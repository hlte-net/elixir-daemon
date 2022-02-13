defmodule HLTE.LoggingUtil do
  require Logger

  def log_json_error(
        %Jason.DecodeError{:data => d, :position => p, :token => t},
        descriptor \\ "POST"
      ) do
    Logger.error("Malformed JSON in #{descriptor}")
    Logger.error("   at position #{p}, token '#{t}' in data: #{d}")
  end

  def log_unauthorized_req(req, calced_hmac, header_name) do
    Logger.critical("Unauthorized! #{req.method} #{req.path}")
    Logger.warn("#{Map.get(req.headers, header_name)} !== #{calced_hmac}")
    Logger.warn("Full request: #{inspect(req)}")
  end
end
