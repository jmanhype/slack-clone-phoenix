defmodule SlackClone.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Core children that must start
    base_children = [
      SlackCloneWeb.Telemetry,
      SlackClone.Repo,
      {DNSCluster, query: Application.get_env(:slack_clone, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SlackClone.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: SlackClone.Finch},
      # Start Oban for background job processing
      {Oban, Application.fetch_env!(:slack_clone, Oban)},
      # Start Cachex for application-level caching
      {Cachex, name: :slack_clone_cache},
      # Start the Presence tracker for real-time user status
      SlackCloneWeb.Presence,
      # Start SlackClone services supervisor
      SlackClone.Services.Supervisor,
      # Start services coordinator
      SlackClone.Services.Coordinator,
      # Start to serve requests, typically the last entry
      SlackCloneWeb.Endpoint
    ]

    # Optional Redis connection - only add if Redis is available
    redis_children = case check_redis_available() do
      true -> [{Redix, name: :redix, host: "localhost", port: 6379}]
      false -> []
    end

    children = base_children ++ redis_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SlackClone.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Check if Redis is available for connection
  defp check_redis_available do
    case :gen_tcp.connect(~c"localhost", 6379, [], 1000) do
      {:ok, socket} -> 
        :gen_tcp.close(socket)
        true
      {:error, _} -> 
        require Logger
        Logger.warning("Redis not available on localhost:6379, caching will use Cachex only")
        false
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SlackCloneWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
