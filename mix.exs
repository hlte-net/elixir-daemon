defmodule HLTE.MixProject do
  require Logger

  use Mix.Project

  def project do
    [
      app: :hlte,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    envArgs = [
      header: fe(:header),
      port: fe(:port),
      db_path: fe(:db_path),
      key_path: fe(:key_path)
    ]

    Logger.notice("App started with config #{inspect(envArgs)}")

    [
      extra_applications: [:logger],
      mod: {HLTE.Application, envArgs},
      env: [
        args: envArgs
      ]
    ]
  end

  defp deps do
    [
      # HTTP/REST library
      {:cowboy, "~> 2.9"},
      # JSON encoding/decoding
      {:jason, "~> 1.2"},
      # SQLite3 client library
      {:exqlite, "~> 0.8.6"}
    ]
  end

  defp fe(k), do: Application.fetch_env!(:hlte, k)
end
