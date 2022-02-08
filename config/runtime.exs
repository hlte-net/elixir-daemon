import Config

config :hlte,
  redis_url: System.fetch_env!("HLTE_REDIS_URL")
