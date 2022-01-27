defmodule HLTE.Application do
  @moduledoc false

  use Application
  use Bitwise

  require Logger

  @impl true
  def start(_type, args) do
    IO.puts("START [#{inspect(args)}] <<#{args[:port]}>>")

    case load_key(args[:key_path]) do
      {:ok, key} ->
        IO.puts("GOT KEY! #{inspect(key)}")
        # persist key!
        start_link(args[:port])

      {:error, reason, expand_path} ->
        Logger.emergency(~s/Failed to load key file at #{expand_path}: "#{reason}"/)
        Logger.flush()
        System.halt(254)
    end
  end

  def load_key(path) do
    expand_path = Path.expand(path)

    case File.stat(expand_path) do
      {:ok, %{mode: mode}} when Bitwise.band(mode, 0o177) == 0 ->
        File.read(expand_path)

      {:ok, stat} ->
        {:error,
         "file permissions (#{inspect(stat.mode &&& 0xFFF, base: :octal)}) are too open: it cannot not be readable or writable by anyone but the owner.",
         expand_path}

      {:error, reason} ->
        {:error, reason, expand_path}

      _ ->
        {:error, "unknown", expand_path}
    end
  end

  def start_link(args) do
    children = [
      {HLTE.HTTP, [args]}
    ]

    opts = [strategy: :one_for_one, name: HLTE.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
