defmodule HLTE.MixProject do
  require Logger

  use Mix.Project

  def project do
    [
      app: :hlte,
      version: "0.2.0",
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

    Logger.notice("App v#{project()[:version]} started with config #{inspect(envArgs)}")

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
      {:cowboy, "~> 2.9"},
      {:jason, "~> 1.2"},
      {:exqlite, "~> 0.8.6"},
      {:redix, "~> 1.1"},
      {:ex_aws, "~> 2.2"},
      {:ex_aws_s3, "~> 2.3"},
      {:hackney, "~> 1.18"},
      {:mail, "~> 0.2"}
    ]
  end

  defp fe(k), do: Application.fetch_env!(:hlte, k)
end
