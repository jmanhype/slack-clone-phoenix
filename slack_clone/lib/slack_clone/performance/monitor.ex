defmodule SlackClone.Performance.Monitor do
  @moduledoc """
  Comprehensive performance monitoring system with real-time metrics collection,
  bottleneck identification, and automated alerting for the Slack clone application.
  """
  
  use GenServer
  
  alias SlackClone.Performance.{CacheManager, PubSubOptimizer}
  
  # Monitoring intervals
  @metrics_interval 10_000      # 10 seconds
  @cleanup_interval 300_000     # 5 minutes
  @alert_interval 60_000        # 1 minute
  
  # Performance thresholds
  @response_time_threshold 500   # milliseconds
  @cpu_threshold 80             # percentage
  @memory_threshold 85          # percentage
  @cache_hit_ratio_threshold 0.7 # 70%
  
  defmodule Metrics do
    @derive Jason.Encoder
    defstruct [
      :timestamp,
      :response_times,
      :cache_stats,
      :pubsub_stats,
      :system_stats,
      :database_stats,
      :liveview_stats,
      :error_counts,
      :active_connections,
      :message_throughput
    ]
  end
  
  defmodule Alert do
    @derive Jason.Encoder
    defstruct [:type, :severity, :message, :timestamp, :metrics, :acknowledged]
  end
  
  @doc """
  Start the performance monitor.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get current performance metrics.
  """
  def get_current_metrics do
    GenServer.call(__MODULE__, :get_current_metrics)
  end
  
  @doc """
  Get performance metrics for a time range.
  """
  def get_metrics_history(minutes_back \\ 60) do
    GenServer.call(__MODULE__, {:get_metrics_history, minutes_back})
  end
  
  @doc """
  Get active alerts.
  """
  def get_active_alerts do
    GenServer.call(__MODULE__, :get_active_alerts)
  end
  
  @doc """
  Record a response time measurement.
  """
  def record_response_time(operation, duration_ms) do
    GenServer.cast(__MODULE__, {:record_response_time, operation, duration_ms})
  end
  
  @doc """
  Record an error occurrence.
  """
  def record_error(type, details \\ nil) do
    GenServer.cast(__MODULE__, {:record_error, type, details})
  end
  
  @doc """
  Get performance dashboard data.
  """
  def get_dashboard_data do
    GenServer.call(__MODULE__, :get_dashboard_data)
  end
  
  # GenServer callbacks
  
  def init(_opts) do
    # Initialize metrics storage
    :ets.new(:performance_metrics, [:ordered_set, :named_table, :public])
    :ets.new(:performance_alerts, [:set, :named_table, :public])
    :ets.new(:response_times, [:bag, :named_table, :public])
    :ets.new(:error_counts, [:set, :named_table, :public])
    
    # Schedule periodic metrics collection
    schedule_metrics_collection()
    schedule_cleanup()
    schedule_alert_check()
    
    state = %{
      current_metrics: %Metrics{},
      alerts: [],
      response_time_buffer: %{},
      error_count_buffer: %{}
    }
    
    {:ok, state}
  end
  
  def handle_call(:get_current_metrics, _from, state) do
    {:reply, state.current_metrics, state}
  end

  def handle_call(:get_metrics, _from, state) do
    # Return comprehensive metrics for telemetry endpoint
    metrics = %{
      current: state.current_metrics,
      alerts: state.alerts,
      system_health: calculate_system_health(state.current_metrics),
      response_time_stats: calculate_response_time_stats(state.response_time_buffer),
      error_stats: calculate_error_stats(state.error_count_buffer),
      timestamp: System.system_time(:millisecond)
    }
    
    {:reply, metrics, state}
  end
  
  def handle_call({:get_metrics_history, minutes_back}, _from, state) do
    cutoff_time = System.system_time(:millisecond) - (minutes_back * 60 * 1000)
    
    history = 
      :ets.select(:performance_metrics, [
        {
          {:"$1", :"$2"},
          [{:>=, :"$1", cutoff_time}],
          [{{:"$1", :"$2"}}]
        }
      ])
      |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
    
    {:reply, history, state}
  end
  
  def handle_call(:get_active_alerts, _from, state) do
    active_alerts = 
      :ets.tab2list(:performance_alerts)
      |> Enum.map(fn {_id, alert} -> alert end)
      |> Enum.filter(fn alert -> not alert.acknowledged end)
    
    {:reply, active_alerts, state}
  end
  
  def handle_call(:get_dashboard_data, _from, state) do
    dashboard_data = %{
      current_metrics: state.current_metrics,
      recent_alerts: get_recent_alerts(10),
      system_health: calculate_system_health(state.current_metrics),
      performance_trends: get_performance_trends(),
      bottlenecks: identify_bottlenecks(state.current_metrics)
    }
    
    {:reply, dashboard_data, state}
  end
  
  def handle_cast({:record_response_time, operation, duration_ms}, state) do
    current_time = System.system_time(:millisecond)
    :ets.insert(:response_times, {current_time, operation, duration_ms})
    
    # Update buffer for aggregation
    buffer = Map.update(
      state.response_time_buffer,
      operation,
      [duration_ms],
      &[duration_ms | &1]
    )
    
    new_state = %{state | response_time_buffer: buffer}
    {:noreply, new_state}
  end
  
  def handle_cast({:record_error, type, details}, state) do
    key = {type, details}
    count = Map.get(state.error_count_buffer, key, 0) + 1
    
    buffer = Map.put(state.error_count_buffer, key, count)
    new_state = %{state | error_count_buffer: buffer}
    
    {:noreply, new_state}
  end
  
  def handle_info(:collect_metrics, state) do
    metrics = collect_system_metrics(state)
    
    # Store metrics
    timestamp = System.system_time(:millisecond)
    :ets.insert(:performance_metrics, {timestamp, metrics})
    
    # Clear buffers
    new_state = %{
      state |
      current_metrics: metrics,
      response_time_buffer: %{},
      error_count_buffer: %{}
    }
    
    schedule_metrics_collection()
    {:noreply, new_state}
  end
  
  def handle_info(:cleanup_old_data, state) do
    cleanup_old_metrics()
    schedule_cleanup()
    {:noreply, state}
  end
  
  def handle_info(:check_alerts, state) do
    new_alerts = check_for_performance_issues(state.current_metrics)
    
    # Store new alerts
    Enum.each(new_alerts, fn alert ->
      alert_id = System.unique_integer([:positive])
      :ets.insert(:performance_alerts, {alert_id, alert})
    end)
    
    # Send notifications for critical alerts
    Enum.each(new_alerts, &maybe_send_alert_notification/1)
    
    schedule_alert_check()
    {:noreply, state}
  end
  
  def handle_info(_message, state) do
    {:noreply, state}
  end
  
  # Private helper functions
  
  defp collect_system_metrics(state) do
    %Metrics{
      timestamp: System.system_time(:millisecond),
      response_times: aggregate_response_times(state.response_time_buffer),
      cache_stats: collect_cache_stats(),
      pubsub_stats: collect_pubsub_stats(),
      system_stats: collect_system_stats(),
      database_stats: collect_database_stats(),
      liveview_stats: collect_liveview_stats(),
      error_counts: state.error_count_buffer,
      active_connections: count_active_connections(),
      message_throughput: calculate_message_throughput()
    }
  end
  
  defp aggregate_response_times(buffer) do
    Enum.into(buffer, %{}, fn {operation, times} ->
      {operation, %{
        count: length(times),
        avg: Enum.sum(times) / length(times),
        min: Enum.min(times),
        max: Enum.max(times),
        p95: percentile(times, 0.95),
        p99: percentile(times, 0.99)
      }}
    end)
  end
  
  defp collect_cache_stats do
    redis_stats = get_redis_stats()
    cachex_stats = case Cachex.stats(:slack_clone_cache) do
      {:error, :stats_disabled} -> %{status: :stats_disabled}
      {:ok, stats} -> stats
      stats when is_map(stats) -> stats
      _ -> %{status: :error}
    end
    
    %{
      redis: redis_stats,
      cachex: cachex_stats,
      hit_ratio: calculate_cache_hit_ratio(redis_stats, cachex_stats)
    }
  end
  
  defp collect_pubsub_stats do
    try do
      case SlackClone.Performance.PubSubOptimizer.get_subscription_stats() do
        stats when is_map(stats) -> stats
        _ -> %{error: "Failed to collect PubSub stats"}
      end
    rescue
      e ->
        require Logger
        Logger.warning("PubSubOptimizer not available: #{inspect(e)}")
        %{
          batched_channels: 0,
          total_batched_messages: 0,
          active_typing_indicators: 0,
          pending_presence_updates: 0,
          timer_active: false,
          error: "PubSubOptimizer not started"
        }
    catch
      :exit, reason ->
        require Logger
        Logger.warning("PubSubOptimizer process not alive: #{inspect(reason)}")
        %{
          batched_channels: 0,
          total_batched_messages: 0,
          active_typing_indicators: 0,
          pending_presence_updates: 0,
          timer_active: false,
          error: "PubSubOptimizer process not available"
        }
    end
  end
  
  defp collect_system_stats do
    memory_usage = :erlang.memory()
    
    %{
      memory: %{
        total: memory_usage[:total],
        processes: memory_usage[:processes],
        atom: memory_usage[:atom],
        binary: memory_usage[:binary],
        ets: memory_usage[:ets]
      },
      cpu_usage: get_cpu_usage(),
      process_count: :erlang.system_info(:process_count),
      port_count: :erlang.system_info(:port_count),
      run_queue_length: :erlang.statistics(:run_queue_lengths) |> Enum.sum(),
      gc_stats: convert_gc_stats(:erlang.statistics(:garbage_collection))
    }
  end
  
  defp collect_database_stats do
    # Database connection pool stats with error handling
    pool_stats = try do
      case SlackClone.Repo.get_pool_status() do
        {:ok, stats} -> stats
        {:error, reason} -> 
          Logger.debug("Failed to get pool stats: #{reason}")
          %{error: reason, pool_size: 0, checked_out: 0, utilization: 0.0}
        _ -> 
          %{error: "Unknown pool stats error", pool_size: 0, checked_out: 0, utilization: 0.0}
      end
    rescue
      e ->
        Logger.debug("Exception getting pool stats: #{inspect(e)}")
        %{error: "Exception: #{inspect(e)}", pool_size: 0, checked_out: 0, utilization: 0.0}
    end
    
    # Query execution metrics with safe defaults
    %{
      pool: pool_stats,
      active_connections: get_db_active_connections(),
      query_queue_length: get_db_query_queue_length(),
      slow_queries: get_slow_query_count()
    }
  end
  
  defp collect_liveview_stats do
    # LiveView connection and process statistics
    %{
      active_sockets: count_liveview_sockets(),
      memory_usage: get_liveview_memory_usage(),
      message_queue_lengths: get_liveview_message_queues()
    }
  end
  
  defp count_active_connections do
    # Count active connections through presence tracker stats
    try do
      case Process.whereis(SlackClone.Services.PresenceTracker) do
        nil -> 0
        _pid ->
          case GenServer.call(SlackClone.Services.PresenceTracker, :get_stats, 5000) do
            stats when is_map(stats) -> 
              Map.get(stats, :active_users, 0)
            _ -> 0
          end
      end
    rescue
      _ -> 0
    end
  end
  
  defp calculate_message_throughput do
    # Calculate messages per second over last minute
    cutoff = System.system_time(:millisecond) - 60_000
    
    message_count = 
      :ets.select_count(:response_times, [
        {
          {:"$1", :"send_message", :"$3"},
          [{:>=, :"$1", cutoff}],
          [true]
        }
      ])
    
    message_count / 60.0  # messages per second
  end
  
  defp check_for_performance_issues(metrics) do
    alerts = []
    
    # Check response time alerts
    alerts = check_response_time_alerts(metrics.response_times, alerts)
    
    # Check system resource alerts
    alerts = check_system_resource_alerts(metrics.system_stats, alerts)
    
    # Check cache performance alerts
    alerts = check_cache_performance_alerts(metrics.cache_stats, alerts)
    
    # Check database performance alerts
    alerts = check_database_alerts(metrics.database_stats, alerts)
    
    # Check error rate alerts
    alerts = check_error_rate_alerts(metrics.error_counts, alerts)
    
    alerts
  end
  
  defp check_response_time_alerts(response_times, alerts) do
    Enum.reduce(response_times, alerts, fn {operation, stats}, acc ->
      cond do
        stats.avg > @response_time_threshold ->
          alert = %Alert{
            type: :high_response_time,
            severity: :warning,
            message: "High average response time for #{operation}: #{stats.avg}ms",
            timestamp: System.system_time(:millisecond),
            metrics: stats,
            acknowledged: false
          }
          [alert | acc]
        
        stats.p95 > (@response_time_threshold * 2) ->
          alert = %Alert{
            type: :very_high_response_time,
            severity: :critical,
            message: "Very high P95 response time for #{operation}: #{stats.p95}ms",
            timestamp: System.system_time(:millisecond),
            metrics: stats,
            acknowledged: false
          }
          [alert | acc]
        
        true ->
          acc
      end
    end)
  end
  
  defp check_system_resource_alerts(system_stats, alerts) do
    alerts = if system_stats.cpu_usage > @cpu_threshold do
      alert = %Alert{
        type: :high_cpu_usage,
        severity: :warning,
        message: "High CPU usage: #{system_stats.cpu_usage}%",
        timestamp: System.system_time(:millisecond),
        metrics: system_stats,
        acknowledged: false
      }
      [alert | alerts]
    else
      alerts
    end
    
    memory_usage_percent = (system_stats.memory.total / (1024 * 1024 * 1024)) * 100
    
    if memory_usage_percent > @memory_threshold do
      alert = %Alert{
        type: :high_memory_usage,
        severity: :warning,
        message: "High memory usage: #{memory_usage_percent}%",
        timestamp: System.system_time(:millisecond),
        metrics: system_stats,
        acknowledged: false
      }
      [alert | alerts]
    else
      alerts
    end
  end
  
  defp check_cache_performance_alerts(cache_stats, alerts) do
    if cache_stats.hit_ratio < @cache_hit_ratio_threshold do
      alert = %Alert{
        type: :low_cache_hit_ratio,
        severity: :warning,
        message: "Low cache hit ratio: #{cache_stats.hit_ratio * 100}%",
        timestamp: System.system_time(:millisecond),
        metrics: cache_stats,
        acknowledged: false
      }
      [alert | alerts]
    else
      alerts
    end
  end
  
  defp check_database_alerts(db_stats, alerts) do
    # Check for database connection pool exhaustion
    pool_size = db_stats.pool[:size] || 1
    checked_out = db_stats.pool[:checked_out] || 0
    alerts = if pool_size > 0 && checked_out / pool_size > 0.9 do
      alert = %Alert{
        type: :database_pool_exhaustion,
        severity: :critical,
        message: "Database connection pool nearly exhausted",
        timestamp: System.system_time(:millisecond),
        metrics: db_stats,
        acknowledged: false
      }
      [alert | alerts]
    else
      alerts
    end
    
    # Check for slow queries
    if db_stats.slow_queries > 10 do
      alert = %Alert{
        type: :high_slow_query_count,
        severity: :warning,
        message: "High number of slow queries: #{db_stats.slow_queries}",
        timestamp: System.system_time(:millisecond),
        metrics: db_stats,
        acknowledged: false
      }
      [alert | alerts]
    else
      alerts
    end
  end
  
  defp check_error_rate_alerts(error_counts, alerts) do
    total_errors = Enum.reduce(error_counts, 0, fn {_type, count}, acc -> acc + count end)
    
    if total_errors > 50 do  # More than 50 errors in the last interval
      alert = %Alert{
        type: :high_error_rate,
        severity: :critical,
        message: "High error rate: #{total_errors} errors in last interval",
        timestamp: System.system_time(:millisecond),
        metrics: error_counts,
        acknowledged: false
      }
      [alert | alerts]
    else
      alerts
    end
  end
  
  defp identify_bottlenecks(metrics) do
    bottlenecks = []
    
    # Identify response time bottlenecks
    slowest_operations = 
      metrics.response_times
      |> Enum.sort_by(fn {_op, stats} -> stats.avg end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {op, stats} -> 
        %{type: :response_time, operation: op, avg_time: stats.avg}
      end)
    
    # Identify resource bottlenecks
    resource_bottlenecks = []
    
    resource_bottlenecks = if metrics.system_stats.cpu_usage > 70 do
      [%{type: :cpu, usage: metrics.system_stats.cpu_usage} | resource_bottlenecks]
    else
      resource_bottlenecks
    end
    
    memory_usage_gb = metrics.system_stats.memory.total / (1024 * 1024 * 1024)
    resource_bottlenecks = if memory_usage_gb > 2 do
      [%{type: :memory, usage_gb: memory_usage_gb} | resource_bottlenecks]
    else
      resource_bottlenecks
    end
    
    # Identify database bottlenecks
    db_bottlenecks = []
    
    db_bottlenecks = if metrics.database_stats.query_queue_length > 10 do
      [%{type: :db_queue, length: metrics.database_stats.query_queue_length} | db_bottlenecks]
    else
      db_bottlenecks
    end
    
    slowest_operations ++ resource_bottlenecks ++ db_bottlenecks
  end
  
  defp calculate_system_health(metrics) do
    # Calculate overall system health score (0-100)
    scores = []
    
    # Response time score (lower is better)
    avg_response_time = 
      metrics.response_times
      |> Enum.map(fn {_op, stats} -> stats.avg end)
      |> case do
        [] -> 0
        times -> Enum.sum(times) / length(times)
      end
    
    response_score = max(0, 100 - (avg_response_time / 10))
    scores = [response_score | scores]
    
    # CPU score
    cpu_score = max(0, 100 - metrics.system_stats.cpu_usage)
    scores = [cpu_score | scores]
    
    # Memory score
    memory_usage_gb = metrics.system_stats.memory.total / (1024 * 1024 * 1024)
    memory_score = max(0, 100 - (memory_usage_gb * 25))  # Assume 4GB is max
    scores = [memory_score | scores]
    
    # Cache score
    cache_score = metrics.cache_stats.hit_ratio * 100
    scores = [cache_score | scores]
    
    # Calculate weighted average
    Enum.sum(scores) / length(scores)
  end
  
  defp get_performance_trends do
    # Get last hour of data
    cutoff_time = System.system_time(:millisecond) - (60 * 60 * 1000)
    
    metrics_history = 
      :ets.select(:performance_metrics, [
        {
          {:"$1", :"$2"},
          [{:>=, :"$1", cutoff_time}],
          [{{:"$1", :"$2"}}]
        }
      ])
      |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
    
    case metrics_history do
      [] -> %{trend: :unknown}
      [_single] -> %{trend: :insufficient_data}
      history ->
        # Calculate trends for key metrics
        response_times = Enum.map(history, fn {_time, metrics} ->
          case metrics.response_times do
            map when map_size(map) > 0 ->
              (map |> Map.values() |> Enum.map(& &1.avg) |> Enum.sum()) / map_size(map)
            _ -> 0
          end
        end)
        
        cpu_usages = Enum.map(history, fn {_time, metrics} ->
          metrics.system_stats.cpu_usage
        end)
        
        %{
          response_time_trend: calculate_trend(response_times),
          cpu_trend: calculate_trend(cpu_usages),
          overall_trend: calculate_overall_trend(history)
        }
    end
  end
  
  defp calculate_trend(values) when length(values) < 2, do: :stable
  defp calculate_trend(values) do
    # Simple trend calculation
    first_half = values |> Enum.take(div(length(values), 2)) |> Enum.sum()
    second_half = values |> Enum.drop(div(length(values), 2)) |> Enum.sum()
    
    first_avg = first_half / div(length(values), 2)
    second_avg = second_half / (length(values) - div(length(values), 2))
    
    cond do
      second_avg > first_avg * 1.1 -> :increasing
      second_avg < first_avg * 0.9 -> :decreasing
      true -> :stable
    end
  end
  
  defp calculate_overall_trend(history) do
    # Calculate overall system health trend
    health_scores = Enum.map(history, fn {_time, metrics} ->
      calculate_system_health(metrics)
    end)
    
    calculate_trend(health_scores)
  end
  
  defp get_recent_alerts(limit) do
    :ets.tab2list(:performance_alerts)
    |> Enum.map(fn {_id, alert} -> alert end)
    |> Enum.sort_by(& &1.timestamp, :desc)
    |> Enum.take(limit)
  end
  
  defp maybe_send_alert_notification(%Alert{severity: :critical} = alert) do
    # Send critical alerts immediately
    Phoenix.PubSub.broadcast(
      SlackClone.PubSub,
      "admin:alerts",
      {:critical_alert, alert}
    )
  end
  
  defp maybe_send_alert_notification(_alert), do: :ok
  
  defp schedule_metrics_collection do
    Process.send_after(self(), :collect_metrics, @metrics_interval)
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_old_data, @cleanup_interval)
  end
  
  defp schedule_alert_check do
    Process.send_after(self(), :check_alerts, @alert_interval)
  end
  
  defp cleanup_old_metrics do
    # Remove metrics older than 24 hours
    cutoff_time = System.system_time(:millisecond) - (24 * 60 * 60 * 1000)
    
    :ets.select_delete(:performance_metrics, [
      {
        {:"$1", :"$2"},
        [{:<, :"$1", cutoff_time}],
        [true]
      }
    ])
    
    # Clean up old response time entries
    :ets.select_delete(:response_times, [
      {
        {:"$1", :"$2", :"$3"},
        [{:<, :"$1", cutoff_time}],
        [true]
      }
    ])
  end
  
  # Mock functions - these would need to be implemented based on your infrastructure
  
  defp get_redis_stats do
    case Redix.command(:redix, ["INFO", "stats"]) do
      {:ok, info} -> parse_redis_info(info)
      _ -> %{error: "Failed to get Redis stats"}
    end
  end
  
  defp parse_redis_info(info) do
    # Parse Redis INFO output
    %{
      total_commands_processed: 0,
      keyspace_hits: 0,
      keyspace_misses: 0,
      used_memory: 0
    }
  end
  
  defp calculate_cache_hit_ratio(redis_stats, _cachex_stats) do
    case redis_stats do
      %{keyspace_hits: hits, keyspace_misses: misses} when hits + misses > 0 ->
        hits / (hits + misses)
      _ -> 0.0
    end
  end
  
  defp get_cpu_usage, do: 0  # Would use :cpu_sup or similar
  defp get_db_active_connections, do: 0
  defp get_db_query_queue_length, do: 0
  defp get_slow_query_count, do: 0
  defp count_liveview_sockets, do: 0
  defp get_liveview_memory_usage, do: 0
  defp get_liveview_message_queues, do: []
  
  defp percentile(values, p) when length(values) > 0 do
    sorted = Enum.sort(values)
    index = round(p * (length(sorted) - 1))
    Enum.at(sorted, index)
  end
  
  defp percentile([], _p), do: 0

  @doc """
  Emit health metrics for telemetry system.
  """
  def emit_health_metrics do
    try do
      case GenServer.call(__MODULE__, :get_metrics, 5000) do
        %Metrics{} = metrics ->
          :telemetry.execute(
            [:slack_clone, :performance, :health],
            %{
              response_time_avg: calculate_avg_response_time(metrics.response_times),
              cache_hit_ratio: get_cache_hit_ratio(metrics.cache_stats),
              memory_usage: get_memory_usage_percent(metrics.system_stats),
              active_connections: metrics.active_connections || 0,
              error_rate: calculate_error_rate(metrics.error_counts)
            },
            %{source: :performance_monitor}
          )

        _ ->
          :telemetry.execute(
            [:slack_clone, :performance, :health],
            %{
              response_time_avg: 0,
              cache_hit_ratio: 0.0,
              memory_usage: 0,
              active_connections: 0,
              error_rate: 0.0
            },
            %{source: :performance_monitor, status: :unavailable}
          )
      end
    rescue
      e ->
        require Logger
        Logger.warning("Failed to emit health metrics: #{inspect(e)}")
        
        :telemetry.execute(
          [:slack_clone, :performance, :health],
          %{
            response_time_avg: 0,
            cache_hit_ratio: 0.0,
            memory_usage: 0,
            active_connections: 0,
            error_rate: 0.0
          },
          %{source: :performance_monitor, status: :error}
        )
    end
  end

  defp calculate_response_time_stats(response_time_buffer) do
    if map_size(response_time_buffer) == 0 do
      %{avg: 0, min: 0, max: 0, p95: 0, p99: 0, count: 0}
    else
      all_times = 
        response_time_buffer
        |> Map.values()
        |> List.flatten()
        |> Enum.sort()
      
      count = length(all_times)
      
      if count == 0 do
        %{avg: 0, min: 0, max: 0, p95: 0, p99: 0, count: 0}
      else
        avg = Enum.sum(all_times) / count
        min_time = List.first(all_times)
        max_time = List.last(all_times)
        p95_index = round(count * 0.95) - 1
        p99_index = round(count * 0.99) - 1
        p95 = Enum.at(all_times, max(p95_index, 0))
        p99 = Enum.at(all_times, max(p99_index, 0))
        
        %{
          avg: round(avg * 100) / 100,
          min: min_time,
          max: max_time,
          p95: p95,
          p99: p99,
          count: count
        }
      end
    end
  end

  defp calculate_error_stats(error_count_buffer) do
    total_errors = 
      error_count_buffer
      |> Map.values()
      |> Enum.sum()
    
    %{
      total_errors: total_errors,
      error_types: error_count_buffer,
      error_rate: if(total_errors > 0, do: total_errors / 100, else: 0.0)
    }
  end

  defp calculate_avg_response_time(response_times) when is_list(response_times) and length(response_times) > 0 do
    Enum.sum(response_times) / length(response_times)
  end
  defp calculate_avg_response_time(_), do: 0

  defp get_cache_hit_ratio(%{hit_ratio: ratio}) when is_number(ratio), do: ratio
  defp get_cache_hit_ratio(_), do: 0.0

  defp get_memory_usage_percent(%{memory_usage: usage}) when is_number(usage), do: usage
  defp get_memory_usage_percent(_), do: 0

  defp calculate_error_rate(%{total: total, errors: errors}) when total > 0, do: errors / total
  defp calculate_error_rate(_), do: 0.0

  # Convert garbage collection stats tuple to JSON-encodable map
  defp convert_gc_stats({number_of_gcs, words_reclaimed, reductions_during_gc}) do
    %{
      number_of_gcs: number_of_gcs,
      words_reclaimed: words_reclaimed,
      reductions_during_gc: reductions_during_gc
    }
  end
  defp convert_gc_stats(_), do: %{number_of_gcs: 0, words_reclaimed: 0, reductions_during_gc: 0}
end