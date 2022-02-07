defmodule HLTE.Application do
  @moduledoc false

  use Application
  use Bitwise

  require Logger

  @impl true
  def start(_type, args) do
    case load_key(args[:key_path]) do
      {:ok, key} ->
        keyHash = :crypto.hash(:sha256, key) |> :binary.encode_hex() |> :string.lowercase()
        :ok = :persistent_term.put(:key, key)
        :ok = :persistent_term.put(:key_hash, keyHash)

        Logger.notice("Loaded #{byte_size(key)}-byte key with SHA256 checksum of #{keyHash}")

        start_link(args)

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
         "file mode (#{inspect(stat.mode &&& 0xFFF, base: :octal)}) is too permissive: " <>
           "it cannot not be readable or writable by anyone but the owner.", expand_path}

      {:error, reason} ->
        {:error, reason, expand_path}

      _ ->
        {:error, "unknown", expand_path}
    end
  end

  def start_link(args) do
    children = [
      {Task.Supervisor, name: HLTE.AsyncSupervisor},
      {HLTE.HTTP, [args[:port], args[:header]]},
      {HLTE.DB, [args[:db_path]]}
    ]

    opts = [strategy: :one_for_one, name: HLTE.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
