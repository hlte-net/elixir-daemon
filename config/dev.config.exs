import Config

config :hlte,
  db_path: "./dev-data.sqlite3"

config :logger, :console,
  format: "$time [$level] $levelpad$message ($metadata)\n",
  metadata: [:file, :line]
