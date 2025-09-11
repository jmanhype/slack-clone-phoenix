defmodule SlackClone.Performance.CacheManager do
  @moduledoc """
  High-performance caching layer with Redis backend, cache warming, and intelligent invalidation.
  """
  
  import Ecto.Query
  alias SlackClone.Repo
  
  # Cache TTLs in seconds
  @default_ttl 3600  # 1 hour
  @short_ttl 300     # 5 minutes
  @long_ttl 86400    # 24 hours
  
  # Cache prefixes
  @message_prefix "msg"
  @channel_prefix "ch"
  @user_prefix "usr"
  @workspace_prefix "ws"
  @presence_prefix "prs"
  
  @doc """
  Get cached data with fallback to database query.
  """
  def get_or_fetch(key, ttl \\ @default_ttl, fetch_fn) when is_function(fetch_fn, 0) do
    case redis_command(["GET", key]) do
      {:ok, nil} ->
        # Cache miss - fetch from database and cache
        data = fetch_fn.()
        set(key, data, ttl)
        data
      
      {:ok, cached_data} ->
        # Cache hit - deserialize and return
        Jason.decode!(cached_data)
      
      {:error, _reason} ->
        # Redis error - fall back to direct database query
        fetch_fn.()
    end
  end
  
  @doc """
  Set data in cache with TTL.
  """
  def set(key, data, ttl \\ @default_ttl) do
    serialized = Jason.encode!(data)
    redis_command(["SETEX", key, ttl, serialized])
  end

  # Helper function for Redis commands with fallback
  defp redis_command(command) do
    case Process.whereis(:redix) do
      nil ->
        # Redis not available, return error
        {:error, :redis_not_available}
      pid when is_pid(pid) ->
        try do
          Redix.command(:redix, command)
        rescue
          _ -> {:error, :redis_connection_failed}
        end
    end
  end
  
  @doc """
  Delete cached data by key or pattern.
  """
  def delete(key_or_pattern) do
    if String.contains?(key_or_pattern, "*") do
      # Pattern-based deletion
      case redis_command(["KEYS", key_or_pattern]) do
        {:ok, keys} when length(keys) > 0 ->
          redis_command(["DEL" | keys])
        _ ->
          {:ok, 0}
      end
    else
      # Single key deletion
      redis_command(["DEL", key_or_pattern])
    end
  end
  
  @doc """
  Cache channel messages with pagination support.
  """
  def cache_channel_messages(channel_id, limit \\ 50, offset \\ 0) do
    key = "#{@message_prefix}:channel:#{channel_id}:#{limit}:#{offset}"
    
    get_or_fetch(key, @short_ttl, fn ->
      from(m in SlackClone.Schema.Message,
        where: m.channel_id == ^channel_id and m.is_deleted == false,
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user, :reactions]
      )
      |> Repo.all()
      |> Enum.map(&serialize_message/1)
    end)
  end
  
  @doc """
  Cache channel information with member count.
  """
  def cache_channel_info(channel_id) do
    key = "#{@channel_prefix}:info:#{channel_id}"
    
    get_or_fetch(key, @default_ttl, fn ->
      channel = Repo.get(SlackClone.Schema.Channel, channel_id)
      member_count = get_channel_member_count(channel_id)
      
      %{
        id: channel.id,
        name: channel.name,
        description: channel.description,
        is_private: channel.is_private,
        workspace_id: channel.workspace_id,
        member_count: member_count,
        updated_at: channel.updated_at
      }
    end)
  end
  
  @doc """
  Cache user workspace channels.
  """
  def cache_user_channels(user_id, workspace_id) do
    key = "#{@user_prefix}:channels:#{user_id}:#{workspace_id}"
    
    get_or_fetch(key, @default_ttl, fn ->
      from(ch in SlackClone.Schema.Channel,
        join: cm in SlackClone.Schema.ChannelMembership,
        on: cm.channel_id == ch.id,
        where: cm.user_id == ^user_id and 
               ch.workspace_id == ^workspace_id and
               cm.is_active == true and
               ch.is_archived == false,
        order_by: [asc: ch.name],
        select: %{
          id: ch.id,
          name: ch.name,
          description: ch.description,
          is_private: ch.is_private,
          unread_count: 0  # Will be populated by separate query
        }
      )
      |> Repo.all()
    end)
  end
  
  @doc """
  Cache workspace members for presence tracking.
  """
  def cache_workspace_members(workspace_id) do
    key = "#{@workspace_prefix}:members:#{workspace_id}"
    
    get_or_fetch(key, @long_ttl, fn ->
      from(u in SlackClone.Schema.User,
        join: wm in SlackClone.Schema.WorkspaceMembership,
        on: wm.user_id == u.id,
        where: wm.workspace_id == ^workspace_id and wm.is_active == true,
        select: %{
          id: u.id,
          name: u.name,
          email: u.email,
          avatar_url: u.avatar_url,
          role: wm.role,
          joined_at: wm.inserted_at
        }
      )
      |> Repo.all()
    end)
  end
  
  @doc """
  Cache user presence data with debouncing.
  """
  def cache_user_presence(user_id, channel_id, presence_data, debounce_ms \\ 1000) do
    key = "#{@presence_prefix}:#{user_id}:#{channel_id}"
    
    # Check if we should debounce this update
    last_update_key = "#{key}:last_update"
    current_time = System.system_time(:millisecond)
    
    case redis_command(["GET", last_update_key]) do
      {:ok, nil} ->
        # First presence update
        update_presence_cache(key, last_update_key, presence_data, current_time)
      
      {:ok, last_time_str} ->
        last_time = String.to_integer(last_time_str)
        if current_time - last_time > debounce_ms do
          # Enough time has passed, update presence
          update_presence_cache(key, last_update_key, presence_data, current_time)
        else
          # Too frequent, skip update
          :debounced
        end
      
      {:error, _} ->
        # Redis error, update anyway
        update_presence_cache(key, last_update_key, presence_data, current_time)
    end
  end
  
  @doc """
  Warm up critical caches on application startup.
  """
  def warm_cache do
    Task.start(fn ->
      # Warm up popular channels
      popular_channels = get_popular_channels()
      
      Enum.each(popular_channels, fn channel_id ->
        cache_channel_messages(channel_id, 50, 0)
        cache_channel_info(channel_id)
      end)
      
      # Warm up active workspaces
      active_workspaces = get_active_workspaces()
      
      Enum.each(active_workspaces, fn workspace_id ->
        cache_workspace_members(workspace_id)
      end)
    end)
  end
  
  @doc """
  Invalidate caches when data changes.
  """
  def invalidate_on_message_create(channel_id, user_id) do
    delete("#{@message_prefix}:channel:#{channel_id}:*")
    delete("#{@channel_prefix}:info:#{channel_id}")
    delete("#{@user_prefix}:channels:#{user_id}:*")
  end
  
  def invalidate_on_channel_update(channel_id, workspace_id) do
    delete("#{@channel_prefix}:info:#{channel_id}")
    delete("#{@user_prefix}:channels:*:#{workspace_id}")
  end
  
  def invalidate_on_membership_change(user_id, workspace_id, channel_id) do
    delete("#{@user_prefix}:channels:#{user_id}:#{workspace_id}")
    delete("#{@channel_prefix}:info:#{channel_id}")
    delete("#{@workspace_prefix}:members:#{workspace_id}")
  end
  
  # Private helper functions
  
  defp serialize_message(message) do
    %{
      id: message.id,
      content: message.content,
      content_type: message.content_type,
      user: %{
        id: message.user.id,
        name: message.user.name,
        avatar_url: message.user.avatar_url
      },
      reactions: message.reactions || [],
      thread_id: message.thread_id,
      is_edited: message.is_edited,
      inserted_at: message.inserted_at,
      updated_at: message.updated_at
    }
  end
  
  defp get_channel_member_count(channel_id) do
    from(cm in SlackClone.Schema.ChannelMembership,
      where: cm.channel_id == ^channel_id and cm.is_active == true,
      select: count()
    )
    |> Repo.one()
  end
  
  defp update_presence_cache(key, last_update_key, presence_data, current_time) do
    set(key, presence_data, @short_ttl)
    redis_command(["SETEX", last_update_key, @short_ttl, to_string(current_time)])
  end
  
  defp get_popular_channels do
    # Query for channels with most recent activity
    from(ch in SlackClone.Schema.Channel,
      join: m in SlackClone.Schema.Message,
      on: m.channel_id == ch.id,
      where: m.inserted_at > ago(24, "hour"),
      group_by: ch.id,
      order_by: [desc: count(m.id)],
      limit: 20,
      select: ch.id
    )
    |> Repo.all()
  end
  
  defp get_active_workspaces do
    # Query for workspaces with recent activity
    from(ws in SlackClone.Schema.Workspace,
      join: ch in SlackClone.Schema.Channel,
      on: ch.workspace_id == ws.id,
      join: m in SlackClone.Schema.Message,
      on: m.channel_id == ch.id,
      where: m.inserted_at > ago(24, "hour"),
      group_by: ws.id,
      order_by: [desc: count(m.id)],
      limit: 10,
      select: ws.id
    )
    |> Repo.all()
  end

  @doc """
  Get cache statistics for monitoring.
  """
  def get_stats do
    case redis_command(["INFO", "stats"]) do
      {:ok, redis_info} ->
        stats = parse_redis_stats(redis_info)
        
        %{
          hit_ratio: calculate_hit_ratio(stats),
          total_keys: get_total_keys(),
          memory_usage: get_memory_usage(stats),
          commands_processed: Map.get(stats, :total_commands_processed, 0),
          keyspace_hits: Map.get(stats, :keyspace_hits, 0),
          keyspace_misses: Map.get(stats, :keyspace_misses, 0),
          status: :healthy
        }

      {:error, :redis_not_available} ->
        %{
          hit_ratio: 0.0,
          total_keys: 0,
          memory_usage: 0,
          commands_processed: 0,
          keyspace_hits: 0,
          keyspace_misses: 0,
          status: :redis_not_available
        }

      {:error, _reason} ->
        %{
          hit_ratio: 0.0,
          total_keys: 0,
          memory_usage: 0,
          commands_processed: 0,
          keyspace_hits: 0,
          keyspace_misses: 0,
          status: :error
        }
    end
  end

  @doc """
  Emit cache metrics for telemetry system.
  """
  def emit_cache_metrics do
    try do
      stats = get_stats()
      
      :telemetry.execute(
        [:slack_clone, :cache, :metrics],
        %{
          hit_ratio: stats.hit_ratio,
          total_keys: stats.total_keys,
          memory_usage: stats.memory_usage,
          commands_processed: stats.commands_processed
        },
        %{
          cache_type: :redis,
          status: stats.status
        }
      )
    rescue
      e ->
        require Logger
        Logger.warning("Failed to emit cache metrics: #{inspect(e)}")
        
        :telemetry.execute(
          [:slack_clone, :cache, :metrics],
          %{
            hit_ratio: 0.0,
            total_keys: 0,
            memory_usage: 0,
            commands_processed: 0
          },
          %{
            cache_type: :redis,
            status: :error
          }
        )
    end
  end

  defp parse_redis_stats(info_string) do
    info_string
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":") do
        [key, value] when key in ["total_commands_processed", "keyspace_hits", "keyspace_misses", "used_memory"] ->
          Map.put(acc, String.to_atom(key), String.to_integer(String.trim(value)))
        _ ->
          acc
      end
    end)
  rescue
    _ -> %{}
  end

  defp calculate_hit_ratio(%{keyspace_hits: hits, keyspace_misses: misses}) when hits + misses > 0 do
    hits / (hits + misses)
  end
  defp calculate_hit_ratio(_), do: 0.0

  defp get_total_keys do
    case redis_command(["DBSIZE"]) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp get_memory_usage(%{used_memory: memory}) when is_integer(memory), do: memory
  defp get_memory_usage(_), do: 0
end