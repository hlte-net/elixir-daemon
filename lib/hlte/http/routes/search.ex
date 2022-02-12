defmodule HLTE.HTTP.Route.Search do
  require Logger

  def init(req, [headerName]) do
    {:cowboy_rest, req, [headerName]}
  end

  def allowed_methods(req, state) do
    {["OPTIONS", "GET"], req, state}
  end

  def options(req, state) do
    {:ok, HLTE.HTTP.cors_preflight_options("GET", req), state}
  end

  def content_types_provided(req, state) do
    {[
       {"text/json", :get_json},
       {"application/json", :get_json}
     ], req, state}
  end

  def get_json(req, [headerName]) when is_map_key(req.headers, headerName) do
    # XXX: must check that the request timestamp isn't too much in the past, to close the reuse vector!!
    %{d: newestFirst, l: limit, q: query} = :cowboy_req.match_qs([:d, :l, :q], req)

    case search(
           req.headers[headerName],
           HLTE.HTTP.calculate_body_hmac(req.qs),
           query,
           limit,
           newestFirst
         ) do
      {:ok, searchRes, elTime} ->
        Logger.info("Executed search '#{query}' (limit=#{limit}) in #{elTime}ms")
        {searchRes, req, [headerName]}

      _ ->
        Logger.warn("Failed request was:\n#{inspect(req)}")
        {"[]", req, [headerName]}
    end
  end

  def get_json(req, [_headerName]) do
    Logger.error("Search request failed! #{inspect(req)}")
    false
  end

  defp search(bodyHmac, calcHmac, query, limit, newestFirst) when bodyHmac === calcHmac do
    {searchRes, elTime} = HLTE.DB.search(query, limit, newestFirst)
    {:ok, Jason.encode!(searchRes), elTime}
  end

  defp search(bodyHmac, calcHmac, _query, _limit, _newestFirst) do
    Logger.critical("Search request (match) failed! HMACS: #{bodyHmac} != #{calcHmac}")
    false
  end
end
