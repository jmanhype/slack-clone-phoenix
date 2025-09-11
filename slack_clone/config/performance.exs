# Performance optimization configuration for Slack Clone
import Config

# Database performance configuration
config :slack_clone, SlackClone.Repo,
  # Connection pool optimization
  pool_size: System.get_env("DATABASE_POOL_SIZE", "15") |> String.to_integer(),
  queue_target: 5000,
  queue_interval: 1000,
  
  # Connection configuration for performance
  prepare: :named,
  timeout: :infinity,
  ownership_timeout: 60_000,
  
  # PostgreSQL specific optimizations
  parameters: [
    application_name: "slack_clone",
    tcp_keepalives_idle: "600",
    tcp_keepalives_interval: "30",
    tcp_keepalives_count: "3"
  ]

# Phoenix optimizations
config :phoenix,
  # Template compilation cache
  template_engines: [
    eex: Phoenix.Template.EExEngine,
    exs: Phoenix.Template.ExsEngine
  ]

# LiveView optimizations
config :phoenix_live_view,
  # Signing salt for improved security and performance
  signing_salt: System.get_env("LIVEVIEW_SALT", "your-signing-salt"),
  
  # Enable compression for LiveView diffs
  compress: true,
  
  # Optimize JavaScript delivery
  static_cache_manifest_vsn: System.get_env("STATIC_CACHE_VERSION", "1.0")

# PubSub optimization
config :slack_clone, SlackClone.PubSub,
  # Use Redis for distributed PubSub when available
  adapter: if(System.get_env("REDIS_URL"), do: Phoenix.PubSub.Redis, else: Phoenix.PubSub.PG2),
  
  # Redis configuration for distributed PubSub
  redis_url: System.get_env("REDIS_URL"),
  
  # PG2 configuration for local development
  name: SlackClone.PubSub,
  pool_size: System.schedulers_online() * 2

# Redis configuration for caching
config :slack_clone, :redis,
  url: System.get_env("REDIS_URL", "redis://localhost:6379/0"),
  pool_size: 10,
  timeout: 5000,
  idle_timeout: 30_000

# Cachex configuration for in-memory caching
config :cachex,
  # Default cache configuration
  :slack_clone_cache,
  limit: 10_000,
  expiration: [
    default: :timer.minutes(30),
    interval: :timer.minutes(5),
    lazy: true
  ],
  fallback: [
    action: &SlackClone.Performance.CacheManager.get_or_fetch/3,
    state: []
  ]

# Oban configuration for background jobs
config :slack_clone, Oban,
  # Use PostgreSQL for job storage
  repo: SlackClone.Repo,
  
  # Queue configuration optimized for performance
  queues: [
    default: [limit: 20, paused: false],
    notifications: [limit: 50, paused: false],
    analytics: [limit: 10, paused: false],
    cleanup: [limit: 5, paused: false]
  ],
  
  # Performance optimizations
  dispatch_cooldown: 5,
  shutdown_timeout: :timer.seconds(30),
  
  # Cron jobs for maintenance
  crontab: [
    {"0 2 * * *", SlackClone.Jobs.DatabaseCleanup, queue: :cleanup},
    {"*/15 * * * *", SlackClone.Jobs.CacheWarmup, queue: :default},
    {"0 */6 * * *", SlackClone.Jobs.MetricsAggregation, queue: :analytics}
  ]

# Performance monitoring configuration
config :slack_clone, SlackClone.Performance.Monitor,
  # Enable performance monitoring
  enabled: true,
  
  # Metrics collection intervals
  metrics_interval: 10_000,      # 10 seconds
  cleanup_interval: 300_000,     # 5 minutes
  alert_interval: 60_000,        # 1 minute
  
  # Performance thresholds for alerts
  thresholds: [
    response_time: 500,           # milliseconds
    cpu_usage: 80,               # percentage
    memory_usage: 85,            # percentage
    cache_hit_ratio: 0.7,        # 70%
    error_rate: 50               # errors per interval
  ]

# Connection pool optimizer configuration
config :slack_clone, SlackClone.Performance.ConnectionPoolOptimizer,
  # Enable automatic pool optimization
  enabled: true,
  
  # Pool sizing parameters
  min_pool_size: 5,
  max_pool_size: 50,
  high_utilization_threshold: 0.8,
  low_utilization_threshold: 0.3,
  
  # Monitoring intervals
  monitoring_interval: 30_000,    # 30 seconds
  health_check_interval: 60_000,  # 1 minute
  resize_interval: 120_000        # 2 minutes

# Edge cache configuration
config :slack_clone, SlackClone.Performance.EdgeCache,
  # Enable edge caching
  enabled: true,
  
  # CDN integration (configure based on your CDN provider)
  cdn_provider: :cloudflare,  # :cloudflare, :aws_cloudfront, :fastly
  
  # Cache TTL settings
  default_ttl: 3600,          # 1 hour
  static_asset_ttl: 86400,    # 24 hours
  api_response_ttl: 300,      # 5 minutes
  user_content_ttl: 1800,     # 30 minutes
  
  # Geographic regions for edge distribution
  regions: [
    :us_east_1,
    :us_west_2,
    :eu_west_1,
    :ap_southeast_1,
    :ap_northeast_1
  ],
  
  # Cache optimization settings
  compression_threshold: 1024,  # bytes
  max_cache_size_mb: 1000,
  eviction_policy: :lru

# PubSub optimizer configuration
config :slack_clone, SlackClone.Performance.PubSubOptimizer,
  # Enable PubSub optimization
  enabled: true,
  
  # Batching configuration
  batch_interval: 100,          # milliseconds
  max_batch_size: 50,
  
  # Debouncing configuration
  typing_debounce: 2000,        # milliseconds
  presence_debounce: 5000       # milliseconds

# Asset optimization
config :esbuild, SlackClone.Assets,
  version: "0.17.11",
  default: [
    args: ~w(
      js/app.js
      js/performance_hooks.js
      --bundle
      --target=es2017
      --outdir=../priv/static/assets
      --external:/fonts/*
      --external:/images/*
      --minify
      --sourcemap=external
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind, SlackClone.Assets,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
      --minify
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Telemetry configuration for performance monitoring
config :telemetry_poller, :default,
  period: 5_000,  # 5 seconds
  measurements: [
    {SlackClone.Performance.Monitor, :record_system_metrics, []},
    {:process_info, [:message_queue_len, :memory]},
    {:system_info, [:process_count, :port_count]}
  ]

# Logger configuration for performance
config :logger,
  backends: [:console, LoggerJSON],
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :channel_id]

# JSON logger for structured logging
config :logger_json, :backend,
  metadata: [
    :request_id,
    :user_id,
    :channel_id,
    :response_time_ms,
    :cache_hit,
    :database_time_ms
  ],
  formatter: LoggerJSON.Formatters.BasicLogger

# Sentry configuration for error monitoring
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: config_env()
  },
  included_environments: [:prod, :staging],
  
  # Performance monitoring
  traces_sample_rate: 0.1,
  profiles_sample_rate: 0.1

# Phoenix endpoint optimizations
config :slack_clone, SlackCloneWeb.Endpoint,
  # HTTP/2 configuration for better performance
  http: [
    ip: {0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT", "4000")),
    protocol_options: [
      idle_timeout: 60_000,
      request_timeout: 30_000,
      max_header_length: 16_384,
      max_header_name_length: 256,
      max_request_line_length: 8192
    ]
  ],
  
  # Enable gzip compression
  compress: true,
  
  # Static asset serving optimizations
  static_url: System.get_env("STATIC_URL") || "/",
  cache_static_manifest: "priv/static/cache_manifest.json",
  
  # Cache control headers
  cache_control_for_etags: "public, max-age=31536000",
  cache_control_for_vsns: "public, max-age=31536000",
  
  # Security headers that also improve performance
  force_ssl: config_env() == :prod,
  
  # Session configuration
  session_options: [
    store: :cookie,
    key: "_slack_clone_key",
    signing_salt: System.get_env("SESSION_SIGNING_SALT", "signing-salt"),
    max_age: 86400 * 30  # 30 days
  ]

# Compile-time optimizations
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# ETS table configuration for better performance
config :slack_clone, :ets_tables,
  # Configure ETS tables for caching
  cache_tables: [
    {:performance_metrics, [:ordered_set, :public, :named_table]},
    {:cache_statistics, [:set, :public, :named_table]},
    {:access_patterns, [:bag, :public, :named_table]},
    {:edge_cache_entries, [:set, :public, :named_table]},
    {:pool_metrics_history, [:ordered_set, :public, :named_table]}
  ]

# Environment-specific overrides
if config_env() == :prod do
  # Production optimizations
  config :slack_clone, SlackClone.Repo,
    pool_size: 20,
    queue_target: 2000,
    queue_interval: 500
  
  config :slack_clone, SlackCloneWeb.Endpoint,
    cache_static_manifest: "priv/static/cache_manifest.json",
    server: true
    
  config :logger, level: :info
  
elseif config_env() == :dev do
  # Development optimizations (lighter monitoring)
  config :slack_clone, SlackClone.Performance.Monitor,
    enabled: false
  
  config :slack_clone, SlackClone.Performance.EdgeCache,
    enabled: false
    
  config :logger, level: :debug
  
elseif config_env() == :test do
  # Test environment optimizations
  config :slack_clone, SlackClone.Repo,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
  
  config :slack_clone, SlackClone.Performance.Monitor,
    enabled: false
  
  config :logger, level: :warn
end