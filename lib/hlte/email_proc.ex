defmodule HLTE.EmailProcessor do
  require Logger
  use GenServer

  def start_link(opts) do
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
    IO.puts("!!!handle_cast(#{inspect(bucket)}, #{inspect(key)})")
    IO.puts(inspect(state))
    IO.puts(inspect(Application.fetch_env!(:hlte, :sns_whitelist)))
    IO.puts(inspect(from))

    IO.puts(
      inspect(
        Enum.find(Application.fetch_env!(:hlte, :sns_whitelist), fn wle -> from === wle end)
      )
    )

    case Enum.find(Application.fetch_env!(:hlte, :sns_whitelist), fn wle -> from === wle end) do
      ^from -> IO.puts("GOOD FROM!!")
      nil -> IO.puts("BAD FROM!!!!")
    end

    {:noreply, [state]}
  end

  @impl true
  def handle_cast(a, b) do
    IO.puts("handle_cast(#{inspect(a)}, #{inspect(b)})")
    {:noreply}
  end
end
