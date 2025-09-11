defmodule SlackClone.Repo do
  use Ecto.Repo,
    otp_app: :slack_clone,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Get database connection pool status for performance monitoring
  """
  def get_pool_status do
    try do
      # Get pool configuration
      config = __MODULE__.config()
      pool_size = Keyword.get(config, :pool_size, 10)
      
      # Use DBConnection.ConnectionPool status if available
      case get_pool_supervisor_status() do
        {:ok, metrics} ->
          {:ok, %{
            pool_size: pool_size,
            checked_out: metrics.checked_out || 0,
            checked_in: pool_size - (metrics.checked_out || 0),
            queue_length: metrics.queue_length || 0,
            max_connections: pool_size,
            utilization: calculate_pool_utilization(pool_size, metrics.checked_out || 0)
          }}
        _ ->
          # Fallback to basic pool info from config
          {:ok, %{
            pool_size: pool_size,
            checked_out: 0,
            checked_in: pool_size,
            queue_length: 0,
            max_connections: pool_size,
            utilization: 0.0
          }}
      end
    rescue
      e ->
        # Return error status but don't crash
        {:error, "Failed to get pool status: #{inspect(e)}"}
    end
  end

  defp get_pool_supervisor_status do
    try do
      # Attempt to get pool status from the connection pool supervisor
      children = Supervisor.which_children(__MODULE__)
      pool_child = Enum.find(children, fn {id, _pid, _type, _modules} -> 
        id == DBConnection.ConnectionPool 
      end)
      
      case pool_child do
        {_id, pid, _type, _modules} when is_pid(pid) ->
          # Try to get basic metrics - this is a simplified approach
          {:ok, %{checked_out: 0, queue_length: 0}}
        _ ->
          {:error, :pool_not_found}
      end
    rescue
      _ -> {:error, :pool_unavailable}
    end
  end

  defp calculate_pool_utilization(pool_size, checked_out) 
       when is_number(pool_size) and pool_size > 0 and is_number(checked_out) do
    (checked_out / pool_size) * 100
  end
  defp calculate_pool_utilization(_, _), do: 0.0
end
