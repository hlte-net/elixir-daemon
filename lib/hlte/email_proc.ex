defmodule HLTE.EmailProcessor do
  require Logger
  use GenServer

  def start_link(opts) do
    Logger.notice(
      "Email processor using whitelist: #{Enum.join(Application.fetch_env!(:hlte, :sns_whitelist), ", ")}"
    )

    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def from_bucket(bucket, key, from, to, subject) do
    GenServer.cast(EmailProcessor, {:process_from_bucket, bucket, key, from, to, subject})
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
  def handle_cast({:process_from_bucket, bucket, key, from, to, subject}, state) do
    case Enum.find(Application.fetch_env!(:hlte, :sns_whitelist), fn whiteListedAddress ->
           from === whiteListedAddress
         end) do
      ^from ->
        IO.puts("GOOD FROM!!")

        chunk_fun = fn cur, acc ->
          {:cont, cur, acc <> cur}
        end

        after_fun = fn _cur, acc ->
          {:cont, acc}
        end

        s3stream =
          ExAws.S3.download_file(bucket, key, :memory)
          |> ExAws.stream!()
          |> Stream.chunk_while("", chunk_fun, after_fun)

        IO.puts("------")
        IO.puts(s3stream)
        IO.puts("------")

      nil ->
        IO.puts("BAD FROM!!!!")
    end

    # {:ok, _content} = ExAws.S3.delete_object(bucket, key) |> ExAws.request
    {:noreply, [state]}
  end

  @impl true
  def handle_cast(a, b) do
    IO.puts("handle_cast(#{inspect(a)}, #{inspect(b)})")
    {:noreply}
  end
end
