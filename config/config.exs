import Config

config :hlte,
  port: 56555,
  db_path: "./data.sqlite3",
  key_path: "./.keyfile",
  redis_url: nil,
  sns_whitelist: [],
  delete_sns_s3_post_proc: true,
  media_data_path: "../persistence/data/"

import_config("#{config_env()}.config.exs")

config :ex_aws,
  region: "us-east-1"

config :logger,
  utc_log: true,
  truncate: :infinity

config :logger, :console, format: "$time [$level] $levelpad$message\n"
