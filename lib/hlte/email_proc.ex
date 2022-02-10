defmodule HLTE.EmailProcessor do
  require Logger
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def process_from_bucket(bucket, key) do
    GenServer.cast(EmailProcessor, {:process_from_bucket, bucket, key})
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(a, b, c) do
    IO.puts("handle_call(#{inspect(a)}, #{inspect(b)}, #{inspect(c)})")
  end

  @impl true
  def handle_cast({:process_from_bucket, bucket, key}, state) do
    IO.puts("!!!handle_cast(#{inspect(bucket)}, #{inspect(key)})")
    IO.puts(inspect(state))
    {:noreply, [state]}
  end

  @impl true
  def handle_cast(a, b) do
    IO.puts("handle_cast(#{inspect(a)}, #{inspect(b)})")
    {:noreply}
  end
end
