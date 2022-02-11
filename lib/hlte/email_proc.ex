defmodule HLTE.EmailProcessor do
  require Logger
  use GenServer

  def start_link(opts) do
    Logger.notice(
      "Email processor using whitelist: #{Enum.join(Application.fetch_env!(:hlte, :sns_whitelist), ", ")}"
    )

    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def from_bucket(bucket, key, from, subject) do
    GenServer.cast(EmailProcessor, {:process_from_bucket, bucket, key, from, subject})
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(_sel, _from, state) do
    {:reply, state}
  end

  @impl true
  def handle_cast({:process_from_bucket, bucket, key, from, subject}, state) do
    case Enum.find(Application.fetch_env!(:hlte, :sns_whitelist), fn whiteListedAddress ->
           from === whiteListedAddress
         end) do
      ^from ->
        chunk_fun = fn cur, acc ->
          {:cont, cur, acc <> cur}
        end

        after_fun = fn
          "" -> {:cont, ""}
          acc -> {:cont, acc, ""}
        end

        {content_type, parsed_msg} =
          ExAws.S3.download_file(bucket, key, :memory)
          |> ExAws.stream!()
          |> Stream.chunk_while("", chunk_fun, after_fun)
          |> Enum.to_list()
          |> Enum.at(0)
          |> Mail.Parsers.RFC2822.parse()
          |> extract_body()

        IO.puts("------")
        IO.puts(content_type)
        IO.puts("------")
        IO.puts(parsed_msg)
        IO.puts("------")

      nil ->
        Logger.error("Message from non-whitelisted address <#{from}>!")
    end

    # {:ok, _content} = ExAws.S3.delete_object(bucket, key) |> ExAws.request
    {:noreply, [state]}
  end

  @impl true
  def handle_cast(a, b) do
    IO.puts("handle_cast(#{inspect(a)}, #{inspect(b)})")
    {:noreply}
  end

  def extract_body(%Mail.Message{:multipart => true, :parts => parts}) do
    target_part =
      Enum.find(parts, fn p ->
        Map.get(p.headers, "content-type") |> Enum.at(0) === "text/plain"
      end) ||
        Enum.at(parts, 0)

    {Map.get(target_part.headers, "content-type"), target_part.body}
  end

  def extract_body(%Mail.Message{
        :multipart => false,
        :body => body,
        :headers => %{"content-type" => c_type}
      }) do
    {c_type, body}
  end
end
