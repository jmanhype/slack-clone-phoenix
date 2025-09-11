defmodule SlackCloneWeb.TelemetryController do
  use SlackCloneWeb, :controller
  
  alias SlackClone.Performance.{Monitor, CacheManager}
  alias SlackClone.Repo

  @doc """
  Returns comprehensive telemetry metrics as JSON.
  """
  def metrics(conn, _params) do
    metrics = %{
      timestamp: DateTime.utc_now(),
      system: get_system_metrics(),
      database: get_database_metrics(),
      cache: get_cache_metrics(),
      performance: get_performance_metrics(),
      health_score: calculate_health_score()
    }
    
    json(conn, metrics)
  end

  @doc """
  Returns system health status.
  """
  def health(conn, _params) do
    health_data = %{
      status: "healthy",
      timestamp: DateTime.utc_now(),
      services: %{
        database: check_database_health(),
        redis: check_redis_health(),
        phoenix: "healthy"
      },
      uptime: get_uptime(),
      version: Application.spec(:slack_clone, :vsn)
    }
    
    json(conn, health_data)
  end

  @doc """
  Returns performance monitoring dashboard data.
  """
  def dashboard(conn, _params) do
    dashboard_data = %{
      current_load: get_current_load(),
      memory_usage: get_memory_stats(),
      active_connections: get_connection_count(),
      recent_errors: get_recent_errors(),
      response_times: get_response_times(),
      database_stats: get_database_performance()
    }
    
    json(conn, dashboard_data)
  end

  # Private helper functions

  defp get_system_metrics do
    memory_info = :erlang.memory()
    
    %{
      node: Node.self(),
      uptime: :erlang.statistics(:wall_clock) |> elem(0),
      memory: %{
        total: memory_info[:total],
        processes: memory_info[:processes],
        system: memory_info[:system],
        atom: memory_info[:atom],
        binary: memory_info[:binary],
        ets: memory_info[:ets]
      },
      schedulers: %{
        online: :erlang.system_info(:schedulers_online),
        total: :erlang.system_info(:schedulers)
      },
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit)
    }
  end

  defp get_database_metrics do
    case Repo.get_pool_status() do
      {:ok, pool_stats} ->
        %{
          status: "healthy",
          pool: pool_stats,
          query_cache_size: get_query_cache_size()
        }
      {:error, reason} ->
        %{
          status: "error",
          error: reason,
          pool: %{},
          query_cache_size: 0
        }
    end
  end

  defp get_cache_metrics do
    CacheManager.get_stats()
  end

  defp get_performance_metrics do
    case Process.whereis(Monitor) do
      nil ->
        %{status: "service_not_available"}
      _pid ->
        try do
          GenServer.call(Monitor, :get_metrics, 5000)
        rescue
          _ -> %{status: "error", message: "Failed to get performance metrics"}
        end
    end
  end

  defp calculate_health_score do
    try do
      # Get component health scores
      db_score = case get_database_metrics().status do
        "healthy" -> 25
        _ -> 0
      end
      
      cache_score = case get_cache_metrics().status do
        :healthy -> 25
        _ -> 0
      end
      
      memory_score = case get_memory_utilization() do
        util when util < 70 -> 25
        util when util < 85 -> 15
        _ -> 5
      end
      
      # Base system score
      system_score = 25
      
      total_score = db_score + cache_score + memory_score + system_score
      
      %{
        overall: total_score,
        components: %{
          database: db_score,
          cache: cache_score,
          memory: memory_score,
          system: system_score
        },
        status: cond do
          total_score >= 80 -> "excellent"
          total_score >= 60 -> "good"
          total_score >= 40 -> "fair"
          true -> "poor"
        end
      }
    rescue
      _ -> %{overall: 0, status: "error", message: "Failed to calculate health score"}
    end
  end

  defp check_database_health do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
      {:ok, _} -> "healthy"
      {:error, _} -> "unhealthy"
    end
  rescue
    _ -> "error"
  end

  defp check_redis_health do
    case Process.whereis(:redix) do
      nil -> "not_configured"
      _pid ->
        try do
          case Redix.command(:redix, ["PING"]) do
            {:ok, "PONG"} -> "healthy"
            _ -> "unhealthy"
          end
        rescue
          _ -> "error"
        end
    end
  end

  defp get_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_ms
  end

  defp get_current_load do
    case :cpu_sup.avg1() do
      load when is_number(load) -> load / 256
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp get_memory_stats do
    memory = :erlang.memory()
    total_memory = memory[:total]
    
    %{
      total_bytes: total_memory,
      total_mb: div(total_memory, 1024 * 1024),
      processes_mb: div(memory[:processes], 1024 * 1024),
      system_mb: div(memory[:system], 1024 * 1024),
      utilization_percent: get_memory_utilization()
    }
  end

  defp get_memory_utilization do
    memory = :erlang.memory()
    # Estimate utilization based on total memory vs typical limits
    total_mb = div(memory[:total], 1024 * 1024)
    # Assume 1GB typical limit for calculation
    min(round(total_mb / 10), 100)
  end

  defp get_connection_count do
    # Count active connections through presence or PubSub
    try do
      case Process.whereis(SlackClone.Services.PresenceTracker) do
        nil -> 0
        _pid ->
          case GenServer.call(SlackClone.Services.PresenceTracker, :get_stats, 5000) do
            stats when is_map(stats) -> Map.get(stats, :active_users, 0)
            _ -> 0
          end
      end
    rescue
      _ -> 0
    end
  end

  defp get_recent_errors do
    # For now, return placeholder - would integrate with error tracking
    %{
      count_1h: 0,
      count_24h: 0,
      latest_errors: []
    }
  end

  defp get_response_times do
    # Placeholder for response time metrics
    %{
      avg_response_time_ms: 50,
      p95_response_time_ms: 120,
      p99_response_time_ms: 250
    }
  end

  defp get_database_performance do
    case get_database_metrics() do
      %{status: "healthy", pool: pool_stats} ->
        %{
          active_connections: Map.get(pool_stats, :checked_out, 0),
          pool_utilization: Map.get(pool_stats, :utilization, 0),
          queue_length: Map.get(pool_stats, :queue_length, 0)
        }
      _ ->
        %{
          active_connections: 0,
          pool_utilization: 0,
          queue_length: 0
        }
    end
  end

  defp get_query_cache_size do
    # Placeholder - would implement query cache size tracking
    0
  end
end