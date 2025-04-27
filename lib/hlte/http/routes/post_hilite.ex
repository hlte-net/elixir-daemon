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
    
    # Handle the response from HLTE.DB.persist gracefully
    case HLTE.DB.persist(dec, bodyHmac) do
      {:ok, rxTime, entryID} ->
        # Store tags if annotation present
        tag_count = 
          case Map.get(dec, "annotation") do
            annotation when is_binary(annotation) -> 
              try do
                case HLTE.TagsDB.store_tags(annotation, bodyHmac, rxTime) do
                  {:ok, count} -> count
                  _ -> 
                    Logger.warning("Failed to store tags for annotation: #{String.slice(annotation, 0..100)}...")
                    0
                end
              rescue
                e -> 
                  Logger.warning("Exception while storing tags: #{inspect(e)}")
                  0
              end
            _ -> 0
          end

        # Format a nice log message with whatever URI we can find
        uri_for_log = 
          case Map.get(dec, "uri") do
            nil -> 
              Map.get(dec, "secondaryURI", "unknown")
            uri -> 
              uri
          end
        
        uri_host = 
          try do
            URI.parse(uri_for_log).host || "unknown_host"
          rescue
            _ -> "unparseable_uri"
          end

        Logger.info(
          "Persisted hilite for #{uri_host} at #{floor(rxTime / 1.0e9)}, " <>
          "work ID #{entryID}, with #{tag_count} tags"
        )

        true
        
      {:error, :invalid_structure} ->
        Logger.error("Failed to persist hilite due to invalid structure")
        false
        
      other_response ->
        Logger.error("Unexpected response from persist operation: #{inspect(other_response)}")
        false
    end
  end

  def persist(_bodyText, bodyHmac, calcHmac) do
    Logger.critical("Persist failed! HMACS: #{bodyHmac} != #{calcHmac}")
    false
  end
end
