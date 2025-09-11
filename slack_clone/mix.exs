defmodule SlackClone.MixProject do
  use Mix.Project

  def project do
    [
      app: :slack_clone,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SlackClone.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      # Phoenix Framework
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      
      # Authentication & Authorization
      {:guardian, "~> 2.3"},
      {:guardian_phoenix, "~> 2.0"},
      {:argon2_elixir, "~> 4.0"},
      
      # File Uploads
      {:waffle, "~> 1.1"},
      {:waffle_ecto, "~> 0.0.12"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.4"},
      {:hackney, "~> 1.20"},
      {:sweet_xml, "~> 0.7"},
      
      # Real-time Features
      {:phoenix_pubsub, "~> 2.1"},
      
      # Rate Limiting & Caching
      {:hammer, "~> 6.1"},
      {:redix, "~> 1.2"},
      {:cachex, "~> 3.6"},
      
      # Search
      {:elasticsearch, "~> 1.0"},
      
      # Background Jobs
      {:oban, "~> 2.17"},
      
      # Monitoring & Logging
      {:sentry, "~> 10.0"},
      {:logger_json, "~> 6.0"},
      
      # Testing
      {:ex_machina, "~> 2.7", only: [:test, :dev]},
      {:faker, "~> 0.18", only: [:test, :dev]},
      {:excoveralls, "~> 0.18", only: :test},
      
      # Code Quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      
      # CORS & Security
      {:cors_plug, "~> 3.0"},
      {:plug_attack, "~> 0.4"},
      
      # Assets
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      
      # Email & Communications
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      
      # Utilities
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:timex, "~> 3.7"},
      {:uuid, "~> 1.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind slack_clone", "esbuild slack_clone"],
      "assets.deploy": [
        "tailwind slack_clone --minify",
        "esbuild slack_clone --minify",
        "phx.digest"
      ]
    ]
  end
end
