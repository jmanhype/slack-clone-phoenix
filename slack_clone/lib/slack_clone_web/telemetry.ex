defmodule SlackCloneWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 5_000ms for more granular performance monitoring
      {:telemetry_poller, measurements: periodic_measurements(), period: 5_000}
      # Performance monitoring integration is now handled by SlackClone.Services.Supervisor
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        tags: extract_phoenix_tags()
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route, :status],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond},
        tags: [:transport]
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond},
        tags: [:topic]
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event, :topic],
        unit: {:native, :millisecond}
      ),

      # LiveView Performance Metrics
      summary("phoenix.live_view.mount.duration",
        unit: {:native, :millisecond},
        tags: [:view]
      ),
      summary("phoenix.live_view.handle_event.duration",
        unit: {:native, :millisecond},
        tags: [:view, :event]
      ),
      summary("phoenix.live_view.render.duration",
        unit: {:native, :millisecond},
        tags: [:view]
      ),
      counter("phoenix.live_view.diff.count",
        tags: [:view]
      ),
      summary("phoenix.live_view.diff.size",
        unit: :byte,
        tags: [:view]
      ),

      # Database Metrics
      summary("slack_clone.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements",
        tags: extract_db_tags()
      ),
      summary("slack_clone.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database",
        tags: extract_db_tags()
      ),
      summary("slack_clone.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query",
        tags: extract_db_tags()
      ),
      summary("slack_clone.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection",
        tags: extract_db_tags()
      ),
      summary("slack_clone.repo.query.idle_time",
        unit: {:native, :millisecond},
        description: "The time the connection spent waiting before being checked out for the query",
        tags: extract_db_tags()
      ),
      counter("slack_clone.repo.query.slow_queries",
        description: "Number of slow queries (>500ms)"
      ),

      # Cache Performance Metrics
      counter("slack_clone.cache.hits",
        tags: [:cache_type, :key_pattern]
      ),
      counter("slack_clone.cache.misses",
        tags: [:cache_type, :key_pattern]
      ),
      summary("slack_clone.cache.fetch_time",
        unit: {:native, :millisecond},
        tags: [:cache_type, :operation]
      ),
      counter("slack_clone.cache.invalidations",
        tags: [:cache_type, :reason]
      ),
      summary("slack_clone.cache.memory_usage",
        unit: {:byte, :megabyte},
        tags: [:cache_type]
      ),

      # PubSub Performance Metrics
      counter("slack_clone.pubsub.messages_sent",
        tags: [:topic_pattern, :batch_size]
      ),
      summary("slack_clone.pubsub.broadcast_time",
        unit: {:native, :millisecond},
        tags: [:topic_pattern, :subscriber_count]
      ),
      counter("slack_clone.pubsub.batch_operations",
        tags: [:operation_type]
      ),
      summary("slack_clone.pubsub.presence_update_time",
        unit: {:native, :millisecond},
        tags: [:channel_type]
      ),

      # Connection Pool Metrics
      summary("slack_clone.pool.checkout_time",
        unit: {:native, :millisecond},
        tags: [:pool_name]
      ),
      last_value("slack_clone.pool.active_connections",
        tags: [:pool_name]
      ),
      last_value("slack_clone.pool.idle_connections",
        tags: [:pool_name]
      ),
      counter("slack_clone.pool.timeouts",
        tags: [:pool_name]
      ),
      last_value("slack_clone.pool.utilization_ratio",
        tags: [:pool_name]
      ),

      # Virtual Scrolling Performance
      summary("slack_clone.virtual_scroll.render_time",
        unit: {:native, :millisecond},
        tags: [:component_type]
      ),
      counter("slack_clone.virtual_scroll.items_rendered",
        tags: [:component_type]
      ),
      summary("slack_clone.virtual_scroll.scroll_performance",
        unit: {:native, :millisecond},
        tags: [:scroll_direction]
      ),

      # Edge Cache Metrics
      counter("slack_clone.edge_cache.requests",
        tags: [:region, :cache_status]
      ),
      summary("slack_clone.edge_cache.response_time",
        unit: {:native, :millisecond},
        tags: [:region, :content_type]
      ),
      last_value("slack_clone.edge_cache.hit_ratio",
        tags: [:region]
      ),

      # VM Metrics (Enhanced)
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.memory.processes", unit: {:byte, :kilobyte}),
      summary("vm.memory.atom", unit: {:byte, :kilobyte}),
      summary("vm.memory.binary", unit: {:byte, :kilobyte}),
      summary("vm.memory.ets", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),
      last_value("vm.system_counts.process_count"),
      last_value("vm.system_counts.atom_count"),
      last_value("vm.system_counts.port_count"),

      # Custom Performance Metrics
      summary("slack_clone.performance.response_time",
        unit: {:native, :millisecond},
        tags: [:endpoint, :method]
      ),
      counter("slack_clone.performance.bottlenecks",
        tags: [:component, :severity]
      ),
      last_value("slack_clone.performance.health_score"),
      counter("slack_clone.performance.alerts",
        tags: [:alert_type, :severity]
      )
    ]
  end

  defp periodic_measurements do
    [
      # System health measurements - these should always work
      {__MODULE__, :dispatch_system_health, []},
      {__MODULE__, :dispatch_cache_stats, []},
      {__MODULE__, :dispatch_pool_stats, []},
      {__MODULE__, :dispatch_performance_health, []}
      # Note: Performance services measurements removed until services are properly started
      # These will be added back when the supervision tree is fixed:
      # {SlackClone.Performance.ConnectionPoolOptimizer, :emit_pool_metrics, []},
      # {SlackClone.Performance.Monitor, :emit_health_metrics, []},
      # {SlackClone.Performance.CacheManager, :emit_cache_metrics, []}
    ]
  end

  # System health telemetry
  def dispatch_system_health do
    memory = :erlang.memory()
    system_info = :erlang.system_info(:system_version)
    
    :telemetry.execute([:vm, :memory], %{
      total: memory[:total],
      processes: memory[:processes],
      atom: memory[:atom],
      binary: memory[:binary],
      ets: memory[:ets]
    })

    system_counts = %{
      process_count: :erlang.system_info(:process_count),
      atom_count: :erlang.system_info(:atom_count),
      port_count: :erlang.system_info(:port_count)
    }

    :telemetry.execute([:vm, :system_counts], system_counts)
  end

  def dispatch_cache_stats do
    # Emit cache statistics from various cache layers
    if Code.ensure_loaded?(SlackClone.Performance.CacheManager) do
      try do
        stats = SlackClone.Performance.CacheManager.get_stats()
        
        :telemetry.execute(
          [:slack_clone, :cache, :stats],
          %{
            hit_ratio: stats.hit_ratio || 0.0,
            total_keys: stats.total_keys || 0,
            memory_usage: stats.memory_usage || 0
          },
          %{cache_type: :redis}
        )
      rescue
        e ->
          # Log error but don't crash telemetry when Redis isn't available
          require Logger
          Logger.warning("Failed to get cache stats for telemetry: #{inspect(e)}")
      end
    end
  end

  def dispatch_pool_stats do
    # Database connection pool statistics
    if Code.ensure_loaded?(SlackClone.Repo) do
      case SlackClone.Repo.get_pool_status() do
        {:ok, pool_status} ->
          :telemetry.execute(
            [:slack_clone, :pool, :status],
            %{
              pool_size: pool_status.pool_size || 0,
              checked_out: pool_status.checked_out || 0,
              queue_length: pool_status.queue_length || 0,
              utilization: pool_status.utilization || 0.0
            },
            %{pool_name: :main}
          )
        {:error, reason} ->
          # Log error but don't crash telemetry
          require Logger
          Logger.warning("Failed to get pool status for telemetry: #{inspect(reason)}")
      end
    end
  end

  def dispatch_performance_health do
    # Overall performance health score
    health_score = calculate_health_score()
    
    :telemetry.execute(
      [:slack_clone, :performance, :health_score],
      %{score: health_score},
      %{}
    )
  end

  # Tag extraction functions for enhanced metrics
  defp extract_phoenix_tags do
    [:method, :status, :route]
  end

  defp extract_db_tags do
    [:source, :command, :result]
  end

  # Calculate overall system health score (0-100)
  defp calculate_health_score do
    memory_score = calculate_memory_health()
    cpu_score = calculate_cpu_health()
    db_score = calculate_db_health()
    
    # Weighted average
    (memory_score * 0.3 + cpu_score * 0.3 + db_score * 0.4)
    |> round()
  end

  defp calculate_memory_health do
    memory = :erlang.memory()
    total_memory = memory[:total]
    
    # Simplified health calculation based on memory usage
    # In production, you'd want more sophisticated thresholds
    case total_memory do
      mem when mem < 100_000_000 -> 100  # < 100MB = excellent
      mem when mem < 500_000_000 -> 80   # < 500MB = good
      mem when mem < 1_000_000_000 -> 60 # < 1GB = fair
      _ -> 30                            # > 1GB = poor
    end
  end

  defp calculate_cpu_health do
    # CPU health based on scheduler utilization
    try do
      # Use erlang:statistics instead of :scheduler.sample_all()
      scheduler_usage = :erlang.statistics(:scheduler_wall_time_all)
      
      # Calculate average CPU utilization from scheduler wall time data
      avg_utilization = case scheduler_usage do
        schedulers when is_list(schedulers) ->
          total_usage = schedulers
          |> Enum.map(fn 
            {_type, _id, active_time, total_time} when total_time > 0 ->
              active_time / total_time
            _ -> 0.0
          end)
          |> Enum.sum()
          
          if length(schedulers) > 0 do
            total_usage / length(schedulers)
          else
            0.0
          end
        _ -> 0.0
      end
      
      case avg_utilization do
        util when util < 0.5 -> 100   # < 50% = excellent
        util when util < 0.7 -> 80    # < 70% = good  
        util when util < 0.85 -> 60   # < 85% = fair
        _ -> 30                       # > 85% = poor
      end
    rescue
      _e ->
        # Fallback to a reasonable default if scheduler stats fail
        85  # Assume good health if can't measure
    end
  end

  defp calculate_db_health do
    # Database health based on connection pool status
    # This is a simplified calculation
    90 # Default good score - would be enhanced with real pool metrics
  end
end
