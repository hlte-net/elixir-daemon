defmodule HLTE.TagsDB do
  require Logger

  use Task

  def start_link([dbPath]) do
    Task.start_link(__MODULE__, :init, [Path.expand(dbPath)])
  end

  def init(dbPath) do
    statRes = File.stat(dbPath)
    {:ok, conn} = get_conn(dbPath)

    case init_db(statRes, conn) do
      {:created} ->
        Logger.notice("Created new tags database at #{dbPath}")

      {:loaded, count} ->
        Logger.notice("Loaded existing tags database with #{count} entries from #{dbPath}")
    end

    :persistent_term.put(:tags_db_path, dbPath)
    Exqlite.Basic.close(conn)
  end

  def init_db({:error, _reason}, conn) do
    # Create the tags table
    {:ok, _, _, _} = Exqlite.Basic.exec(conn, """
    CREATE TABLE tags (
      tag TEXT NOT NULL,
      checksum TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      PRIMARY KEY (tag, checksum, timestamp)
    );
    CREATE INDEX idx_tags_tag ON tags(tag);
    CREATE INDEX idx_tags_checksum_timestamp ON tags(checksum, timestamp);
    CREATE INDEX idx_tags_timestamp ON tags(timestamp);
    """)

    {:created}
  end

  def init_db({:ok, _stat}, conn) do
    {:ok, [[count]], ["count(*)"]} =
      Exqlite.Basic.exec(conn, "SELECT count(*) FROM tags;") |> Exqlite.Basic.rows()

    Exqlite.Basic.exec(conn, "PRAGMA busy_timeout = 5000;")

    {:loaded, count}
  end

  @doc """
  Extract tags from annotation text and store them in the tags database.
  """
  def store_tags(annotation, checksum, timestamp) when is_binary(annotation) do
    Task.Supervisor.async(HLTE.AsyncSupervisor, fn ->
      store_tags_async(annotation, checksum, timestamp)
    end)
    |> Task.await()
  end

  def store_tags(_, _, _), do: {:ok, 0}  # Handle nil or other non-binary annotations

  @doc """
  Get top N tags by usage count.
  Maximum limit is 100 for security reasons.
  """
  def get_top_tags(limit \\ 10) do
    # Validate limit is an integer
    parsed_limit = 
      case limit do
        limit when is_integer(limit) -> limit
        limit when is_binary(limit) ->
          case Integer.parse(limit) do
            {num, _} -> num
            :error -> 10
          end
        _ -> 10
      end
      
    Task.Supervisor.async(HLTE.AsyncSupervisor, fn ->
      get_top_tags_async(parsed_limit)
    end)
    |> Task.await()
  end

  @doc """
  Get most recent N tags.
  Maximum limit is 100 for security reasons.
  """
  def get_recent_tags(limit \\ 10) do
    # Validate limit is an integer
    parsed_limit = 
      case limit do
        limit when is_integer(limit) -> limit
        limit when is_binary(limit) ->
          case Integer.parse(limit) do
            {num, _} -> num
            :error -> 10
          end
        _ -> 10
      end
      
    Task.Supervisor.async(HLTE.AsyncSupervisor, fn ->
      get_recent_tags_async(parsed_limit)
    end)
    |> Task.await()
  end

  # Private functions

  defp store_tags_async(annotation, checksum, timestamp) do
    tags = extract_tags(annotation)
    
    if Enum.empty?(tags) do
      {:ok, 0}
    else
      {:ok, conn} = get_conn(:persistent_term.get(:tags_db_path))
      
      # Use a transaction for better performance when inserting multiple tags
      Exqlite.Basic.exec(conn, "BEGIN TRANSACTION")
      
      # Insert each tag
      count = Enum.reduce(tags, 0, fn tag, acc ->
        case Exqlite.Basic.exec(conn, 
          "INSERT OR IGNORE INTO tags VALUES (?, ?, ?)", 
          [tag, checksum, timestamp]) do
          {:ok, _, _, _} -> acc + 1
          _ -> acc
        end
      end)
      
      Exqlite.Basic.exec(conn, "COMMIT")
      Exqlite.Basic.close(conn)
      
      # Invalidate cache when new tags are added
      :persistent_term.erase({:tags_cache, "top_tags_10"})
      :persistent_term.erase({:tags_cache, "recent_tags_10"})
      
      {:ok, count}
    end
  end

  # Cache time in seconds (5 minutes)
  @cache_timeout 300
  
  defp get_top_tags_async(limit) when is_integer(limit) and limit > 0 and limit <= 100 do
    # Apply a hard limit of 100 for security
    capped_limit = min(limit, 100)
    
    # Try to get from cache first
    cache_key = "top_tags_#{capped_limit}"
    now = :os.system_time(:second)
    case :persistent_term.get({:tags_cache, cache_key}, :not_found) do
      {:cached, timestamp, data} when now - timestamp < @cache_timeout ->
        # Cache hit - return cached data
        data
        
      _ ->
        # Cache miss - fetch from database
        {:ok, conn} = get_conn(:persistent_term.get(:tags_db_path))
        
        query = """
        SELECT tag, COUNT(*) as count 
        FROM tags 
        GROUP BY tag 
        ORDER BY count DESC, tag ASC 
        LIMIT ?
        """
        
        {:ok, rows, _} =
          Exqlite.Basic.exec(conn, query, [capped_limit])
          |> Exqlite.Basic.rows()
        
        Exqlite.Basic.close(conn)
        
        # Transform the result
        result = Enum.map(rows, fn [tag, count] ->
          %{
            "tag" => tag,
            "count" => count |> to_string() |> String.to_integer()
          }
        end)
        
        # Store in cache
        :persistent_term.put({:tags_cache, cache_key}, {:cached, :os.system_time(:second), result})
        
        result
    end
  end
  
  # Handle invalid limit values
  defp get_top_tags_async(_invalid_limit) do
    # Default to 10 items for invalid input
    get_top_tags_async(10)
  end

  defp get_recent_tags_async(limit) when is_integer(limit) and limit > 0 and limit <= 100 do
    # Apply a hard limit of 100 for security
    capped_limit = min(limit, 100)
    
    # Try to get from cache first
    cache_key = "recent_tags_#{capped_limit}"
    now = :os.system_time(:second)
    case :persistent_term.get({:tags_cache, cache_key}, :not_found) do
      {:cached, timestamp, data} when now - timestamp < @cache_timeout ->
        # Cache hit - return cached data
        data
        
      _ ->
        # Cache miss - fetch from database
        {:ok, conn} = get_conn(:persistent_term.get(:tags_db_path))
        
        query = """
        WITH latest_tag_uses AS (
          SELECT tag, MAX(timestamp) as latest_timestamp
          FROM tags
          GROUP BY tag
        )
        SELECT t.tag, t.timestamp
        FROM tags t
        JOIN latest_tag_uses l ON t.tag = l.tag AND t.timestamp = l.latest_timestamp
        ORDER BY t.timestamp DESC
        LIMIT ?
        """
        
        {:ok, rows, _} =
          Exqlite.Basic.exec(conn, query, [capped_limit])
          |> Exqlite.Basic.rows()
        
        Exqlite.Basic.close(conn)
        
        # Transform the result
        result = Enum.map(rows, fn [tag, timestamp] ->
          %{
            "tag" => tag,
            "timestamp" => timestamp |> to_string() |> String.to_integer()
          }
        end)
        
        # Store in cache
        :persistent_term.put({:tags_cache, cache_key}, {:cached, :os.system_time(:second), result})
        
        result
    end
  end
  
  # Handle invalid limit values
  defp get_recent_tags_async(_invalid_limit) do
    # Default to 10 items for invalid input
    get_recent_tags_async(10)
  end

  @doc """
  Extract tags from text. Public for testing.
  """
  def extract_tags(text) when is_binary(text) do
    Regex.scan(~r/\#([a-zA-Z0-9_]+)/, text)
    |> Enum.map(fn [_, tag] -> tag end)
  end
  
  def extract_tags(_), do: []

  defp get_conn(dbPath) do
    case Exqlite.Basic.open(dbPath) do
      {:ok, conn} -> {:ok, conn}
      _ -> {:err, nil}
    end
  end
end