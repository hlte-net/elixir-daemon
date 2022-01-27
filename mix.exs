defmodule HLTE.MixProject do
  use Mix.Project

  def project do
    [
      app: :hlte_daemon,
      version: "0.1.0",
      api_version: "20220126",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod:
        {HLTE.Application,
         [
           port: 31337,
           local_data_path: "./data",
           key_path: "./.keyfile"
         ]}
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
end
