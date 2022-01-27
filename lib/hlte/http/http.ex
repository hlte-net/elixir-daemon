defmodule HLTE.HTTP do
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(args) do
    IO.puts("HTTP run #{inspect(args)}")

    :ok
  end
end
