defmodule HLTE.HTTP.Route.SNSIngest do
  require Logger

  def init(req, state) when req.method === "POST" do
    Logger.warn("*** SNS REQ 'POST' ***")
    IO.puts(inspect(req))
    {:ok, bodyText, req2} = :cowboy_req.read_body(req)
    IO.puts("******")
    IO.puts(bodyText)
    Logger.warn("*** /SNS REQ 'POST' ***")

    Jason.decode(bodyText) |> ingest_post()
    {:ok, :cowboy_req.set_resp_header("Access-Control-Allow-Origin", "*", req2), state}
  end

  def init(req, state) do
    {:ok, :cowboy_req.reply(405, req), state}
  end

  defp ingest_post(
         {:ok,
          %{
            :notificationType => "Received",
            :receipt => receipt,
            :mail => mail
          }}
       ) do
    Logger.info("Got an email notification! From: #{mail.source}")
    IO.puts("****** Receipt:")
    IO.puts(inspect(receipt))
    IO.puts("****** Mail:")
    IO.puts(inspect(mail))
    IO.puts("******")
  end

  defp ingest_post({:ok, malformed}) do
    Logger.error("Malformed POST! #{inspect(malformed)}")
  end

  defp ingest_post({:error, %Jason.DecodeError{:data => d, :position => p, :token => t}}) do
    Logger.error("Malformed POST JSON!")
    Logger.error("-> at position #{p}, token '#{t}' in data: #{d}")
  end

  defp ingest_post({:error, unkErr}) do
    Logger.error("Malformed POST! Unknown error: #{inspect(unkErr)}")
  end
end
