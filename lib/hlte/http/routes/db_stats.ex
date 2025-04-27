defmodule HLTE.HTTP.Route.DBStats do
  require Logger

  def init(req, _state) do
    {:cowboy_rest, req, []}
  end

  def allowed_methods(req, state) do
    {["OPTIONS", "GET"], req, state}
  end

  def options(req, state) do
    # Get origin from request headers
    origin = get_origin_header(req)

    # Set CORS headers specific for hlte.net subdomains
    req1 = :cowboy_req.set_resp_header("Access-Control-Allow-Methods", "GET, OPTIONS", req)
    req2 = :cowboy_req.set_resp_header("Access-Control-Allow-Origin", origin, req1)

    req3 =
      :cowboy_req.set_resp_header(
        "Access-Control-Allow-Headers",
        "Content-Type, content-type",
        req2
      )

    {:ok, req3, state}
  end

  # Helper function to get appropriate origin header value
  defp get_origin_header(req) do
    case :cowboy_req.header("origin", req) do
      :undefined ->
        # Default if no origin header
        "null"

      origin ->
        # Check if origin is from hlte.net subdomain
        if String.match?(origin, ~r/^https?:\/\/([a-zA-Z0-9-]+\.)*hlte\.net$/) do
          origin
        else
          # Not from hlte.net domain - deny CORS
          "null"
        end
    end
  end

  def content_types_provided(req, state) do
    {[
       {"text/json", :get_json},
       {"application/json", :get_json}
     ], req, state}
  end

  def get_json(req, state) do
    t0 = :erlang.monotonic_time(:millisecond)

    # Get the statistics
    stats = get_db_stats()

    elTime = :erlang.monotonic_time(:millisecond) - t0
    Logger.info("Executed DB stats query in #{elTime}ms")

    # Add CORS header to allow only hlte.net subdomains
    origin = get_origin_header(req)
    req_with_cors = :cowboy_req.set_resp_header("Access-Control-Allow-Origin", origin, req)

    {Jason.encode!(stats), req_with_cors, state}
  end

  # Private function to get database statistics
  defp get_db_stats() do
    # Create a cache key for this data (cache expires after 5 minutes)
    cache_key = "db_stats"
    now = :os.system_time(:second)

    case :persistent_term.get({:stats_cache, cache_key}, :not_found) do
      {:cached, timestamp, data} when now - timestamp < 60 ->
        # Cache hit - return cached data
        data

      _ ->
        # Cache miss - fetch from database
        entries_count = get_entries_count()
        tags_count = get_tags_count()

        result = %{
          "entries_count" => entries_count,
          "tags_count" => tags_count
        }

        # Store in cache
        :persistent_term.put({:stats_cache, cache_key}, {:cached, now, result})

        result
    end
  end

  # Get the count of entries in the main database
  defp get_entries_count() do
    Task.Supervisor.async(HLTE.AsyncSupervisor, fn ->
      {:ok, conn} = get_conn(:persistent_term.get(:db_path))

      {:ok, [[count]], _column_names} =
        Exqlite.Basic.exec(conn, "SELECT count(*) FROM hlte;") |> Exqlite.Basic.rows()

      Exqlite.Basic.close(conn)

      # Convert to integer
      count |> to_string() |> String.to_integer()
    end)
    |> Task.await()
  end

  # Get the count of unique tags in the tags database
  defp get_tags_count() do
    Task.Supervisor.async(HLTE.AsyncSupervisor, fn ->
      {:ok, conn} = get_conn(:persistent_term.get(:tags_db_path))

      {:ok, [[count]], _column_names} =
        Exqlite.Basic.exec(conn, "SELECT COUNT(DISTINCT tag) FROM tags;") |> Exqlite.Basic.rows()

      Exqlite.Basic.close(conn)

      # Convert to integer
      count |> to_string() |> String.to_integer()
    end)
    |> Task.await()
  end

  defp get_conn(dbPath) do
    case Exqlite.Basic.open(dbPath) do
      {:ok, conn} -> {:ok, conn}
      _ -> {:err, nil}
    end
  end
end
