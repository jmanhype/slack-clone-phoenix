defmodule SlackClone.Files.FileAccessLog do
  @moduledoc """
  Schema for comprehensive file access logging and audit trail.
  
  Tracks all file access events including views, downloads, modifications,
  sharing activities, and administrative actions. Provides detailed audit
  capabilities for compliance, security monitoring, and usage analytics.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Jason.Encoder, except: [:__meta__]}

  schema "file_access_logs" do
    field :access_type, :string
    field :access_method, :string
    field :access_source, :string, default: "web"
    field :access_result, :string, default: "success"
    field :timestamp, :utc_datetime
    field :duration_ms, :integer
    field :bytes_transferred, :integer, default: 0
    field :user_agent, :string
    field :ip_address, :string
    field :geo_location, :map
    field :device_info, :map
    field :session_id, :string
    field :request_id, :string
    field :referrer_url, :string
    field :download_range, :string
    field :cache_status, :string
    field :compression_used, :boolean, default: false
    field :encryption_used, :boolean, default: false
    field :permission_level, :string
    field :access_context, :map, default: %{}
    field :sharing_context, :map
    field :collaboration_session_id, :string
    field :version_accessed, :string
    field :file_size_at_access, :integer
    field :file_hash_at_access, :string
    field :access_path, :string
    field :api_endpoint, :string
    field :http_method, :string
    field :http_status_code, :integer
    field :error_details, :map
    field :security_flags, {:array, :string}, default: []
    field :compliance_tags, {:array, :string}, default: []
    field :risk_score, :integer, default: 0
    field :anomaly_indicators, {:array, :string}, default: []
    field :bandwidth_usage_kb, :integer, default: 0
    field :cpu_time_ms, :integer, default: 0
    field :memory_usage_mb, :integer, default: 0
    field :cache_hit, :boolean, default: false
    field :cdn_used, :boolean, default: false
    field :edge_location, :string
    field :latency_ms, :integer
    field :quality_metrics, :map, default: %{}
    field :business_context, :map, default: %{}
    field :integration_source, :string
    field :automation_context, :map
    field :child_access_count, :integer, default: 0
    field :access_chain_depth, :integer, default: 0
    field :grouped_access_id, :string
    field :activity_correlation_id, :string
    field :is_bulk_operation, :boolean, default: false
    field :bulk_operation_size, :integer, default: 1
    field :privacy_level, :string, default: "standard"
    field :data_classification, :string
    field :retention_category, :string, default: "standard"
    field :archived, :boolean, default: false
    field :archived_at, :utc_datetime
    field :tags, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    # Associations
    belongs_to :file_upload, SlackClone.Files.FileUpload
    belongs_to :workspace, SlackClone.Workspaces.Workspace
    belongs_to :channel, SlackClone.Channels.Channel
    belongs_to :user, SlackClone.Accounts.User
    belongs_to :shared_link, SlackClone.Files.ShareableLink
    belongs_to :parent_access, __MODULE__

    has_many :child_accesses, __MODULE__, foreign_key: :parent_access_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a new file access log entry.
  """
  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :access_type, :access_method, :access_source, :access_result,
      :duration_ms, :bytes_transferred, :user_agent, :ip_address,
      :geo_location, :device_info, :session_id, :request_id, :referrer_url,
      :download_range, :cache_status, :compression_used, :encryption_used,
      :permission_level, :access_context, :sharing_context,
      :collaboration_session_id, :version_accessed, :file_size_at_access,
      :file_hash_at_access, :access_path, :api_endpoint, :http_method,
      :http_status_code, :error_details, :security_flags, :compliance_tags,
      :risk_score, :anomaly_indicators, :bandwidth_usage_kb, :cpu_time_ms,
      :memory_usage_mb, :cache_hit, :cdn_used, :edge_location, :latency_ms,
      :quality_metrics, :business_context, :integration_source,
      :automation_context, :parent_access_id, :access_chain_depth,
      :grouped_access_id, :activity_correlation_id, :is_bulk_operation,
      :bulk_operation_size, :privacy_level, :data_classification,
      :retention_category, :tags, :metadata, :file_upload_id, :workspace_id,
      :channel_id, :user_id, :shared_link_id
    ])
    |> validate_required([:access_type, :access_method, :file_upload_id])
    |> validate_inclusion(:access_type, [
      "view", "download", "upload", "edit", "delete", "copy", "move", "share",
      "unshare", "preview", "thumbnail", "search", "list", "permissions",
      "metadata", "version", "restore", "duplicate", "export", "import",
      "sync", "backup", "scan", "analyze", "transform", "admin"
    ])
    |> validate_inclusion(:access_method, [
      "direct", "link", "embed", "api", "webhook", "scheduled", "automated",
      "bulk", "sync", "integration", "mobile_app", "desktop_app", "cli"
    ])
    |> validate_inclusion(:access_source, [
      "web", "mobile", "desktop", "api", "webhook", "integration", "cli",
      "scheduled_task", "background_job", "admin_panel", "third_party"
    ])
    |> validate_inclusion(:access_result, [
      "success", "partial", "failed", "denied", "timeout", "cancelled",
      "throttled", "quota_exceeded", "error", "blocked"
    ])
    |> validate_inclusion(:cache_status, [
      "hit", "miss", "stale", "bypass", "expired", "not_cached"
    ])
    |> validate_inclusion(:permission_level, [
      "none", "read", "write", "admin", "owner", "viewer", "editor",
      "commenter", "reviewer", "limited", "custom"
    ])
    |> validate_inclusion(:privacy_level, [
      "public", "internal", "confidential", "restricted", "classified", "standard"
    ])
    |> validate_inclusion(:data_classification, [
      "public", "internal", "confidential", "restricted", "top_secret",
      "personal", "sensitive", "financial", "healthcare", "legal"
    ])
    |> validate_inclusion(:retention_category, [
      "temporary", "standard", "long_term", "permanent", "legal_hold",
      "compliance", "archive", "purge_eligible"
    ])
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> validate_number(:bytes_transferred, greater_than_or_equal_to: 0)
    |> validate_number(:file_size_at_access, greater_than_or_equal_to: 0)
    |> validate_number(:risk_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:bandwidth_usage_kb, greater_than_or_equal_to: 0)
    |> validate_number(:cpu_time_ms, greater_than_or_equal_to: 0)
    |> validate_number(:memory_usage_mb, greater_than_or_equal_to: 0)
    |> validate_number(:latency_ms, greater_than_or_equal_to: 0)
    |> validate_number(:access_chain_depth, greater_than_or_equal_to: 0)
    |> validate_number(:bulk_operation_size, greater_than: 0)
    |> validate_length(:tags, max: 20)
    |> validate_length(:user_agent, max: 2000)
    |> validate_length(:referrer_url, max: 2000)
    |> set_timestamp()
    |> calculate_risk_score()
    |> detect_anomalies()
    |> foreign_key_constraint(:file_upload_id)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:shared_link_id)
    |> foreign_key_constraint(:parent_access_id)
  end

  # Private functions for changeset operations

  defp set_timestamp(changeset) do
    put_change(changeset, :timestamp, DateTime.utc_now())
  end

  defp calculate_risk_score(changeset) do
    access_type = get_change(changeset, :access_type) || get_field(changeset, :access_type)
    access_method = get_change(changeset, :access_method) || get_field(changeset, :access_method)
    access_source = get_change(changeset, :access_source) || get_field(changeset, :access_source)
    ip_address = get_change(changeset, :ip_address) || get_field(changeset, :ip_address)
    
    base_score = case access_type do
      type when type in ["delete", "move", "share", "permissions", "admin"] -> 30
      type when type in ["edit", "upload", "copy", "export"] -> 20
      type when type in ["download", "duplicate"] -> 15
      type when type in ["view", "preview", "thumbnail"] -> 5
      _ -> 10
    end
    
    method_modifier = case access_method do
      "api" -> 10
      "webhook" -> 15
      "automated" -> 5
      _ -> 0
    end
    
    source_modifier = case access_source do
      "third_party" -> 20
      "integration" -> 10
      source when source in ["cli", "background_job"] -> 5
      _ -> 0
    end
    
    ip_modifier = if ip_address do
      cond do
        String.starts_with?(ip_address, "10.") or 
        String.starts_with?(ip_address, "192.168.") or
        String.starts_with?(ip_address, "172.") -> 0  # Internal IP
        true -> 10  # External IP
      end
    else
      5
    end
    
    total_score = min(base_score + method_modifier + source_modifier + ip_modifier, 100)
    put_change(changeset, :risk_score, total_score)
  end

  defp detect_anomalies(changeset) do
    indicators = []
    
    # Check for unusual file size access patterns
    indicators = check_file_size_anomaly(changeset, indicators)
    
    # Check for unusual access times
    indicators = check_time_anomaly(changeset, indicators)
    
    # Check for suspicious user agents
    indicators = check_user_agent_anomaly(changeset, indicators)
    
    # Check for bulk access patterns
    indicators = check_bulk_access_anomaly(changeset, indicators)
    
    put_change(changeset, :anomaly_indicators, indicators)
  end

  defp check_file_size_anomaly(changeset, indicators) do
    bytes_transferred = get_change(changeset, :bytes_transferred) || get_field(changeset, :bytes_transferred, 0)
    file_size = get_change(changeset, :file_size_at_access) || get_field(changeset, :file_size_at_access)
    
    if bytes_transferred > 0 && file_size && bytes_transferred > file_size * 1.5 do
      ["unusual_transfer_size" | indicators]
    else
      indicators
    end
  end

  defp check_time_anomaly(changeset, indicators) do
    now = DateTime.utc_now()
    hour = now.hour
    
    # Flag access during unusual hours (2 AM - 5 AM UTC as example)
    if hour >= 2 and hour <= 5 do
      ["unusual_access_time" | indicators]
    else
      indicators
    end
  end

  defp check_user_agent_anomaly(changeset, indicators) do
    user_agent = get_change(changeset, :user_agent) || get_field(changeset, :user_agent)
    
    suspicious_patterns = [
      "bot", "crawler", "scraper", "automated", "script", "wget", "curl"
    ]
    
    if user_agent && Enum.any?(suspicious_patterns, &String.contains?(String.downcase(user_agent), &1)) do
      ["suspicious_user_agent" | indicators]
    else
      indicators
    end
  end

  defp check_bulk_access_anomaly(changeset, indicators) do
    bulk_size = get_change(changeset, :bulk_operation_size) || get_field(changeset, :bulk_operation_size, 1)
    
    if bulk_size > 100 do
      ["large_bulk_operation" | indicators]
    else
      indicators
    end
  end

  # Query functions

  @doc """
  Returns access logs for a specific file.
  """
  def logs_for_file(query \\ __MODULE__, file_id) do
    from log in query,
      where: log.file_upload_id == ^file_id,
      order_by: [desc: log.timestamp]
  end

  @doc """
  Returns access logs for a user.
  """
  def logs_for_user(query \\ __MODULE__, user_id) do
    from log in query,
      where: log.user_id == ^user_id,
      order_by: [desc: log.timestamp]
  end

  @doc """
  Returns access logs for a workspace.
  """
  def logs_for_workspace(query \\ __MODULE__, workspace_id) do
    from log in query,
      where: log.workspace_id == ^workspace_id,
      order_by: [desc: log.timestamp]
  end

  @doc """
  Returns logs by access type.
  """
  def logs_by_type(query \\ __MODULE__, access_type) do
    from log in query,
      where: log.access_type == ^access_type,
      order_by: [desc: log.timestamp]
  end

  @doc """
  Returns logs within a date range.
  """
  def logs_in_range(query \\ __MODULE__, start_date, end_date) do
    from log in query,
      where: log.timestamp >= ^start_date and log.timestamp <= ^end_date,
      order_by: [desc: log.timestamp]
  end

  @doc """
  Returns high-risk access logs for security monitoring.
  """
  def high_risk_logs(query \\ __MODULE__, risk_threshold \\ 50) do
    from log in query,
      where: log.risk_score >= ^risk_threshold,
      order_by: [desc: log.risk_score, desc: log.timestamp]
  end

  @doc """
  Returns logs with anomaly indicators.
  """
  def anomalous_logs(query \\ __MODULE__) do
    from log in query,
      where: fragment("array_length(?, 1) > 0", log.anomaly_indicators),
      order_by: [desc: log.timestamp]
  end

  @doc """
  Returns failed access attempts.
  """
  def failed_access_logs(query \\ __MODULE__) do
    from log in query,
      where: log.access_result in ["failed", "denied", "blocked", "error"],
      order_by: [desc: log.timestamp]
  end

  @doc """
  Returns access statistics for a time period.
  """
  def access_statistics(query \\ __MODULE__, start_date, end_date) do
    from log in query,
      where: log.timestamp >= ^start_date and log.timestamp <= ^end_date,
      select: %{
        total_accesses: count(log.id),
        unique_users: count(log.user_id, :distinct),
        unique_files: count(log.file_upload_id, :distinct),
        total_bytes_transferred: sum(log.bytes_transferred),
        successful_accesses: filter(count(log.id), log.access_result == "success"),
        failed_accesses: filter(count(log.id), log.access_result != "success"),
        average_duration_ms: avg(log.duration_ms),
        high_risk_accesses: filter(count(log.id), log.risk_score >= 50)
      }
  end

  @doc """
  Returns top accessed files for a time period.
  """
  def top_accessed_files(query \\ __MODULE__, start_date, end_date, limit \\ 10) do
    from log in query,
      where: log.timestamp >= ^start_date and log.timestamp <= ^end_date,
      group_by: log.file_upload_id,
      select: %{
        file_upload_id: log.file_upload_id,
        access_count: count(log.id),
        unique_users: count(log.user_id, :distinct),
        total_bytes_transferred: sum(log.bytes_transferred),
        last_accessed: max(log.timestamp)
      },
      order_by: [desc: count(log.id)],
      limit: ^limit
  end

  @doc """
  Returns user activity summary for a time period.
  """
  def user_activity_summary(query \\ __MODULE__, start_date, end_date) do
    from log in query,
      where: log.timestamp >= ^start_date and log.timestamp <= ^end_date,
      group_by: log.user_id,
      select: %{
        user_id: log.user_id,
        total_accesses: count(log.id),
        unique_files: count(log.file_upload_id, :distinct),
        total_bytes_transferred: sum(log.bytes_transferred),
        average_risk_score: avg(log.risk_score),
        first_access: min(log.timestamp),
        last_access: max(log.timestamp),
        access_types: fragment("array_agg(DISTINCT ?)", log.access_type)
      },
      order_by: [desc: count(log.id)]
  end

  # Business logic functions

  @doc """
  Creates a comprehensive access log entry with context enrichment.
  """
  def create_enriched_log(base_attrs, enrichment_context \\ %{}) do
    enriched_attrs = base_attrs
    |> enrich_geo_location(enrichment_context)
    |> enrich_device_info(enrichment_context)
    |> enrich_business_context(enrichment_context)
    |> enrich_quality_metrics(enrichment_context)
    
    changeset(%__MODULE__{}, enriched_attrs)
  end

  defp enrich_geo_location(attrs, context) do
    ip_address = attrs[:ip_address]
    
    if ip_address && Map.get(context, :geo_lookup_enabled, true) do
      # In a real implementation, this would call a geo-location service
      geo_data = %{
        country: "Unknown",
        region: "Unknown", 
        city: "Unknown",
        latitude: 0.0,
        longitude: 0.0,
        timezone: "UTC",
        isp: "Unknown"
      }
      
      Map.put(attrs, :geo_location, geo_data)
    else
      attrs
    end
  end

  defp enrich_device_info(attrs, context) do
    user_agent = attrs[:user_agent]
    
    if user_agent && Map.get(context, :device_detection_enabled, true) do
      # In a real implementation, this would parse the user agent
      device_data = %{
        device_type: "unknown",
        browser: "unknown",
        browser_version: "unknown",
        os: "unknown",
        os_version: "unknown",
        is_mobile: false,
        is_tablet: false,
        is_desktop: true
      }
      
      Map.put(attrs, :device_info, device_data)
    else
      attrs
    end
  end

  defp enrich_business_context(attrs, context) do
    business_data = %{
      department: Map.get(context, :department),
      project: Map.get(context, :project),
      cost_center: Map.get(context, :cost_center),
      business_purpose: Map.get(context, :business_purpose),
      compliance_context: Map.get(context, :compliance_context)
    }
    
    Map.put(attrs, :business_context, business_data)
  end

  defp enrich_quality_metrics(attrs, context) do
    metrics_data = %{
      network_quality: Map.get(context, :network_quality, "unknown"),
      server_load: Map.get(context, :server_load, 0),
      cache_efficiency: Map.get(context, :cache_efficiency, 0.0),
      compression_ratio: Map.get(context, :compression_ratio, 1.0),
      error_rate: Map.get(context, :error_rate, 0.0)
    }
    
    Map.put(attrs, :quality_metrics, metrics_data)
  end

  @doc """
  Generates a compliance report for file access activities.
  """
  def generate_compliance_report(workspace_id, start_date, end_date, compliance_framework \\ "general") do
    logs = __MODULE__
    |> logs_for_workspace(workspace_id)
    |> logs_in_range(start_date, end_date)
    |> SlackClone.Repo.all()
    
    %{
      report_period: %{start: start_date, end: end_date},
      compliance_framework: compliance_framework,
      total_access_events: length(logs),
      unique_users: logs |> Enum.map(& &1.user_id) |> Enum.uniq() |> length(),
      unique_files: logs |> Enum.map(& &1.file_upload_id) |> Enum.uniq() |> length(),
      access_type_breakdown: group_by_access_type(logs),
      high_risk_activities: Enum.filter(logs, & &1.risk_score >= 50) |> length(),
      failed_access_attempts: Enum.filter(logs, & &1.access_result != "success") |> length(),
      anomalous_activities: Enum.filter(logs, & length(&1.anomaly_indicators) > 0) |> length(),
      data_retention_compliance: check_retention_compliance(logs),
      privacy_compliance: check_privacy_compliance(logs),
      security_incidents: identify_security_incidents(logs),
      recommendations: generate_compliance_recommendations(logs, compliance_framework)
    }
  end

  defp group_by_access_type(logs) do
    Enum.group_by(logs, & &1.access_type)
    |> Enum.map(fn {type, type_logs} -> 
      {type, %{count: length(type_logs), percentage: (length(type_logs) / length(logs)) * 100}}
    end)
    |> Enum.into(%{})
  end

  defp check_retention_compliance(logs) do
    categories = Enum.group_by(logs, & &1.retention_category)
    
    Enum.map(categories, fn {category, category_logs} ->
      {category, %{
        count: length(category_logs),
        oldest_access: Enum.min_by(category_logs, & &1.timestamp).timestamp,
        retention_status: "compliant"  # This would check against actual policies
      }}
    end)
    |> Enum.into(%{})
  end

  defp check_privacy_compliance(logs) do
    privacy_levels = Enum.group_by(logs, & &1.privacy_level)
    
    %{
      privacy_level_distribution: Enum.map(privacy_levels, fn {level, level_logs} ->
        {level, length(level_logs)}
      end) |> Enum.into(%{}),
      data_subject_rights: %{
        access_requests: 0,  # Would be populated from actual data
        deletion_requests: 0,
        portability_requests: 0
      },
      consent_tracking: %{
        explicit_consent: 0,
        implied_consent: 0,
        withdrawn_consent: 0
      }
    }
  end

  defp identify_security_incidents(logs) do
    high_risk_logs = Enum.filter(logs, & &1.risk_score >= 75)
    anomalous_logs = Enum.filter(logs, & length(&1.anomaly_indicators) > 0)
    failed_logs = Enum.filter(logs, & &1.access_result in ["denied", "blocked", "failed"])
    
    %{
      potential_incidents: length(high_risk_logs) + length(anomalous_logs),
      high_risk_accesses: length(high_risk_logs),
      anomalous_activities: length(anomalous_logs),
      access_violations: length(failed_logs),
      incident_types: identify_incident_types(high_risk_logs ++ anomalous_logs)
    }
  end

  defp identify_incident_types(incident_logs) do
    incident_logs
    |> Enum.flat_map(& &1.anomaly_indicators)
    |> Enum.frequencies()
  end

  defp generate_compliance_recommendations(logs, framework) do
    base_recommendations = [
      "Review high-risk access patterns regularly",
      "Implement additional monitoring for anomalous activities",
      "Consider implementing stricter access controls for sensitive files"
    ]
    
    framework_specific = case framework do
      "gdpr" -> [
        "Ensure data subject rights procedures are documented",
        "Implement consent tracking mechanisms",
        "Review data retention policies"
      ]
      "hipaa" -> [
        "Implement audit log protection mechanisms",
        "Review minimum necessary access policies",
        "Ensure business associate agreements are current"
      ]
      "sox" -> [
        "Implement segregation of duties for financial data access",
        "Ensure audit trails are tamper-evident",
        "Review access control effectiveness"
      ]
      _ -> []
    end
    
    base_recommendations ++ framework_specific
  end

  @doc """
  Archives old access logs based on retention policies.
  """
  def archive_old_logs(retention_days \\ 90) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-retention_days, :day)
    
    from(log in __MODULE__,
      where: log.timestamp < ^cutoff_date and log.archived == false,
      update: [set: [archived: true, archived_at: ^DateTime.utc_now()]]
    )
    |> SlackClone.Repo.update_all([])
  end

  @doc """
  Calculates bandwidth usage metrics for a time period.
  """
  def calculate_bandwidth_metrics(workspace_id, start_date, end_date) do
    stats = __MODULE__
    |> logs_for_workspace(workspace_id)
    |> logs_in_range(start_date, end_date)
    |> from(as: :log)
    |> select([log: log], %{
      total_bytes: sum(log.bytes_transferred),
      total_bandwidth_kb: sum(log.bandwidth_usage_kb),
      average_latency_ms: avg(log.latency_ms),
      cache_hit_rate: fragment("CAST(COUNT(CASE WHEN ? THEN 1 END) AS FLOAT) / COUNT(*)", log.cache_hit),
      cdn_usage_rate: fragment("CAST(COUNT(CASE WHEN ? THEN 1 END) AS FLOAT) / COUNT(*)", log.cdn_used),
      peak_concurrent_users: max(log.grouped_access_id)
    })
    |> SlackClone.Repo.one()
    
    %{
      period: %{start: start_date, end: end_date},
      data_transfer: %{
        total_bytes: stats.total_bytes || 0,
        total_bandwidth_kb: stats.total_bandwidth_kb || 0,
        average_file_size: if(stats.total_bytes, do: stats.total_bytes / 1, else: 0)
      },
      performance: %{
        average_latency_ms: stats.average_latency_ms || 0,
        cache_hit_rate: (stats.cache_hit_rate || 0) * 100,
        cdn_usage_rate: (stats.cdn_usage_rate || 0) * 100
      },
      optimization_score: calculate_optimization_score(stats)
    }
  end

  defp calculate_optimization_score(stats) do
    cache_score = min((stats.cache_hit_rate || 0) * 100, 40)
    cdn_score = min((stats.cdn_usage_rate || 0) * 100, 30)
    latency_score = case stats.average_latency_ms || 1000 do
      latency when latency < 100 -> 30
      latency when latency < 500 -> 20
      latency when latency < 1000 -> 10
      _ -> 0
    end
    
    Float.round(cache_score + cdn_score + latency_score, 1)
  end
end