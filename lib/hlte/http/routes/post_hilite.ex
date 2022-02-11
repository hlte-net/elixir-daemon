defmodule HLTE.HTTP.Route.PostHilite do
  require Logger

  def init(req, [headerName]) do
    {:cowboy_rest, req, [headerName]}
  end

  def allowed_methods(req, state) do
    {["OPTIONS", "POST"], req, state}
  end

  def content_types_accepted(req, state) do
    {[
       {"text/json", :post_json},
       {"application/json", :post_json}
     ], req, state}
  end

  def options(req, [headerName]) do
    {:ok, HLTE.HTTP.cors_preflight_options("POST", req, headerName), [headerName]}
  end

  def post_json(req, [headerName]) when is_map_key(req.headers, headerName) do
    {:ok, bodyText, req2} = :cowboy_req.read_body(req)
    hmac = req.headers[headerName]

    {persist(bodyText, hmac, HLTE.HTTP.calculate_body_hmac(bodyText)),
     :cowboy_req.set_resp_header("Access-Control-Allow-Origin", "*", req2), [headerName]}
  end

  def post_json(req, state) do
    Logger.error("POST without header! #{inspect(req)}")
    {false, req, state}
  end

  def persist(bodyText, bodyHmac, calcHmac) when bodyHmac === calcHmac do
    dec = Jason.decode!(bodyText)
    {:ok, rxTime, entryID} = HLTE.DB.persist(dec, bodyHmac)

    Logger.info(
      "Persisted hilite for #{URI.parse(Map.get(dec, "uri")).host} at #{floor(rxTime / 1.0e9)}, work ID #{entryID}"
    )

    true
  end

  def persist(_bodyText, bodyHmac, calcHmac) do
    Logger.critical("Persist failed! HMACS: #{bodyHmac} != #{calcHmac}")
    false
  end
end
