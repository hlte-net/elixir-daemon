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
                "objectKey" => objectKey
              }
            },
            "mail" => %{
              "timestamp" => ts,
              "source" => source,
              "destination" => destList,
              "commonHeaders" => %{
                "from" => fromList,
                "date" => rxDate,
                "messageId" => mId,
                "subject" => subject
              }
            }
          }}
       ) do
    Logger.info("****** MAIL RX ******")
    Logger.info("At:      #{rxDate} (#{ts})")
    Logger.info("Msg ID:  #{mId}")
    Logger.info("From:    #{source}")
    Logger.info("To:      #{destList |> Enum.join(", ")}")
    Logger.info("Subject: #{subject}")
    Logger.info("S3:      #{bucket}/#{objectKey}")
    Logger.info("****** /MAIL RX ******")

    HLTE.EmailProcessor.from_bucket(bucket, objectKey, source, destList, subject)

    :ok
  end

  defp ingest_post({:ok, malformed}) do
    Logger.error("Malformed POST object! #{inspect(malformed)}")
    :error
  end

  defp ingest_post({:error, %Jason.DecodeError{:data => d, :position => p, :token => t}}) do
    Logger.error("Malformed POST JSON!")
    Logger.error("   at position #{p}, token '#{t}' in data: #{d}")
    :error
  end

  defp ingest_post({:error, unkErr}) do
    Logger.error("Malformed POST! Unknown error: #{inspect(unkErr)}")
    :error
  end
end
