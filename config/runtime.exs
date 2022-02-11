import Config

config :hlte,
  redis_url: System.fetch_env!("HLTE_REDIS_URL"),
  sns_whitelist: Jason.decode!(System.fetch_env!("HLTE_SNS_WHITELIST_JSON"))
