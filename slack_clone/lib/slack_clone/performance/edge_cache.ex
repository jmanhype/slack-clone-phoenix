defmodule SlackClone.Performance.EdgeCache do
  @moduledoc """
  Edge caching implementation with CDN integration, geographic distribution,
  and intelligent cache invalidation for optimal global performance.
  """
  
  use GenServer
  
  # Cache configuration
  @default_ttl 3600          # 1 hour
  @static_asset_ttl 86400    # 24 hours for static assets
  @api_response_ttl 300      # 5 minutes for API responses
  @user_content_ttl 1800     # 30 minutes for user-generated content
  
  # Geographic regions
  @regions [
    :us_east_1,
    :us_west_2,
    :eu_west_1,
    :ap_southeast_1,
    :ap_northeast_1
  ]
  
  # Cache tiers
  @cache_tiers [
    browser: 60,          # 1 minute browser cache
    cdn: 3600,           # 1 hour CDN cache
    application: 300,     # 5 minutes application cache
    database: 1800       # 30 minutes database query cache
  ]
  
  defmodule CacheEntry do
    defstruct [
      :key,
      :value,
      :content_type,
      :etag,
      :last_modified,
      :ttl,
      :regions,
      :compression,
      :size_bytes,
      :hit_count,
      :created_at,
      :expires_at
    ]
  end
  
  defmodule CacheStats do
    defstruct [
      :total_requests,
      :cache_hits,
      :cache_misses,
      :hit_ratio,
      :bandwidth_saved_mb,
      :avg_response_time,
      :regions_active,
      :total_cached_items,
      :cache_size_mb
    ]
  end
  
  @doc """
  Start the edge cache manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Cache content with automatic geographic distribution.
  """
  def cache_content(key, content, opts \\ []) do
    GenServer.call(__MODULE__, {:cache_content, key, content, opts})
  end
  
  @doc """
  Get cached content with fallback to origin.
  """
  def get_content(key, region \\ :auto) do
    GenServer.call(__MODULE__, {:get_content, key, region})
  end
  
  @doc """
  Invalidate cached content globally or by region.
  """
  def invalidate(key_or_pattern, opts \\ []) do
    GenServer.cast(__MODULE__, {:invalidate, key_or_pattern, opts})
  end
  
  @doc """
  Warm cache with critical content.
  """
  def warm_cache(content_list) do
    GenServer.cast(__MODULE__, {:warm_cache, content_list})
  end
  
  @doc """
  Get cache statistics and performance metrics.
  """
  def get_cache_stats(region \\ :global) do
    GenServer.call(__MODULE__, {:get_cache_stats, region})
  end
  
  @doc """
  Optimize cache based on access patterns.
  """
  def optimize_cache do
    GenServer.cast(__MODULE__, :optimize_cache)
  end
  
  # GenServer callbacks
  
  def init(_opts) do
    # Initialize cache storage
    :ets.new(:edge_cache_entries, [:set, :named_table, :public])
    :ets.new(:cache_statistics, [:set, :named_table, :public])
    :ets.new(:access_patterns, [:bag, :named_table, :public])
    
    # Schedule cache maintenance
    :timer.send_interval(60_000, :cleanup_expired)     # Every minute
    :timer.send_interval(300_000, :optimize_cache)     # Every 5 minutes
    :timer.send_interval(900_000, :update_statistics)  # Every 15 minutes
    
    state = %{
      regions: initialize_regions(),
      cache_policies: initialize_cache_policies(),
      optimization_config: initialize_optimization_config()
    }
    
    {:ok, state}
  end
  
  def handle_call({:cache_content, key, content, opts}, _from, state) do
    result = store_content(key, content, opts, state)
    {:reply, result, state}
  end
  
  def handle_call({:get_content, key, region}, _from, state) do
    result = retrieve_content(key, region, state)
    {:reply, result, state}
  end
  
  def handle_call({:get_cache_stats, region}, _from, state) do
    stats = calculate_cache_stats(region, state)
    {:reply, stats, state}
  end
  
  def handle_cast({:invalidate, key_or_pattern, opts}, state) do
    perform_invalidation(key_or_pattern, opts, state)
    {:noreply, state}
  end
  
  def handle_cast({:warm_cache, content_list}, state) do
    perform_cache_warming(content_list, state)
    {:noreply, state}
  end
  
  def handle_cast(:optimize_cache, state) do
    new_state = perform_cache_optimization(state)
    {:noreply, new_state}
  end
  
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries()
    {:noreply, state}
  end
  
  def handle_info(:optimize_cache, state) do
    new_state = perform_cache_optimization(state)
    {:noreply, new_state}
  end
  
  def handle_info(:update_statistics, state) do
    update_cache_statistics()
    {:noreply, state}
  end
  
  def handle_info(_message, state) do
    {:noreply, state}
  end
  
  # Private implementation
  
  defp store_content(key, content, opts, state) do
    entry = build_cache_entry(key, content, opts)
    
    # Determine target regions
    regions = get_target_regions(opts[:regions] || :auto, state)
    
    # Compress content if beneficial
    compressed_content = maybe_compress_content(content, entry.content_type)
    entry = %{entry | value: compressed_content, compression: get_compression_type(compressed_content)}
    
    # Store in local cache
    :ets.insert(:edge_cache_entries, {key, entry})
    
    # Distribute to edge locations
    distribute_to_regions(key, entry, regions, state)
    
    # Update access patterns
    record_cache_operation(:store, key, byte_size(compressed_content))
    
    {:ok, %{
      cached: true,
      regions: regions,
      compressed: entry.compression != :none,
      size_bytes: byte_size(compressed_content),
      ttl: entry.ttl
    }}
  end
  
  defp retrieve_content(key, region, state) do
    # Try to get from specified region first
    case get_from_region(key, region, state) do
      {:ok, entry} ->
        # Record cache hit
        record_cache_operation(:hit, key, byte_size(entry.value))
        update_hit_count(key)
        
        # Decompress if needed
        content = maybe_decompress_content(entry.value, entry.compression)
        
        {:ok, %{
          content: content,
          content_type: entry.content_type,
          etag: entry.etag,
          last_modified: entry.last_modified,
          cache_hit: true,
          region: region,
          size_bytes: byte_size(content)
        }}
      
      {:error, :not_found} ->
        # Record cache miss
        record_cache_operation(:miss, key, 0)
        
        # Try other regions as fallback
        case try_fallback_regions(key, region, state) do
          {:ok, entry} ->
            content = maybe_decompress_content(entry.value, entry.compression)
            
            {:ok, %{
              content: content,
              content_type: entry.content_type,
              etag: entry.etag,
              last_modified: entry.last_modified,
              cache_hit: true,
              region: :fallback,
              size_bytes: byte_size(content)
            }}
          
          {:error, :not_found} ->
            {:error, :not_found}
        end
    end
  end
  
  defp build_cache_entry(key, content, opts) do
    now = System.system_time(:second)
    content_type = detect_content_type(content, opts[:content_type])
    ttl = determine_ttl(content_type, opts[:ttl])
    
    %CacheEntry{
      key: key,
      value: content,
      content_type: content_type,
      etag: generate_etag(content),
      last_modified: opts[:last_modified] || now,
      ttl: ttl,
      regions: [],
      compression: :none,
      size_bytes: byte_size(content),
      hit_count: 0,
      created_at: now,
      expires_at: now + ttl
    }
  end
  
  defp get_target_regions(:auto, state) do
    # Determine optimal regions based on user distribution
    get_optimal_regions_for_content(state)
  end
  
  defp get_target_regions(:all, _state), do: @regions
  defp get_target_regions(regions, _state) when is_list(regions), do: regions
  defp get_target_regions(region, _state) when is_atom(region), do: [region]
  
  defp get_optimal_regions_for_content(state) do
    # Analyze user access patterns to determine best regions
    # This would be based on your user analytics
    case get_user_distribution() do
      %{primary: primary_regions, secondary: secondary_regions} ->
        primary_regions ++ Enum.take(secondary_regions, 2)
      
      _ ->
        # Default to major regions
        [:us_east_1, :eu_west_1, :ap_southeast_1]
    end
  end
  
  defp distribute_to_regions(key, entry, regions, state) do
    # Simulate distribution to edge locations
    # In a real implementation, this would integrate with:
    # - CloudFlare API
    # - AWS CloudFront
    # - Fastly API
    # - Or your chosen CDN provider
    
    Enum.each(regions, fn region ->
      distribute_to_region(key, entry, region, state)
    end)
  end
  
  defp distribute_to_region(key, entry, region, _state) do
    # This would implement actual CDN distribution
    # For now, simulate with local storage per region
    region_key = "#{region}:#{key}"
    :ets.insert(:edge_cache_entries, {region_key, %{entry | regions: [region | entry.regions]}})
  end
  
  defp get_from_region(key, :auto, _state) do
    # Get from closest region based on request origin
    closest_region = determine_closest_region()
    get_from_specific_region(key, closest_region)
  end
  
  defp get_from_region(key, region, _state) do
    get_from_specific_region(key, region)
  end
  
  defp get_from_specific_region(key, region) do
    region_key = "#{region}:#{key}"
    
    case :ets.lookup(:edge_cache_entries, region_key) do
      [{_, entry}] ->
        if entry.expires_at > System.system_time(:second) do
          {:ok, entry}
        else
          :ets.delete(:edge_cache_entries, region_key)
          {:error, :expired}
        end
      
      [] ->
        {:error, :not_found}
    end
  end
  
  defp try_fallback_regions(key, exclude_region, _state) do
    fallback_regions = @regions -- [exclude_region]
    
    Enum.find_value(fallback_regions, {:error, :not_found}, fn region ->
      case get_from_specific_region(key, region) do
        {:ok, entry} -> {:ok, entry}
        _ -> nil
      end
    end)
  end
  
  defp perform_invalidation(key_or_pattern, opts, _state) do
    regions = opts[:regions] || @regions
    
    if String.contains?(to_string(key_or_pattern), "*") do
      # Pattern-based invalidation
      pattern = convert_to_ets_pattern(key_or_pattern)
      
      Enum.each(regions, fn region ->
        # Get all keys that start with this region and match pattern
        region_pattern = "#{region}:#{pattern}"
        :ets.select_delete(:edge_cache_entries, [
          {
            {region_pattern, :"$2"},
            [],
            [true]
          }
        ])
      end)
    else
      # Single key invalidation
      Enum.each(regions, fn region ->
        region_key = "#{region}:#{key_or_pattern}"
        :ets.delete(:edge_cache_entries, region_key)
      end)
    end
    
    # Also invalidate from origin cache
    :ets.delete(:edge_cache_entries, key_or_pattern)
    
    # Record invalidation
    record_cache_operation(:invalidate, key_or_pattern, 0)
  end
  
  defp perform_cache_warming(content_list, state) do
    Task.start(fn ->
      Enum.each(content_list, fn
        {key, content, opts} ->
          store_content(key, content, opts, state)
        
        {key, fetch_fn} when is_function(fetch_fn) ->
          case fetch_fn.() do
            {:ok, content, opts} ->
              store_content(key, content, opts || [], state)
            _ ->
              :error
          end
      end)
    end)
  end
  
  defp perform_cache_optimization(state) do
    # Analyze access patterns and optimize cache
    access_patterns = analyze_access_patterns()
    
    # Remove least accessed items if cache is too large
    maybe_evict_cold_content(access_patterns)
    
    # Pre-warm frequently accessed content
    maybe_prewarm_hot_content(access_patterns)
    
    # Optimize region distribution
    optimize_region_distribution(access_patterns, state)
  end
  
  defp cleanup_expired_entries do
    current_time = System.system_time(:second)
    
    :ets.select_delete(:edge_cache_entries, [
      {
        {:"$1", :"$2"},
        [{:<, {:map_get, :expires_at, :"$2"}, current_time}],
        [true]
      }
    ])
  end
  
  defp calculate_cache_stats(region, _state) do
    current_time = System.system_time(:second)
    
    # Get access statistics
    access_stats = get_access_stats(region)
    
    # Calculate cache size
    cache_entries = if region == :global do
      :ets.tab2list(:edge_cache_entries)
    else
      # Get entries that start with the region prefix
      region_prefix = "#{region}:"
      :ets.select(:edge_cache_entries, [
        {
          {:"$1", :"$2"},
          [],
          [{{:"$1", :"$2"}}]
        }
      ])
      |> Enum.filter(fn {key, _value} ->
        String.starts_with?(to_string(key), region_prefix)
      end)
    end
    
    total_size = 
      cache_entries
      |> Enum.reduce(0, fn {_, entry}, acc ->
        acc + (entry.size_bytes || 0)
      end)
    
    %CacheStats{
      total_requests: access_stats.total_requests,
      cache_hits: access_stats.cache_hits,
      cache_misses: access_stats.cache_misses,
      hit_ratio: calculate_hit_ratio(access_stats.cache_hits, access_stats.total_requests),
      bandwidth_saved_mb: total_size / (1024 * 1024),
      avg_response_time: access_stats.avg_response_time || 0,
      regions_active: count_active_regions(cache_entries),
      total_cached_items: length(cache_entries),
      cache_size_mb: total_size / (1024 * 1024)
    }
  end
  
  # Helper functions for compression, content type detection, etc.
  
  defp maybe_compress_content(content, content_type) when byte_size(content) > 1024 do
    if compressible_content_type?(content_type) do
      case :zlib.gzip(content) do
        compressed when byte_size(compressed) < byte_size(content) * 0.9 ->
          compressed
        _ ->
          content
      end
    else
      content
    end
  end
  
  defp maybe_compress_content(content, _), do: content
  
  defp get_compression_type(content) do
    # Simple check for gzip magic number
    case content do
      <<31, 139, _::binary>> -> :gzip
      _ -> :none
    end
  end
  
  defp maybe_decompress_content(content, :gzip) do
    :zlib.gunzip(content)
  end
  
  defp maybe_decompress_content(content, _), do: content
  
  defp compressible_content_type?(content_type) do
    compressible_types = [
      "text/", "application/json", "application/javascript",
      "application/xml", "image/svg+xml"
    ]
    
    Enum.any?(compressible_types, &String.starts_with?(content_type || "", &1))
  end
  
  defp detect_content_type(content, provided_type) do
    provided_type || guess_content_type_from_content(content)
  end
  
  defp guess_content_type_from_content(content) do
    case content do
      <<"{", _::binary>> -> "application/json"
      <<"<html", _::binary>> -> "text/html"
      <<"<!DOCTYPE html", _::binary>> -> "text/html"
      _ -> "application/octet-stream"
    end
  end
  
  defp determine_ttl(content_type, provided_ttl) do
    provided_ttl || get_default_ttl_for_content_type(content_type)
  end
  
  defp get_default_ttl_for_content_type(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> @static_asset_ttl
      String.starts_with?(content_type, "application/javascript") -> @static_asset_ttl
      String.starts_with?(content_type, "text/css") -> @static_asset_ttl
      String.starts_with?(content_type, "application/json") -> @api_response_ttl
      true -> @default_ttl
    end
  end
  
  defp generate_etag(content) do
    :crypto.hash(:md5, content) |> Base.encode16(case: :lower)
  end
  
  defp determine_closest_region do
    # This would implement geolocation-based region selection
    # For now, return a default
    :us_east_1
  end
  
  defp record_cache_operation(operation, key, size_bytes) do
    timestamp = System.system_time(:millisecond)
    :ets.insert(:access_patterns, {timestamp, operation, key, size_bytes})
  end
  
  defp update_hit_count(key) do
    case :ets.lookup(:edge_cache_entries, key) do
      [{key, entry}] ->
        updated_entry = %{entry | hit_count: entry.hit_count + 1}
        :ets.insert(:edge_cache_entries, {key, updated_entry})
      [] ->
        :ok
    end
  end
  
  defp get_access_stats(region) do
    # Analyze access patterns from ETS
    one_hour_ago = System.system_time(:millisecond) - (60 * 60 * 1000)
    
    recent_access = :ets.select(:access_patterns, [
      {
        {:"$1", :"$2", :"$3", :"$4"},
        [{:>=, :"$1", one_hour_ago}],
        [{{:"$1", :"$2", :"$3", :"$4"}}]
      }
    ])
    
    hits = Enum.count(recent_access, fn {_, op, _, _} -> op == :hit end)
    misses = Enum.count(recent_access, fn {_, op, _, _} -> op == :miss end)
    total = hits + misses
    
    %{
      total_requests: total,
      cache_hits: hits,
      cache_misses: misses,
      avg_response_time: calculate_avg_response_time(recent_access)
    }
  end
  
  defp calculate_hit_ratio(hits, total) when total > 0, do: hits / total
  defp calculate_hit_ratio(_, _), do: 0.0
  
  defp count_active_regions(cache_entries) do
    cache_entries
    |> Enum.map(fn {key, _} ->
      case String.split(to_string(key), ":", parts: 2) do
        [region, _] when region in @regions -> region
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> length()
  end
  
  defp calculate_avg_response_time(_access_patterns) do
    # This would calculate actual response times from telemetry
    0
  end
  
  defp analyze_access_patterns do
    # Analyze access patterns to inform optimization decisions
    %{hot_content: [], cold_content: [], region_preferences: %{}}
  end
  
  defp maybe_evict_cold_content(_patterns) do
    # Implement LRU or similar eviction policy
    :ok
  end
  
  defp maybe_prewarm_hot_content(_patterns) do
    # Pre-warm frequently accessed content
    :ok
  end
  
  defp optimize_region_distribution(_patterns, state) do
    # Optimize which regions cache which content
    state
  end
  
  defp get_user_distribution do
    # This would analyze user geographic distribution
    %{primary: [:us_east_1, :eu_west_1], secondary: [:ap_southeast_1, :us_west_2]}
  end
  
  defp update_cache_statistics do
    # Update periodic statistics
    :ok
  end
  
  defp initialize_regions do
    Enum.into(@regions, %{}, fn region -> {region, %{active: true}} end)
  end
  
  defp initialize_cache_policies do
    @cache_tiers
  end
  
  defp initialize_optimization_config do
    %{
      max_cache_size_mb: 1000,
      eviction_policy: :lru,
      compression_threshold_bytes: 1024,
      prewarm_threshold_hits: 10
    }
  end
  
  defp convert_to_ets_pattern(pattern) do
    # Convert glob pattern to ETS match pattern
    String.replace(pattern, "*", "_")
  end
  
  defp match_spec_for_pattern(pattern, key_var) do
    # Build match specification for pattern matching
    {:like, key_var, pattern}
  end
end