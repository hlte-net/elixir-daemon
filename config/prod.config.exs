import Config

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :hlte,
  port: 56555

config :logger, :console,
  format: "$time [$level] $levelpad$message ($metadata)\n",
  metadata: [:file, :line]
