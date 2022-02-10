import Config

config :hlte,
  api_version: "20220126",
  header: "x-hlte",
  port: 31337,
  db_path: "./data.sqlite3",
  key_path: "./.keyfile",
  redis_url: nil,
  sns_ingest_whitelist: []

import_config("#{config_env()}.config.exs")

config :ex_aws,
  region: "us-east-1"

config :logger,
  utc_log: true,
  truncate: :infinity

config :logger, :console, format: "$time [$level] $levelpad$message\n"
