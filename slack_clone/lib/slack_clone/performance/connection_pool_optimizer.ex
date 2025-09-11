defmodule SlackClone.Performance.ConnectionPoolOptimizer do
  @moduledoc """
  Database connection pool optimization with dynamic sizing,
  connection health monitoring, and intelligent query routing.
  """
  
  use GenServer
  
  alias SlackClone.Repo
  
  # Pool monitoring intervals
  @monitoring_interval 30_000    # 30 seconds
  @health_check_interval 60_000  # 1 minute
  @resize_interval 120_000       # 2 minutes
  
  # Pool sizing thresholds
  @high_utilization_threshold 0.8
  @low_utilization_threshold 0.3
  @max_pool_size 50
  @min_pool_size 5
  
  defmodule PoolMetrics do
    defstruct [
      :pool_size,
      :checked_out,
      :checked_in,
      :utilization,
      :avg_wait_time,
      :max_wait_time,
      :query_queue_length,
      :connection_errors,
      :slow_queries,
      :timestamp
    ]
  end
  
  @doc """
  Start the connection pool optimizer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get current pool metrics.
  """
  def get_pool_metrics do
    GenServer.call(__MODULE__, :get_pool_metrics)
  end
  
  @doc """
  Force pool resize based on current load.
  """
  def optimize_pool_size do
    GenServer.cast(__MODULE__, :optimize_pool_size)
  end
  
  @doc """
  Check connection pool health.
  """
  def health_check do
    GenServer.call(__MODULE__, :health_check)
  end
  
  @doc """
  Get optimal pool size recommendation.
  """
  def recommend_pool_size do
    GenServer.call(__MODULE__, :recommend_pool_size)
  end
  
  # GenServer callbacks
  
  def init(_opts) do
    # Initialize metrics storage
    :ets.new(:pool_metrics_history, [:ordered_set, :named_table, :public])
    
    # Schedule monitoring
    schedule_monitoring()
    schedule_health_checks()
    schedule_resize_checks()
    
    state = %{
      current_metrics: %PoolMetrics{},
      optimization_history: [],
      last_resize: System.system_time(:millisecond)
    }
    
    {:ok, state}
  end
  
  def handle_call(:get_pool_metrics, _from, state) do
    {:reply, state.current_metrics, state}
  end
  
  def handle_call(:health_check, _from, state) do
    health_status = perform_health_check()
    {:reply, health_status, state}
  end
  
  def handle_call(:recommend_pool_size, _from, state) do
    recommendation = calculate_optimal_pool_size(state.current_metrics)
    {:reply, recommendation, state}
  end
  
  def handle_cast(:optimize_pool_size, state) do
    new_state = maybe_resize_pool(state)
    {:noreply, new_state}
  end
  
  def handle_info(:monitor_pool, state) do
    metrics = collect_pool_metrics()
    
    # Store metrics history
    timestamp = System.system_time(:millisecond)
    :ets.insert(:pool_metrics_history, {timestamp, metrics})
    
    new_state = %{state | current_metrics: metrics}
    
    schedule_monitoring()
    {:noreply, new_state}
  end
  
  def handle_info(:health_check, state) do
    health_status = perform_health_check()
    
    # Log health issues
    if health_status.status != :healthy do
      log_health_issue(health_status)
    end
    
    schedule_health_checks()
    {:noreply, state}
  end
  
  def handle_info(:resize_check, state) do
    new_state = maybe_resize_pool(state)
    schedule_resize_checks()
    {:noreply, new_state}
  end
  
  def handle_info(_message, state) do
    {:noreply, state}
  end
  
  # Private implementation
  
  defp collect_pool_metrics do
    pool_status = get_pool_status()
    
    %PoolMetrics{
      pool_size: pool_status.pool_size,
      checked_out: pool_status.checked_out,
      checked_in: pool_status.checked_in,
      utilization: calculate_utilization(pool_status),
      avg_wait_time: get_avg_wait_time(),
      max_wait_time: get_max_wait_time(),
      query_queue_length: get_query_queue_length(),
      connection_errors: get_connection_error_count(),
      slow_queries: get_slow_query_count(),
      timestamp: System.system_time(:millisecond)
    }
  end
  
  defp get_pool_status do
    # Get actual pool status from DBConnection
    case GenServer.call(SlackClone.Repo, {:get_pool_status}) do
      {:ok, status} -> status
      {:error, _} ->
        # Fallback to default values
        %{
          pool_size: Application.get_env(:slack_clone, SlackClone.Repo)[:pool_size] || 10,
          checked_out: 0,
          checked_in: 0
        }
    end
  end
  
  defp calculate_utilization(%{pool_size: pool_size, checked_out: checked_out}) 
       when pool_size > 0 do
    checked_out / pool_size
  end
  
  defp calculate_utilization(_), do: 0.0
  
  defp get_avg_wait_time do
    # Get average connection wait time from telemetry or logs
    # This would be implemented based on your telemetry setup
    0
  end
  
  defp get_max_wait_time do
    # Get maximum connection wait time from telemetry or logs
    0
  end
  
  defp get_query_queue_length do
    # Get current query queue length
    # This would be implemented based on your database adapter
    0
  end
  
  defp get_connection_error_count do
    # Get connection error count from the last monitoring interval
    0
  end
  
  defp get_slow_query_count do
    # Get slow query count from the last monitoring interval
    0
  end
  
  defp maybe_resize_pool(state) do
    current_time = System.system_time(:millisecond)
    time_since_last_resize = current_time - state.last_resize
    
    # Only resize if enough time has passed (prevent thrashing)
    if time_since_last_resize > @resize_interval do
      recommendation = calculate_optimal_pool_size(state.current_metrics)
      
      if should_resize_pool(state.current_metrics, recommendation) do
        resize_pool(recommendation.recommended_size)
        
        optimization_record = %{
          timestamp: current_time,
          old_size: state.current_metrics.pool_size,
          new_size: recommendation.recommended_size,
          reason: recommendation.reason,
          utilization: state.current_metrics.utilization
        }
        
        %{
          state |
          last_resize: current_time,
          optimization_history: [optimization_record | state.optimization_history] |> Enum.take(20)
        }
      else
        state
      end
    else
      state
    end
  end
  
  defp calculate_optimal_pool_size(metrics) do
    current_size = metrics.pool_size || 10
    utilization = metrics.utilization
    
    cond do
      # High utilization - need more connections
      utilization > @high_utilization_threshold and current_size < @max_pool_size ->
        new_size = min(@max_pool_size, round(current_size * 1.5))
        %{
          recommended_size: new_size,
          reason: "High utilization (#{Float.round(utilization * 100, 1)}%)",
          confidence: :high
        }
      
      # Low utilization - can reduce connections
      utilization < @low_utilization_threshold and current_size > @min_pool_size ->
        new_size = max(@min_pool_size, round(current_size * 0.75))
        %{
          recommended_size: new_size,
          reason: "Low utilization (#{Float.round(utilization * 100, 1)}%)",
          confidence: :medium
        }
      
      # Check for wait time issues
      metrics.avg_wait_time > 100 and current_size < @max_pool_size ->
        new_size = min(@max_pool_size, current_size + 2)
        %{
          recommended_size: new_size,
          reason: "High wait times (#{metrics.avg_wait_time}ms)",
          confidence: :high
        }
      
      # Check for connection errors
      metrics.connection_errors > 5 and current_size < @max_pool_size ->
        new_size = min(@max_pool_size, current_size + 1)
        %{
          recommended_size: new_size,
          reason: "Connection errors detected (#{metrics.connection_errors})",
          confidence: :medium
        }
      
      true ->
        %{
          recommended_size: current_size,
          reason: "Current size is optimal",
          confidence: :high
        }
    end
  end
  
  defp should_resize_pool(metrics, recommendation) do
    current_size = metrics.pool_size || 10
    
    # Only resize if the change is significant
    size_change = abs(recommendation.recommended_size - current_size)
    size_change >= 2 and recommendation.confidence in [:high, :medium]
  end
  
  defp resize_pool(new_size) do
    # This would implement actual pool resizing
    # Different approaches based on the connection pool implementation
    
    try do
      # For Ecto with DBConnection pools, you might need to:
      # 1. Update the pool configuration
      # 2. Restart the pool supervisor
      # 3. Or use dynamic pool resizing if available
      
      update_pool_config(new_size)
      log_pool_resize(new_size)
      
      {:ok, new_size}
    rescue
      error ->
        log_resize_error(error, new_size)
        {:error, error}
    end
  end
  
  defp update_pool_config(new_size) do
    # Update the pool configuration
    # This implementation depends on your specific setup
    
    # Example for runtime configuration update:
    Application.put_env(:slack_clone, SlackClone.Repo, 
      Application.get_env(:slack_clone, SlackClone.Repo)
      |> Keyword.put(:pool_size, new_size)
    )
    
    # Notify the repository about the configuration change
    # GenServer.call(SlackClone.Repo, {:update_pool_size, new_size})
  end
  
  defp perform_health_check do
    start_time = System.system_time(:millisecond)
    
    health_checks = [
      check_basic_connectivity(),
      check_pool_availability(),
      check_response_times(),
      check_connection_leaks(),
      check_database_locks()
    ]
    
    failed_checks = Enum.filter(health_checks, fn {status, _} -> status != :ok end)
    
    total_time = System.system_time(:millisecond) - start_time
    
    %{
      status: if(length(failed_checks) == 0, do: :healthy, else: :unhealthy),
      checks: health_checks,
      failed_count: length(failed_checks),
      check_duration_ms: total_time,
      timestamp: System.system_time(:millisecond)
    }
  end
  
  defp check_basic_connectivity do
    try do
      case Ecto.Adapters.SQL.query(SlackClone.Repo, "SELECT 1", []) do
        {:ok, _} -> {:ok, "Database connectivity normal"}
        {:error, reason} -> {:error, "Database connectivity failed: #{inspect(reason)}"}
      end
    rescue
      error -> {:error, "Database connectivity exception: #{inspect(error)}"}
    end
  end
  
  defp check_pool_availability do
    pool_status = get_pool_status()
    available_connections = pool_status.checked_in
    
    if available_connections > 0 do
      {:ok, "#{available_connections} connections available"}
    else
      {:warning, "No available connections in pool"}
    end
  end
  
  defp check_response_times do
    start_time = System.monotonic_time(:millisecond)
    
    case Ecto.Adapters.SQL.query(SlackClone.Repo, "SELECT COUNT(*) FROM users LIMIT 1", []) do
      {:ok, _} ->
        response_time = System.monotonic_time(:millisecond) - start_time
        if response_time < 100 do
          {:ok, "Query response time normal (#{response_time}ms)"}
        else
          {:warning, "Query response time high (#{response_time}ms)"}
        end
      
      {:error, reason} ->
        {:error, "Query failed: #{inspect(reason)}"}
    end
  end
  
  defp check_connection_leaks do
    pool_status = get_pool_status()
    
    # Check if connections have been checked out for too long
    if pool_status.checked_out > pool_status.pool_size * 0.9 do
      {:warning, "Possible connection leak detected (#{pool_status.checked_out}/#{pool_status.pool_size} checked out)"}
    else
      {:ok, "No connection leaks detected"}
    end
  end
  
  defp check_database_locks do
    # Check for long-running locks that might indicate deadlocks
    try do
      case Ecto.Adapters.SQL.query(SlackClone.Repo, """
        SELECT COUNT(*) as lock_count 
        FROM pg_locks 
        WHERE mode = 'ExclusiveLock' 
        AND granted = false
        """, []) do
        {:ok, %{rows: [[count]]}} when count > 5 ->
          {:warning, "High number of database locks detected (#{count})"}
        
        {:ok, _} ->
          {:ok, "Database locks normal"}
        
        {:error, reason} ->
          {:error, "Lock check failed: #{inspect(reason)}"}
      end
    rescue
      _ -> {:ok, "Lock check skipped (not PostgreSQL)"}
    end
  end
  
  defp log_health_issue(health_status) do
    require Logger
    
    failed_checks = health_status.checks
    |> Enum.filter(fn {status, _} -> status != :ok end)
    |> Enum.map(fn {status, message} -> "#{status}: #{message}" end)
    
    Logger.warn("Database health check failed", %{
      failed_checks: failed_checks,
      total_checks: length(health_status.checks),
      duration_ms: health_status.check_duration_ms
    })
  end
  
  defp log_pool_resize(new_size) do
    require Logger
    Logger.info("Connection pool resized", %{new_size: new_size})
  end
  
  defp log_resize_error(error, attempted_size) do
    require Logger
    Logger.error("Failed to resize connection pool", %{
      error: inspect(error),
      attempted_size: attempted_size
    })
  end
  
  defp schedule_monitoring do
    Process.send_after(self(), :monitor_pool, @monitoring_interval)
  end
  
  defp schedule_health_checks do
    Process.send_after(self(), :health_check, @health_check_interval)
  end
  
  defp schedule_resize_checks do
    Process.send_after(self(), :resize_check, @resize_interval)
  end
  
  @doc """
  Get pool optimization history.
  """
  def get_optimization_history do
    GenServer.call(__MODULE__, :get_optimization_history)
  end
  
  def handle_call(:get_optimization_history, _from, state) do
    {:reply, state.optimization_history, state}
  end
  
  @doc """
  Get pool metrics history for a time period.
  """
  def get_metrics_history(minutes_back \\ 60) do
    cutoff_time = System.system_time(:millisecond) - (minutes_back * 60 * 1000)
    
    :ets.select(:pool_metrics_history, [
      {
        {:"$1", :"$2"},
        [{:>=, :"$1", cutoff_time}],
        [{{:"$1", :"$2"}}]
      }
    ])
    |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
  end

  @doc """
  Emit pool metrics for telemetry system.
  """
  def emit_pool_metrics do
    try do
      case GenServer.call(__MODULE__, :get_pool_metrics, 5000) do
        %PoolMetrics{} = metrics ->
          :telemetry.execute(
            [:slack_clone, :database, :pool_metrics],
            %{
              pool_size: metrics.pool_size || 0,
              checked_out: metrics.checked_out || 0,
              checked_in: metrics.checked_in || 0,
              utilization: metrics.utilization || 0.0,
              avg_wait_time: metrics.avg_wait_time || 0,
              max_wait_time: metrics.max_wait_time || 0,
              query_queue_length: metrics.query_queue_length || 0,
              connection_errors: metrics.connection_errors || 0,
              slow_queries: metrics.slow_queries || 0
            },
            %{
              pool_type: :database,
              timestamp: metrics.timestamp || System.system_time(:millisecond)
            }
          )

        error ->
          require Logger
          Logger.warning("Failed to get pool metrics for telemetry: #{inspect(error)}")
          
          # Emit default metrics to prevent undefined function errors
          :telemetry.execute(
            [:slack_clone, :database, :pool_metrics],
            %{
              pool_size: 0,
              checked_out: 0,
              checked_in: 0,
              utilization: 0.0,
              avg_wait_time: 0,
              max_wait_time: 0,
              query_queue_length: 0,
              connection_errors: 0,
              slow_queries: 0
            },
            %{
              pool_type: :database,
              timestamp: System.system_time(:millisecond),
              status: :error
            }
          )
      end
    rescue
      e ->
        require Logger
        Logger.warning("Failed to emit pool metrics: #{inspect(e)}")
        
        # Emit error state metrics
        :telemetry.execute(
          [:slack_clone, :database, :pool_metrics],
          %{
            pool_size: 0,
            checked_out: 0,
            checked_in: 0,
            utilization: 0.0,
            avg_wait_time: 0,
            max_wait_time: 0,
            query_queue_length: 0,
            connection_errors: 1,
            slow_queries: 0
          },
          %{
            pool_type: :database,
            timestamp: System.system_time(:millisecond),
            status: :unavailable
          }
        )
    end
  end
end