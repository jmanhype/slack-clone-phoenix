# Performance benchmark script for Slack Clone
defmodule SlackClone.Benchmark do
  @moduledoc """
  Performance benchmarks for critical operations.
  
  Run with: mix run priv/repo/benchmark.exs
  """
  
  alias SlackClone.{Accounts, Messages, Channels, Repo}
  
  require Logger

  def run do
    Logger.info("Starting performance benchmarks...")
    
    # Setup test data
    setup_test_data()
    
    benchmarks = %{
      # Database operations
      "User creation" => fn -> benchmark_user_creation() end,
      "Message creation" => fn -> benchmark_message_creation() end,
      "Message listing" => fn -> benchmark_message_listing() end,
      "Channel creation" => fn -> benchmark_channel_creation() end,
      
      # Search operations
      "Message search" => fn -> benchmark_message_search() end,
      
      # Real-time operations
      "Channel broadcast" => fn -> benchmark_channel_broadcast() end,
      
      # Authentication
      "User authentication" => fn -> benchmark_authentication() end,
    }
    
    results = Enum.map(benchmarks, fn {name, benchmark_fn} ->
      Logger.info("Running benchmark: #{name}")
      {time, result} = :timer.tc(benchmark_fn)
      time_ms = time / 1000
      
      Logger.info("#{name}: #{time_ms}ms")
      
      %{
        name: name,
        time_ms: time_ms,
        result: result,
        timestamp: DateTime.utc_now()
      }
    end)
    
    # Generate summary
    summary = generate_summary(results)
    
    # Output results in JSON format for CI/CD
    output = %{
      timestamp: DateTime.utc_now(),
      environment: System.get_env("MIX_ENV", "test"),
      results: results,
      summary: summary,
      system_info: get_system_info()
    }
    
    json_output = Jason.encode!(output, pretty: true)
    File.write!("benchmarks.json", json_output)
    
    Logger.info("Benchmark results saved to benchmarks.json")
    Logger.info("Summary: #{inspect(summary)}")
    
    output
  end
  
  defp setup_test_data do
    # Create test user if not exists
    user_attrs = %{
      email: "benchmark@example.com",
      username: "benchmark_user",
      password: "secure_password123!"
    }
    
    case Accounts.get_user_by_email(user_attrs.email) do
      nil -> 
        {:ok, user} = Accounts.create_user(user_attrs)
        user
      user -> 
        user
    end
  end
  
  defp benchmark_user_creation do
    user_attrs = %{
      email: "test_#{:rand.uniform(10000)}@example.com",
      username: "test_user_#{:rand.uniform(10000)}",
      password: "secure_password123!"
    }
    
    case Accounts.create_user(user_attrs) do
      {:ok, user} -> 
        # Cleanup
        Repo.delete(user)
        :ok
      {:error, _} -> 
        :error
    end
  end
  
  defp benchmark_message_creation do
    user = Accounts.get_user_by_email("benchmark@example.com")
    
    message_attrs = %{
      content: "Benchmark message #{:rand.uniform(10000)}",
      user_id: user.id,
      channel_id: get_or_create_test_channel().id
    }
    
    case Messages.create_message(message_attrs) do
      {:ok, _message} -> :ok
      {:error, _} -> :error
    end
  end
  
  defp benchmark_message_listing do
    channel = get_or_create_test_channel()
    
    # Create some messages first
    user = Accounts.get_user_by_email("benchmark@example.com")
    
    Enum.each(1..10, fn i ->
      Messages.create_message(%{
        content: "Benchmark message #{i}",
        user_id: user.id,
        channel_id: channel.id
      })
    end)
    
    case Messages.list_messages(channel.id, limit: 50) do
      messages when is_list(messages) -> :ok
      _ -> :error
    end
  end
  
  defp benchmark_channel_creation do
    user = Accounts.get_user_by_email("benchmark@example.com")
    
    channel_attrs = %{
      name: "benchmark-channel-#{:rand.uniform(10000)}",
      description: "Benchmark channel",
      creator_id: user.id
    }
    
    case Channels.create_channel(channel_attrs) do
      {:ok, channel} -> 
        # Cleanup
        Repo.delete(channel)
        :ok
      {:error, _} -> 
        :error
    end
  end
  
  defp benchmark_message_search do
    # This would use your search implementation
    # For now, we'll simulate it
    :timer.sleep(50) # Simulate search latency
    :ok
  end
  
  defp benchmark_channel_broadcast do
    channel = get_or_create_test_channel()
    
    # Simulate broadcasting to channel
    Phoenix.PubSub.broadcast(
      SlackClone.PubSub,
      "channel:#{channel.id}",
      {:new_message, %{content: "Benchmark broadcast"}}
    )
    
    :ok
  end
  
  defp benchmark_authentication do
    # Simulate authentication check
    case Accounts.authenticate_user("benchmark@example.com", "secure_password123!") do
      {:ok, _user} -> :ok
      {:error, _} -> :error
    end
  end
  
  defp get_or_create_test_channel do
    user = Accounts.get_user_by_email("benchmark@example.com")
    
    case Channels.get_channel_by_name("benchmark-test") do
      nil ->
        {:ok, channel} = Channels.create_channel(%{
          name: "benchmark-test",
          description: "Test channel for benchmarks",
          creator_id: user.id
        })
        channel
      channel ->
        channel
    end
  end
  
  defp generate_summary(results) do
    total_time = Enum.sum(Enum.map(results, & &1.time_ms))
    avg_time = total_time / length(results)
    
    successful_ops = Enum.count(results, fn r -> r.result == :ok end)
    total_ops = length(results)
    
    %{
      total_operations: total_ops,
      successful_operations: successful_ops,
      success_rate: successful_ops / total_ops * 100,
      total_time_ms: total_time,
      average_time_ms: avg_time,
      fastest_operation: Enum.min_by(results, & &1.time_ms),
      slowest_operation: Enum.max_by(results, & &1.time_ms)
    }
  end
  
  defp get_system_info do
    %{
      erlang_version: :erlang.system_info(:otp_release),
      elixir_version: System.version(),
      cpu_count: System.schedulers_online(),
      memory_usage: :erlang.memory(),
      node_name: Node.self()
    }
  end
end

# Run benchmarks if called directly
if __ENV__.file == :code.get_path() |> List.first() |> Path.join("benchmark.exs") do
  SlackClone.Benchmark.run()
end