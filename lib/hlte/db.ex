alias Exqlite.Basic

defmodule HLTE.DB do
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
        Logger.notice("Created new database at #{dbPath}")

      {:loaded, count} ->
        Logger.notice("Loaded existing database with #{count} entries from #{dbPath}")
    end

    :persistent_term.put(:db_path, dbPath)
    Basic.close(conn)
  end

  def init_db({:error, _reason}, conn) do
    {:ok, _, _, _} = Basic.exec(conn, "create table hlte (
      checksum text not null,
      timestamp integer not null,
      primaryURI text not null,
      secondaryURI text,
      hilite text,
      annotation text
      )")

    {:created}
  end

  def init_db({:ok, _stat}, conn) do
    {:ok, [[count]], ["count(*)"]} =
      Basic.exec(conn, "SELECT count(*) FROM hlte;") |> Basic.rows()

    {:loaded, count}
  end

  def persist(%{"uri" => uri, "secondaryURI" => suri, "data" => data, "annotation" => ann}, hmac) do
    persist_async(
      uri,
      suri,
      data,
      ann,
      hmac
    )
  end

  def persist(%{"uri" => uri, "secondaryURI" => suri, "annotation" => ann}, hmac) do
    persist_async(
      uri,
      suri,
      nil,
      ann,
      hmac
    )
  end

  def persist(%{"uri" => uri, "data" => data}, hmac) do
    persist_async(
      uri,
      nil,
      data,
      nil,
      hmac
    )
  end

  def search(query, limit, newestFirst) do
    t0 = :erlang.monotonic_time(:millisecond)

    searchRes =
      Task.await(
        Task.Supervisor.async(HLTE.AsyncSupervisor, fn ->
          case newestFirst do
            "false" -> search_async(query, limit, "asc")
            _ -> search_async(query, limit, "desc")
          end
        end)
      )

    {searchRes, :erlang.monotonic_time(:millisecond) - t0}
  end

  defp persist_async(
         uri,
         suri,
         data,
         ann,
         hmac
       ) do
    rxTime = System.os_time(:nanosecond)

    entryID =
      Task.await(
        Task.Supervisor.async(HLTE.AsyncSupervisor, fn ->
          {:ok, conn} = get_conn(:persistent_term.get(:db_path))

          {:ok, _, _, _} =
            Basic.exec(conn, "insert into hlte values(?, ?, ?, ?, ?, ?)", [
              hmac,
              rxTime,
              uri,
              suri,
              data,
              ann
            ])

          Basic.close(conn)
          HLTE.Redis.post_persistence_work(rxTime, hmac, %{"uri" => uri, "secondaryURI" => suri})
        end)
      )

    {:ok, rxTime, entryID}
  end

  defp search_async(query, limit, sortDir) do
    {:ok, conn} = get_conn(:persistent_term.get(:db_path))

    {:ok, rows, rowSpec} =
      Basic.exec(
        conn,
        "select checksum, timestamp, primaryURI,
        secondaryURI, hilite, annotation from hlte
      where hilite like '%' || ? || '%'
      or annotation like '%' || ? || '%'
      or primaryURI like '%' || ? || '%'
      or secondaryURI like '%' || ? || '%'
      order by timestamp #{sortDir} limit ?",
        [
          query,
          query,
          query,
          query,
          limit
        ]
      )
      |> Basic.rows()

    Basic.close(conn)

    # transform into a list of maps with key names based on the row names in `rowSpec`
    Enum.map(rows, fn ele ->
      Enum.reduce(0..(length(rowSpec) - 1), %{}, fn idx, acc ->
        key = Enum.at(rowSpec, idx)

        case key do
          "timestamp" -> Map.put(acc, key, to_string(Enum.at(ele, idx)))
          _ -> Map.put(acc, key, Enum.at(ele, idx))
        end
      end)
    end)
  end

  defp get_conn(dbPath) do
    case Basic.open(dbPath) do
      {:ok, conn} -> {:ok, conn}
      _ -> {:err, nil}
    end
  end
end
