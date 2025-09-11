defmodule SlackClone.Files.FileOperation do
  @moduledoc """
  Schema for tracking file operations and transformations within the system.
  
  Records all file manipulation activities including uploads, downloads, 
  modifications, conversions, compressions, and administrative actions.
  Provides detailed audit trails and analytics for file management workflows.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Jason.Encoder, except: [:__meta__]}

  schema "file_operations" do
    field :operation_type, :string
    field :operation_category, :string
    field :operation_status, :string, default: "pending"
    field :operation_priority, :string, default: "normal"
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :duration_ms, :integer
    field :bytes_processed, :integer, default: 0
    field :bytes_before, :integer
    field :bytes_after, :integer
    field :compression_ratio, :float
    field :quality_setting, :string
    field :format_before, :string
    field :format_after, :string
    field :dimensions_before, :map
    field :dimensions_after, :map
    field :metadata_before, :map
    field :metadata_after, :map
    field :operation_parameters, :map, default: %{}
    field :transformation_rules, :map, default: %{}
    field :processing_engine, :string
    field :engine_version, :string
    field :cpu_usage_percent, :float
    field :memory_usage_mb, :integer
    field :temp_storage_mb, :integer
    field :network_bytes_in, :integer, default: 0
    field :network_bytes_out, :integer, default: 0
    field :error_message, :string
    field :error_code, :string
    field :retry_count, :integer, default: 0
    field :max_retries, :integer, default: 3
    field :success_rate, :float, default: 0.0
    field :quality_score, :float
    field :performance_score, :float
    field :cost_estimate, :decimal
    field :cost_actual, :decimal
    field :energy_consumption_kwh, :float
    field :carbon_footprint_kg, :float
    field :batch_id, :string
    field :pipeline_stage, :string
    field :dependency_operations, {:array, :binary_id}, default: []
    field :child_operations, {:array, :binary_id}, default: []
    field :output_files, {:array, :map}, default: []
    field :intermediate_files, {:array, :string}, default: []
    field :cleanup_completed, :boolean, default: false
    field :logs, {:array, :map}, default: []
    field :performance_metrics, :map, default: %{}
    field :validation_results, :map, default: %{}
    field :security_checks, :map, default: %{}
    field :compliance_status, :string, default: "not_checked"
    field :tags, {:array, :string}, default: []
    field :notes, :string
    field :is_automated, :boolean, default: false
    field :scheduled_for, :utc_datetime
    field :execution_context, :string, default: "user_initiated"

    # Associations
    belongs_to :file_upload, SlackClone.Files.FileUpload
    belongs_to :workspace, SlackClone.Workspaces.Workspace
    belongs_to :channel, SlackClone.Channels.Channel
    belongs_to :initiated_by, SlackClone.Accounts.User
    belongs_to :executed_by, SlackClone.Accounts.User
    belongs_to :parent_operation, __MODULE__

    has_many :child_operations_rel, __MODULE__, foreign_key: :parent_operation_id
    has_many :operation_logs, SlackClone.Files.FileOperationLog

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new file operation.
  """
  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [
      :operation_type, :operation_category, :operation_priority,
      :operation_parameters, :transformation_rules, :processing_engine,
      :engine_version, :quality_setting, :batch_id, :pipeline_stage,
      :dependency_operations, :max_retries, :tags, :notes, :is_automated,
      :scheduled_for, :execution_context, :file_upload_id, :workspace_id,
      :channel_id, :initiated_by_id, :parent_operation_id
    ])
    |> validate_required([
      :operation_type, :operation_category, :file_upload_id, :initiated_by_id
    ])
    |> validate_inclusion(:operation_type, [
      "upload", "download", "convert", "compress", "decompress", "resize",
      "rotate", "crop", "watermark", "thumbnail", "preview", "analyze",
      "virus_scan", "encrypt", "decrypt", "backup", "restore", "duplicate",
      "move", "copy", "delete", "rename", "merge", "split", "extract",
      "archive", "sync", "transcode", "optimize", "validate", "repair"
    ])
    |> validate_inclusion(:operation_category, [
      "storage", "transformation", "security", "analysis", "maintenance",
      "sync", "backup", "compliance", "optimization", "user_action"
    ])
    |> validate_inclusion(:operation_status, [
      "pending", "queued", "running", "paused", "completed", "failed",
      "cancelled", "timeout", "retry", "partial"
    ])
    |> validate_inclusion(:operation_priority, [
      "low", "normal", "high", "urgent", "critical"
    ])
    |> validate_inclusion(:execution_context, [
      "user_initiated", "automated", "scheduled", "webhook", "api",
      "batch_process", "system_maintenance", "security_scan", "compliance_check"
    ])
    |> validate_inclusion(:compliance_status, [
      "not_checked", "compliant", "non_compliant", "review_required", "exempted"
    ])
    |> validate_number(:max_retries, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_number(:retry_count, greater_than_or_equal_to: 0)
    |> validate_length(:tags, max: 20)
    |> validate_length(:notes, max: 2000)
    |> set_start_timestamp()
    |> foreign_key_constraint(:file_upload_id)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:initiated_by_id)
    |> foreign_key_constraint(:executed_by_id)
    |> foreign_key_constraint(:parent_operation_id)
  end

  @doc """
  Update changeset for modifying operation progress and status.
  """
  def update_changeset(operation, attrs) do
    operation
    |> cast(attrs, [
      :operation_status, :completed_at, :duration_ms, :bytes_processed,
      :bytes_before, :bytes_after, :compression_ratio, :format_before,
      :format_after, :dimensions_before, :dimensions_after, :metadata_before,
      :metadata_after, :cpu_usage_percent, :memory_usage_mb, :temp_storage_mb,
      :network_bytes_in, :network_bytes_out, :error_message, :error_code,
      :retry_count, :success_rate, :quality_score, :performance_score,
      :cost_actual, :energy_consumption_kwh, :carbon_footprint_kg,
      :child_operations, :output_files, :intermediate_files, :cleanup_completed,
      :logs, :performance_metrics, :validation_results, :security_checks,
      :compliance_status, :executed_by_id, :notes
    ])
    |> validate_inclusion(:operation_status, [
      "pending", "queued", "running", "paused", "completed", "failed",
      "cancelled", "timeout", "retry", "partial"
    ])
    |> validate_inclusion(:compliance_status, [
      "not_checked", "compliant", "non_compliant", "review_required", "exempted"
    ])
    |> validate_number(:bytes_processed, greater_than_or_equal_to: 0)
    |> validate_number(:bytes_before, greater_than_or_equal_to: 0)
    |> validate_number(:bytes_after, greater_than_or_equal_to: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> validate_number(:retry_count, greater_than_or_equal_to: 0)
    |> validate_number(:cpu_usage_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:memory_usage_mb, greater_than_or_equal_to: 0)
    |> validate_number(:quality_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:performance_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> check_completion_requirements()
    |> calculate_derived_metrics()
  end

  # Private functions for changeset operations

  defp set_start_timestamp(changeset) do
    put_change(changeset, :started_at, DateTime.utc_now())
  end

  defp check_completion_requirements(changeset) do
    status = get_change(changeset, :operation_status) || get_field(changeset, :operation_status)
    
    if status in ["completed", "failed", "cancelled"] do
      completed_at = get_change(changeset, :completed_at) || get_field(changeset, :completed_at)
      
      if is_nil(completed_at) do
        put_change(changeset, :completed_at, DateTime.utc_now())
      else
        changeset
      end
    else
      changeset
    end
  end

  defp calculate_derived_metrics(changeset) do
    changeset
    |> calculate_duration()
    |> calculate_compression_ratio()
    |> calculate_success_rate()
  end

  defp calculate_duration(changeset) do
    started_at = get_field(changeset, :started_at)
    completed_at = get_change(changeset, :completed_at) || get_field(changeset, :completed_at)
    
    if started_at && completed_at do
      duration_ms = DateTime.diff(completed_at, started_at, :millisecond)
      put_change(changeset, :duration_ms, duration_ms)
    else
      changeset
    end
  end

  defp calculate_compression_ratio(changeset) do
    bytes_before = get_change(changeset, :bytes_before) || get_field(changeset, :bytes_before)
    bytes_after = get_change(changeset, :bytes_after) || get_field(changeset, :bytes_after)
    
    if bytes_before && bytes_after && bytes_before > 0 do
      ratio = bytes_after / bytes_before
      put_change(changeset, :compression_ratio, Float.round(ratio, 4))
    else
      changeset
    end
  end

  defp calculate_success_rate(changeset) do
    retry_count = get_change(changeset, :retry_count) || get_field(changeset, :retry_count, 0)
    max_retries = get_field(changeset, :max_retries, 3)
    status = get_change(changeset, :operation_status) || get_field(changeset, :operation_status)
    
    if status == "completed" do
      put_change(changeset, :success_rate, 100.0)
    else
      attempts = retry_count + 1
      max_attempts = max_retries + 1
      rate = if status in ["failed", "cancelled"], do: 0.0, else: (attempts / max_attempts) * 100
      put_change(changeset, :success_rate, Float.round(rate, 1))
    end
  end

  # Query functions

  @doc """
  Returns file operations for a specific file.
  """
  def operations_for_file(query \\ __MODULE__, file_id) do
    from op in query,
      where: op.file_upload_id == ^file_id,
      order_by: [desc: op.started_at]
  end

  @doc """
  Returns file operations for a workspace.
  """
  def operations_for_workspace(query \\ __MODULE__, workspace_id) do
    from op in query,
      where: op.workspace_id == ^workspace_id,
      order_by: [desc: op.started_at]
  end

  @doc """
  Returns operations by status.
  """
  def operations_by_status(query \\ __MODULE__, status) do
    from op in query,
      where: op.operation_status == ^status,
      order_by: [desc: op.started_at]
  end

  @doc """
  Returns operations by type and category.
  """
  def operations_by_type(query \\ __MODULE__, operation_type, category \\ nil) do
    query = from op in query, where: op.operation_type == ^operation_type
    
    if category do
      from op in query, where: op.operation_category == ^category
    else
      query
    end
  end

  @doc """
  Returns failed operations that can be retried.
  """
  def retryable_operations(query \\ __MODULE__) do
    from op in query,
      where: op.operation_status == "failed" and op.retry_count < op.max_retries,
      order_by: [asc: op.started_at]
  end

  @doc """
  Returns long-running operations that may need attention.
  """
  def long_running_operations(query \\ __MODULE__, threshold_minutes \\ 30) do
    threshold_time = DateTime.utc_now() |> DateTime.add(-threshold_minutes, :minute)
    
    from op in query,
      where: op.operation_status == "running" and op.started_at < ^threshold_time,
      order_by: [asc: op.started_at]
  end

  @doc """
  Returns operations scheduled for future execution.
  """
  def scheduled_operations(query \\ __MODULE__) do
    now = DateTime.utc_now()
    
    from op in query,
      where: op.operation_status == "pending" and not is_nil(op.scheduled_for) and op.scheduled_for > ^now,
      order_by: [asc: op.scheduled_for]
  end

  @doc """
  Returns operations ready for execution (scheduled time has arrived).
  """
  def ready_for_execution(query \\ __MODULE__) do
    now = DateTime.utc_now()
    
    from op in query,
      where: op.operation_status == "pending" and 
        (is_nil(op.scheduled_for) or op.scheduled_for <= ^now),
      order_by: [asc: op.started_at]
  end

  @doc """
  Returns batch operation statistics.
  """
  def batch_statistics(query \\ __MODULE__, batch_id) do
    from op in query,
      where: op.batch_id == ^batch_id,
      select: %{
        total_operations: count(op.id),
        completed: filter(count(op.id), op.operation_status == "completed"),
        failed: filter(count(op.id), op.operation_status == "failed"),
        running: filter(count(op.id), op.operation_status == "running"),
        total_bytes_processed: sum(op.bytes_processed),
        average_duration_ms: avg(op.duration_ms),
        total_cost: sum(op.cost_actual)
      }
  end

  # Business logic functions

  @doc """
  Adds a log entry to the operation's log history.
  """
  def add_log_entry(operation, level, message, metadata \\ %{}) do
    timestamp = DateTime.utc_now()
    
    log_entry = %{
      timestamp: timestamp,
      level: level,
      message: message,
      metadata: metadata
    }
    
    current_logs = operation.logs || []
    updated_logs = [log_entry | current_logs]
    
    # Keep only the most recent 100 log entries
    trimmed_logs = Enum.take(updated_logs, 100)
    
    %{operation | logs: trimmed_logs}
  end

  @doc """
  Calculates the performance score based on various metrics.
  """
  def calculate_performance_score(operation) do
    # Base scores for different aspects
    speed_score = calculate_speed_score(operation)
    efficiency_score = calculate_efficiency_score(operation)
    reliability_score = calculate_reliability_score(operation)
    cost_score = calculate_cost_score(operation)
    
    # Weighted average
    overall_score = (speed_score * 0.3) + (efficiency_score * 0.25) + 
                   (reliability_score * 0.35) + (cost_score * 0.1)
    
    Float.round(overall_score, 1)
  end

  defp calculate_speed_score(operation) do
    if operation.duration_ms && operation.bytes_processed do
      # Calculate MB/s throughput
      throughput_mbps = (operation.bytes_processed / (1024 * 1024)) / (operation.duration_ms / 1000)
      
      cond do
        throughput_mbps >= 50 -> 100
        throughput_mbps >= 20 -> 80
        throughput_mbps >= 10 -> 60
        throughput_mbps >= 5 -> 40
        throughput_mbps >= 1 -> 20
        true -> 10
      end
    else
      50  # Default neutral score
    end
  end

  defp calculate_efficiency_score(operation) do
    cpu_score = case operation.cpu_usage_percent do
      nil -> 50
      usage when usage <= 20 -> 100
      usage when usage <= 40 -> 80
      usage when usage <= 60 -> 60
      usage when usage <= 80 -> 40
      _ -> 20
    end
    
    memory_score = case operation.memory_usage_mb do
      nil -> 50
      usage when usage <= 100 -> 100
      usage when usage <= 500 -> 80
      usage when usage <= 1000 -> 60
      usage when usage <= 2000 -> 40
      _ -> 20
    end
    
    (cpu_score + memory_score) / 2
  end

  defp calculate_reliability_score(operation) do
    retry_score = case operation.retry_count do
      0 -> 100
      1 -> 80
      2 -> 60
      3 -> 40
      _ -> 20
    end
    
    status_score = case operation.operation_status do
      "completed" -> 100
      "partial" -> 70
      "failed" -> 0
      "cancelled" -> 30
      _ -> 50
    end
    
    (retry_score + status_score) / 2
  end

  defp calculate_cost_score(operation) do
    if operation.cost_estimate && operation.cost_actual do
      cost_ratio = Decimal.to_float(operation.cost_actual) / Decimal.to_float(operation.cost_estimate)
      
      cond do
        cost_ratio <= 0.8 -> 100  # Under budget
        cost_ratio <= 1.0 -> 90   # On budget
        cost_ratio <= 1.2 -> 70   # Slightly over
        cost_ratio <= 1.5 -> 50   # Moderately over
        true -> 20                # Significantly over
      end
    else
      50  # Default neutral score
    end
  end

  @doc """
  Estimates the operation cost based on resource usage and complexity.
  """
  def estimate_cost(operation_type, file_size_bytes, parameters \\ %{}) do
    base_cost = case operation_type do
      "upload" -> 0.001
      "download" -> 0.0005
      "convert" -> 0.01
      "compress" -> 0.005
      "thumbnail" -> 0.002
      "virus_scan" -> 0.003
      "backup" -> 0.002
      _ -> 0.005
    end
    
    # Size multiplier (cost per MB)
    size_mb = file_size_bytes / (1024 * 1024)
    size_cost = base_cost * size_mb
    
    # Complexity multiplier
    complexity_multiplier = Map.get(parameters, "complexity_factor", 1.0)
    
    # Quality multiplier for transformations
    quality_multiplier = case Map.get(parameters, "quality", "standard") do
      "low" -> 0.7
      "standard" -> 1.0
      "high" -> 1.5
      "lossless" -> 2.0
      _ -> 1.0
    end
    
    total_cost = size_cost * complexity_multiplier * quality_multiplier
    Decimal.from_float(total_cost)
  end

  @doc """
  Checks if an operation can be safely retried.
  """
  def can_retry?(operation) do
    operation.retry_count < operation.max_retries and
    operation.operation_status in ["failed", "timeout"] and
    not has_permanent_error?(operation)
  end

  defp has_permanent_error?(operation) do
    permanent_error_codes = [
      "file_not_found", "permission_denied", "invalid_format",
      "corrupted_file", "unsupported_operation", "quota_exceeded"
    ]
    
    operation.error_code in permanent_error_codes
  end

  @doc """
  Gets the next pipeline stage for multi-stage operations.
  """
  def get_next_pipeline_stage(current_stage, operation_type) do
    pipeline_stages = %{
      "convert" => ["validate", "extract", "transform", "optimize", "save"],
      "backup" => ["prepare", "compress", "encrypt", "transfer", "verify"],
      "restore" => ["locate", "decrypt", "decompress", "validate", "restore"]
    }
    
    stages = Map.get(pipeline_stages, operation_type, [])
    current_index = Enum.find_index(stages, &(&1 == current_stage))
    
    if current_index && current_index < length(stages) - 1 do
      Enum.at(stages, current_index + 1)
    else
      nil
    end
  end

  @doc """
  Calculates environmental impact metrics for the operation.
  """
  def calculate_environmental_impact(operation) do
    # Estimate energy consumption based on CPU usage and duration
    energy_kwh = if operation.cpu_usage_percent && operation.duration_ms do
      # Rough estimate: 100W TDP at 100% CPU usage
      cpu_power_watts = (operation.cpu_usage_percent / 100) * 100
      duration_hours = operation.duration_ms / (1000 * 60 * 60)
      cpu_power_watts * duration_hours / 1000
    else
      0.0
    end
    
    # Carbon footprint based on regional energy grid (example: 0.5 kg CO2/kWh)
    carbon_factor = 0.5  # This should be configurable based on data center location
    carbon_kg = energy_kwh * carbon_factor
    
    %{
      energy_consumption_kwh: Float.round(energy_kwh, 6),
      carbon_footprint_kg: Float.round(carbon_kg, 6),
      efficiency_rating: classify_efficiency(energy_kwh, operation.bytes_processed)
    }
  end

  defp classify_efficiency(energy_kwh, bytes_processed) do
    if energy_kwh > 0 && bytes_processed do
      # kWh per GB processed
      kwh_per_gb = energy_kwh / (bytes_processed / (1024 * 1024 * 1024))
      
      cond do
        kwh_per_gb <= 0.001 -> "excellent"
        kwh_per_gb <= 0.005 -> "good"
        kwh_per_gb <= 0.01 -> "average"
        kwh_per_gb <= 0.05 -> "poor"
        true -> "inefficient"
      end
    else
      "unknown"
    end
  end
end