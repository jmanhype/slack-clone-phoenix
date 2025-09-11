ExUnit.start()

# Configure test environment
Application.put_env(:slack_clone, :test_mode, true)

# Configure test database 
Ecto.Adapters.SQL.Sandbox.mode(SlackClone.Repo, :manual)

# Set up test support modules
Code.require_file("support/factory.ex", __DIR__)
Code.require_file("support/conn_case.ex", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)
Code.require_file("support/channel_case.ex", __DIR__)

# Performance and benchmark test configuration
if System.get_env("BENCHMARK_TESTS") == "true" do
  ExUnit.configure(exclude: [], include: [:benchmark, :performance])
else
  ExUnit.configure(exclude: [:benchmark, :performance], include: [])
end

# Integration test configuration 
if System.get_env("INTEGRATION_TESTS") == "true" do
  ExUnit.configure(exclude: [], include: [:integration])
else
  ExUnit.configure(exclude: [:integration], include: [])
end

# Test coverage configuration
if System.get_env("COVERAGE") == "true" do
  ExUnit.configure(formatters: [ExUnit.CLIFormatter, ExCoveralls.Formatter])
end

# Test timeout configuration for slow tests
ExUnit.configure(timeout: 60_000)

# Set up global test hooks
ExUnit.start(
  capture_log: true,
  max_failures: 5,
  seed: System.get_env("SEED") || :rand.uniform(100_000)
)

defmodule SlackClone.TestHelpers do
  @moduledoc """
  Shared test helpers for the test suite
  """
  
  import Ecto.Changeset
  import ExMachina
  
  @doc """
  Creates a test workspace with default settings
  """
  def create_test_workspace(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Workspace",
      slug: "test-workspace-#{:rand.uniform(1000)}",
      description: "A workspace for testing",
      settings: %{
        "allow_invites" => true,
        "public" => false
      }
    }
    
    build(:workspace, Map.merge(default_attrs, attrs))
    |> SlackClone.Repo.insert!()
  end
  
  @doc """
  Creates a test channel in a workspace
  """
  def create_test_channel(workspace, attrs \\ %{}) do
    default_attrs = %{
      name: "test-channel-#{:rand.uniform(1000)}",
      description: "A channel for testing",
      type: "public",
      workspace_id: workspace.id,
      creator_id: workspace.owner_id
    }
    
    build(:channel, Map.merge(default_attrs, attrs))
    |> SlackClone.Repo.insert!()
  end
  
  @doc """
  Waits for a process to be registered
  """
  def wait_for_process(process_name, timeout \\ 5000) do
    wait_until(fn -> Process.whereis(process_name) != nil end, timeout)
  end
  
  @doc """
  Waits for a GenServer to be available via Registry
  """
  def wait_for_via_process(via_tuple, timeout \\ 5000) do
    wait_until(fn -> GenServer.whereis(via_tuple) != nil end, timeout)
  end
  
  @doc """
  Waits until a condition is true
  """
  def wait_until(condition_fn, timeout \\ 5000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    wait_until_loop(condition_fn, deadline)
  end
  
  defp wait_until_loop(condition_fn, deadline) do
    if condition_fn.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        raise "Condition not met within timeout"
      else
        Process.sleep(50)
        wait_until_loop(condition_fn, deadline)
      end
    end
  end
  
  @doc """
  Flushes all messages from the process mailbox
  """
  def flush_messages do
    receive do
      _message -> flush_messages()
    after
      0 -> :ok
    end
  end
  
  @doc """
  Creates a temporary file for upload testing
  """
  def create_temp_upload(filename, content \\ "test content", content_type \\ "text/plain") do
    temp_dir = System.tmp_dir!()
    temp_path = Path.join(temp_dir, filename)
    File.write!(temp_path, content)
    
    %Plug.Upload{
      path: temp_path,
      filename: filename,
      content_type: content_type
    }
  end
  
  @doc """
  Cleanup temporary files after tests
  """
  def cleanup_temp_files do
    temp_dir = System.tmp_dir!()
    
    temp_dir
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "test_"))
    |> Enum.each(fn file ->
      Path.join(temp_dir, file) |> File.rm()
    end)
  end
  
  @doc """
  Formats changeset errors for easier testing
  """
  def changeset_errors(changeset) do
    traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
  
  @doc """
  Measures execution time of a function
  """
  def measure_time(fun) do
    {time, result} = :timer.tc(fun)
    {time / 1000, result}  # Return time in milliseconds
  end
  
  @doc """
  Asserts that a function executes within a time limit
  """
  def assert_time_limit(fun, max_time_ms) do
    {time, result} = measure_time(fun)
    
    if time > max_time_ms do
      raise "Function took #{time}ms, expected under #{max_time_ms}ms"
    end
    
    result
  end
end

# Make test helpers available globally
import SlackClone.TestHelpers
