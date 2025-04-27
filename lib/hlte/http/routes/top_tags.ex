defmodule HLTE.HTTP.Route.TopTags do
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
    req3 = :cowboy_req.set_resp_header("Access-Control-Allow-Headers", "Content-Type, content-type", req2)
    
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
    # Safely extract query parameters
    query_params = :cowboy_req.parse_qs(req)
    
    # Find the 'n' parameter if it exists
    limit = 
      case List.keyfind(query_params, "n", 0) do
        {"n", n_value} -> 
          case Integer.parse(n_value) do
            {num, _} when num > 0 and num <= 100 -> num
            {num, _} when num > 100 -> 100  # Cap at 100 for security
            _ -> 10  # Default to 10 if not a valid positive integer
          end
        nil -> 10  # Default limit if not specified
      end
    
    t0 = :erlang.monotonic_time(:millisecond)
    
    # Use the TagsDB module to get top tags
    tagsRes = HLTE.TagsDB.get_top_tags(limit)
    
    elTime = :erlang.monotonic_time(:millisecond) - t0
    Logger.info("Executed top tags query (limit=#{limit}) in #{elTime}ms")
    
    # Add CORS header to allow only hlte.net subdomains
    origin = get_origin_header(req)
    req_with_cors = :cowboy_req.set_resp_header("Access-Control-Allow-Origin", origin, req)
    
    {Jason.encode!(tagsRes), req_with_cors, state}
  end
end