defmodule HLTE.HTTP.Route.SNSIngest do
  require Logger

  def init(req, state) when req.method === "POST" do
    {:ok, bodyText, req2} = :cowboy_req.read_body(req)

    case Jason.decode(bodyText) |> ingest_post() do
      :error ->
        Logger.warn("Raw request:\n#{inspect(req)}")
        Logger.warn("Raw body:\n#{bodyText}")

      :ok ->
        :ok
    end

    {:ok, :cowboy_req.set_resp_header("Access-Control-Allow-Origin", "*", req2), state}
  end

  def init(req, state) do
    {:ok, :cowboy_req.reply(405, req), state}
  end

  defp ingest_post(
         {:ok,
          %{
            "notificationType" => "Received",
            "receipt" => %{
              "action" => %{
                "type" => "S3",
                "bucketName" => bucket,
                "objectKey" => object_key
              }
            },
            "mail" => %{
              "source" => source,
              "commonHeaders" => %{
                "subject" => subject
              },
              "destination" => [main_dest]
            }
          }}
       ) do
    Logger.info("Processing SNS (to #{main_dest}) from <#{source}>, subject \"#{subject}\"")
    HLTE.EmailProcessor.from_bucket(bucket, object_key, main_dest, source, subject)
    :ok
  end

  defp ingest_post({:ok, malformed}) do
    Logger.error("Malformed POST object! #{inspect(malformed)}")
    :error
  end

  defp ingest_post({:error, decode_error}) do
    HLTE.LoggingUtil.log_json_error(decode_error)
    :error
  end
end
