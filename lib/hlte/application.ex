defmodule HLTE.Application do
  @moduledoc false

  use Application
  use Bitwise

  require Logger

  # https://stackoverflow.com/questions/32968253/access-project-version-within-elixir-application#comment74133074_35704257
  @version Mix.Project.config()[:version]
  defp version(), do: @version

  @impl true
  def start(_type, _opts) do
    args = [
      header: fe(:header),
      port: fe(:port),
      db_path: fe(:db_path),
      key_path: fe(:key_path),
      media_data_path: fe(:media_data_path)
    ]

    if Mix.env() === :test do
      Path.expand(args[:key_path]) |> File.chmod!(0o400)
    end

    case load_key(args[:key_path]) do
      {:ok, key} ->
        keyHash = :crypto.hash(:sha256, key) |> :binary.encode_hex() |> :string.lowercase()
        :ok = :persistent_term.put(:key, key)
        :ok = :persistent_term.put(:key_hash, keyHash)

        Logger.notice("Loaded #{byte_size(key)}-byte key with SHA256 checksum of #{keyHash}")

        {:ok, pid} = start_link(args)

        Logger.notice(
          "App v#{version()} started as PID #{inspect(pid)} with config: #{inspect(args)}"
        )

        {:ok, pid}

      {:error, reason, expand_path} ->
        Logger.emergency(~s/Failed to load key file at #{expand_path}: "#{reason}"/)
        Logger.flush()
        {:error, reason, expand_path}
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
    end
  end

  def start_link(args) do
    children = [
      {Task.Supervisor, name: HLTE.AsyncSupervisor},
      {HLTE.EmailProcessor, name: EmailProcessor},
      {HLTE.HTTP, [args[:port], args[:header], args[:media_data_path]]},
      {HLTE.DB, [args[:db_path]]}
    ]

    opts = [strategy: :one_for_one, name: HLTE.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp fe(k), do: Application.fetch_env!(:hlte, k)
end
