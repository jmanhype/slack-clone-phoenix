# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :slack_clone,
  ecto_repos: [SlackClone.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :slack_clone, SlackCloneWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SlackCloneWeb.ErrorHTML, json: SlackCloneWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SlackClone.PubSub,
  live_view: [signing_salt: "9PTnIREx"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :slack_clone, SlackClone.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  slack_clone: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  slack_clone: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Guardian for JWT authentication
config :slack_clone, SlackClone.Guardian,
  issuer: "slack_clone",
  secret_key: "your_secret_key_here",
  ttl: {24, :hours},
  refresh_ttl: {7, :days}

# Configure Waffle for file uploads
config :waffle,
  storage: Waffle.Storage.Local,
  storage_dir_prefix: "priv/static/uploads"

# Configure ExAWS for S3 uploads (optional)
config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION", "us-east-1")

# Configure Oban for background jobs
config :slack_clone, Oban,
  repo: SlackClone.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, notifications: 5, uploads: 3]

# Configure Redis for caching and rate limiting
config :redix,
  host: System.get_env("REDIS_HOST", "localhost"),
  port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
  database: String.to_integer(System.get_env("REDIS_DATABASE", "0"))

# Configure rate limiting (using ETS in-memory backend for now)
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4,
                                 cleanup_interval_ms: 60_000 * 10]}

# Configure CORS
config :cors_plug,
  origin: ["http://localhost:3000", "http://localhost:4000"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept", "Origin", "User-Agent", "DNT", "Cache-Control", "X-Mx-ReqToken", "Keep-Alive", "X-Requested-With", "If-Modified-Since", "X-CSRF-Token"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
