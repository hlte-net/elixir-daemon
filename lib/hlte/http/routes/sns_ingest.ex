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
    IO.puts("****** MAIL RX ******")
    IO.puts("At:      #{ts}")
    IO.puts("At:      #{rxDate}")
    IO.puts("Msg ID:  #{mId}")
    IO.puts("From:    #{source}")
    IO.puts("From:    #{fromList |> Enum.join(", ")}")
    IO.puts("To:      #{destList |> Enum.join(", ")}")
    IO.puts("Subject: #{subject}")
    IO.puts("S3:      #{bucket}/#{objectKey}")
    IO.puts("****** /MAIL RX ******")
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
