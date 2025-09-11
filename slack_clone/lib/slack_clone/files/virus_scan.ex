defmodule SlackClone.Files.VirusScan do
  @moduledoc """
  Schema for tracking virus scan results and file security analysis.
  Integrates with multiple antivirus engines and threat intelligence services.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "virus_scans" do
    belongs_to :file_upload, SlackClone.Files.FileUpload

    # Scan configuration
    field :scan_engine, :string # clamav, virustotal, windows_defender, custom
    field :scan_version, :string # Engine version
    field :signature_version, :string # Virus definition version
    field :scan_type, :string # quick, full, deep, heuristic
    
    # Scan execution
    field :scan_started_at, :utc_datetime
    field :scan_completed_at, :utc_datetime
    field :scan_duration_ms, :integer
    field :scan_status, :string # pending, scanning, completed, failed, timeout, cancelled
    field :scan_priority, :string, default: "normal" # low, normal, high, urgent
    
    # Results
    field :is_clean, :boolean
    field :threat_detected, :boolean, default: false
    field :threat_count, :integer, default: 0
    field :threat_names, {:array, :string}, default: []
    field :threat_types, {:array, :string}, default: [] # virus, malware, trojan, adware, etc.
    field :severity_level, :string # low, medium, high, critical
    field :confidence_score, :float, default: 0.0 # 0.0 to 1.0
    
    # Detailed threat information
    field :threat_details, :map, default: %{}
    field :infected_files, {:array, :string}, default: []
    field :suspicious_patterns, {:array, :string}, default: []
    field :behavioral_indicators, {:array, :string}, default: []
    
    # File analysis
    field :file_hash_md5, :string
    field :file_hash_sha1, :string
    field :file_hash_sha256, :string
    field :file_size_scanned, :integer
    field :file_type_detected, :string
    field :mime_type_detected, :string
    
    # Multi-engine results (for aggregated scans)
    field :engines_used, {:array, :string}, default: []
    field :engines_detected, :integer, default: 0
    field :engines_total, :integer, default: 1
    field :detection_ratio, :float, default: 0.0 # engines_detected / engines_total
    field :engine_results, :map, default: %{} # Detailed per-engine results
    
    # Reputation and intelligence
    field :reputation_score, :float # -100 to 100 (negative = malicious, positive = clean)
    field :first_seen_date, :utc_datetime
    field :last_seen_date, :utc_datetime
    field :submission_count, :integer, default: 0
    field :community_score, :float, default: 0.0
    field :vendor_classifications, :map, default: %{}
    
    # Quarantine and remediation
    field :quarantined, :boolean, default: false
    field :quarantine_path, :string
    field :quarantine_reason, :string
    field :auto_quarantine, :boolean, default: false
    field :remediation_suggested, :string # delete, quarantine, clean, ignore
    field :remediation_applied, :string
    field :remediation_successful, :boolean
    
    # Error handling
    field :scan_error, :string
    field :error_code, :string
    field :error_details, :map
    field :retry_count, :integer, default: 0
    field :max_retries, :integer, default: 3
    field :retry_after, :utc_datetime
    
    # Performance and costs
    field :cpu_usage_percent, :float
    field :memory_usage_mb, :integer
    field :network_usage_bytes, :integer
    field :api_calls_made, :integer, default: 0
    field :scan_cost_estimate, :float, default: 0.0
    
    # Compliance and audit
    field :compliance_checked, :boolean, default: false
    field :compliance_status, :string # compliant, non_compliant, unknown
    field :policy_violations, {:array, :string}, default: []
    field :audit_required, :boolean, default: false
    field :audit_log, :string
    
    # Integration metadata
    field :external_scan_id, :string # Reference to external service
    field :webhook_delivered, :boolean, default: false
    field :webhook_url, :string
    field :integration_metadata, :map, default: %{}
    
    # Caching and optimization
    field :cache_key, :string
    field :cached_result, :boolean, default: false
    field :cache_expires_at, :utc_datetime
    field :skip_future_scans, :boolean, default: false
    field :whitelist_reason, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(scan, attrs) do
    scan
    |> cast(attrs, [
      :file_upload_id, :scan_engine, :scan_version, :signature_version, :scan_type,
      :scan_started_at, :scan_completed_at, :scan_duration_ms, :scan_status, :scan_priority,
      :is_clean, :threat_detected, :threat_count, :threat_names, :threat_types,
      :severity_level, :confidence_score, :threat_details, :infected_files,
      :suspicious_patterns, :behavioral_indicators, :file_hash_md5, :file_hash_sha1,
      :file_hash_sha256, :file_size_scanned, :file_type_detected, :mime_type_detected,
      :engines_used, :engines_detected, :engines_total, :detection_ratio, :engine_results,
      :reputation_score, :first_seen_date, :last_seen_date, :submission_count,
      :community_score, :vendor_classifications, :quarantined, :quarantine_path,
      :quarantine_reason, :auto_quarantine, :remediation_suggested, :remediation_applied,
      :remediation_successful, :scan_error, :error_code, :error_details, :retry_count,
      :max_retries, :retry_after, :cpu_usage_percent, :memory_usage_mb, :network_usage_bytes,
      :api_calls_made, :scan_cost_estimate, :compliance_checked, :compliance_status,
      :policy_violations, :audit_required, :audit_log, :external_scan_id, :webhook_delivered,
      :webhook_url, :integration_metadata, :cache_key, :cached_result, :cache_expires_at,
      :skip_future_scans, :whitelist_reason
    ])
    |> validate_required([:file_upload_id, :scan_engine, :scan_status])
    |> validate_inclusion(:scan_engine, ["clamav", "virustotal", "windows_defender", "mcafee", "symantec", "kaspersky", "custom"])
    |> validate_inclusion(:scan_type, ["quick", "full", "deep", "heuristic", "realtime"])
    |> validate_inclusion(:scan_status, ["pending", "scanning", "completed", "failed", "timeout", "cancelled"])
    |> validate_inclusion(:scan_priority, ["low", "normal", "high", "urgent"])
    |> validate_inclusion(:severity_level, ["low", "medium", "high", "critical", nil])
    |> validate_inclusion(:remediation_suggested, ["delete", "quarantine", "clean", "ignore", "manual_review", nil])
    |> validate_inclusion(:compliance_status, ["compliant", "non_compliant", "unknown", "pending"])
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:detection_ratio, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:reputation_score, greater_than_or_equal_to: -100.0, less_than_or_equal_to: 100.0)
    |> validate_number(:engines_detected, greater_than_or_equal_to: 0)
    |> validate_number(:engines_total, greater_than: 0)
    |> validate_number(:threat_count, greater_than_or_equal_to: 0)
    |> validate_number(:retry_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:file_upload_id, :scan_engine])
    |> put_detection_ratio()
    |> put_cache_key()
  end

  defp put_detection_ratio(changeset) do
    detected = get_field(changeset, :engines_detected) || 0
    total = get_field(changeset, :engines_total) || 1
    
    if total > 0 do
      put_change(changeset, :detection_ratio, detected / total)
    else
      changeset
    end
  end

  defp put_cache_key(changeset) do
    if get_field(changeset, :cache_key) do
      changeset
    else
      file_hash = get_field(changeset, :file_hash_sha256) || get_field(changeset, :file_hash_md5)
      scan_engine = get_field(changeset, :scan_engine)
      
      if file_hash && scan_engine do
        cache_key = "scan:#{scan_engine}:#{file_hash}"
        put_change(changeset, :cache_key, cache_key)
      else
        changeset
      end
    end
  end

  def create_scan_changeset(file_upload_id, engine, opts \\ []) do
    now = DateTime.utc_now()
    
    attrs = %{
      file_upload_id: file_upload_id,
      scan_engine: engine,
      scan_status: "pending",
      scan_priority: Keyword.get(opts, :priority, "normal"),
      scan_type: Keyword.get(opts, :scan_type, "quick"),
      max_retries: Keyword.get(opts, :max_retries, 3),
      auto_quarantine: Keyword.get(opts, :auto_quarantine, false)
    }
    
    %__MODULE__{}
    |> changeset(attrs)
  end

  def start_scan_changeset(scan) do
    scan
    |> change(%{
      scan_status: "scanning",
      scan_started_at: DateTime.utc_now(),
      retry_count: scan.retry_count + 1
    })
  end

  def complete_scan_changeset(scan, results) do
    now = DateTime.utc_now()
    duration = if scan.scan_started_at do
      DateTime.diff(now, scan.scan_started_at, :millisecond)
    else
      0
    end
    
    # Determine if file is clean based on results
    is_clean = not (results[:threat_detected] || false)
    
    changes = %{
      scan_status: "completed",
      scan_completed_at: now,
      scan_duration_ms: duration,
      is_clean: is_clean,
      threat_detected: results[:threat_detected] || false,
      threat_count: length(results[:threat_names] || []),
      threat_names: results[:threat_names] || [],
      threat_types: results[:threat_types] || [],
      severity_level: results[:severity_level],
      confidence_score: results[:confidence_score] || 1.0,
      threat_details: results[:threat_details] || %{},
      reputation_score: results[:reputation_score],
      engines_detected: results[:engines_detected] || 0,
      engines_total: results[:engines_total] || 1,
      cache_expires_at: DateTime.add(now, 24 * 3600, :second) # Cache for 24 hours
    }
    
    # Auto-quarantine if enabled and threats detected
    changes = if scan.auto_quarantine and (results[:threat_detected] || false) do
      Map.merge(changes, %{
        quarantined: true,
        quarantine_reason: "Auto-quarantined due to threat detection",
        remediation_suggested: "quarantine"
      })
    else
      changes
    end
    
    scan
    |> change(changes)
  end

  def fail_scan_changeset(scan, error_info) do
    should_retry = scan.retry_count < scan.max_retries
    
    changes = %{
      scan_status: if(should_retry, do: "failed", else: "failed"),
      scan_error: error_info[:message],
      error_code: error_info[:code],
      error_details: error_info[:details] || %{}
    }
    
    changes = if should_retry do
      retry_delay = min(300 * :math.pow(2, scan.retry_count), 3600) # Exponential backoff, max 1 hour
      Map.put(changes, :retry_after, DateTime.add(DateTime.utc_now(), round(retry_delay), :second))
    else
      changes
    end
    
    scan
    |> change(changes)
  end

  def quarantine_changeset(scan, reason) do
    scan
    |> change(%{
      quarantined: true,
      quarantine_reason: reason,
      quarantine_path: generate_quarantine_path(scan),
      remediation_applied: "quarantine"
    })
  end

  defp generate_quarantine_path(scan) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "quarantine/#{scan.file_upload_id}/#{timestamp}"
  end

  # Query functions
  def for_file_query(file_upload_id) do
    from s in __MODULE__,
      where: s.file_upload_id == ^file_upload_id,
      order_by: [desc: :inserted_at]
  end

  def by_status_query(status) do
    from s in __MODULE__,
      where: s.scan_status == ^status,
      order_by: [
        asc: fragment("CASE ? WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END", s.scan_priority),
        asc: :inserted_at
      ]
  end

  def pending_scans_query(limit \\ 10) do
    now = DateTime.utc_now()
    
    from s in __MODULE__,
      where: s.scan_status == "pending" or 
             (s.scan_status == "failed" and s.retry_count < s.max_retries and 
              (is_nil(s.retry_after) or s.retry_after <= ^now)),
      order_by: [
        asc: fragment("CASE ? WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END", s.scan_priority),
        asc: :inserted_at
      ],
      limit: ^limit
  end

  def threats_detected_query(days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from s in __MODULE__,
      where: s.threat_detected == true,
      where: s.scan_completed_at >= ^cutoff,
      order_by: [desc: :scan_completed_at]
  end

  def quarantined_files_query do
    from s in __MODULE__,
      where: s.quarantined == true,
      order_by: [desc: :updated_at]
  end

  def high_risk_files_query(severity_threshold \\ "high") do
    severities = case severity_threshold do
      "critical" -> ["critical"]
      "high" -> ["critical", "high"]
      "medium" -> ["critical", "high", "medium"]
      _ -> ["critical", "high", "medium", "low"]
    end
    
    from s in __MODULE__,
      where: s.threat_detected == true,
      where: s.severity_level in ^severities,
      where: s.scan_status == "completed",
      order_by: [
        asc: fragment("CASE ? WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END", s.severity_level),
        desc: :scan_completed_at
      ]
  end

  def scan_performance_query(days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from s in __MODULE__,
      where: s.scan_completed_at >= ^cutoff,
      where: s.scan_status == "completed",
      group_by: s.scan_engine,
      select: %{
        scan_engine: s.scan_engine,
        total_scans: count(s.id),
        avg_scan_time: avg(s.scan_duration_ms),
        threats_detected: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", s.threat_detected)),
        avg_confidence: avg(s.confidence_score),
        success_rate: fragment("ROUND(COUNT(CASE WHEN ? = 'completed' THEN 1 END) * 100.0 / COUNT(*), 2)", s.scan_status)
      }
  end

  def reputation_analysis_query(reputation_threshold \\ -50.0) do
    from s in __MODULE__,
      where: not is_nil(s.reputation_score),
      where: s.reputation_score <= ^reputation_threshold,
      order_by: [asc: s.reputation_score]
  end

  def compliance_violations_query do
    from s in __MODULE__,
      where: s.compliance_status == "non_compliant",
      where: fragment("array_length(?, 1) > 0", s.policy_violations),
      order_by: [desc: :updated_at]
  end

  def cached_results_query(expired_only \\ false) do
    query = from s in __MODULE__,
      where: s.cached_result == true,
      order_by: [desc: :cache_expires_at]
    
    if expired_only do
      from s in query,
        where: s.cache_expires_at <= ^DateTime.utc_now()
    else
      query
    end
  end

  # Helper functions
  def is_scan_needed?(file_upload, engine) do
    # Check if scan already exists and is valid
    case SlackClone.Repo.get_by(__MODULE__, file_upload_id: file_upload.id, scan_engine: engine) do
      nil -> true
      %{scan_status: "failed", retry_count: count, max_retries: max} when count >= max -> false
      %{scan_status: "completed", cache_expires_at: expires_at} -> 
        DateTime.compare(DateTime.utc_now(), expires_at) == :gt
      %{skip_future_scans: true} -> false
      _ -> false
    end
  end

  def calculate_threat_score(scan) do
    base_score = case scan.severity_level do
      "critical" -> 100
      "high" -> 75
      "medium" -> 50
      "low" -> 25
      _ -> 0
    end
    
    # Adjust based on confidence and detection ratio
    confidence_multiplier = scan.confidence_score || 1.0
    detection_multiplier = scan.detection_ratio || 0.0
    
    adjusted_score = base_score * confidence_multiplier * (0.5 + 0.5 * detection_multiplier)
    
    # Factor in reputation score
    reputation_adjustment = case scan.reputation_score do
      score when not is_nil(score) and score < -50 -> 20
      score when not is_nil(score) and score < 0 -> 10
      _ -> 0
    end
    
    min(round(adjusted_score + reputation_adjustment), 100)
  end

  def get_remediation_recommendation(scan) do
    threat_score = calculate_threat_score(scan)
    
    cond do
      threat_score >= 90 -> "delete"
      threat_score >= 70 -> "quarantine"
      threat_score >= 40 -> "manual_review"
      threat_score >= 20 -> "clean"
      true -> "ignore"
    end
  end

  def aggregate_multi_engine_results(scans) do
    total_engines = length(scans)
    detecting_engines = Enum.count(scans, & &1.threat_detected)
    
    threats = scans
    |> Enum.flat_map(& &1.threat_names)
    |> Enum.uniq()
    
    max_severity = scans
    |> Enum.map(& &1.severity_level)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce("low", fn severity, acc ->
      severity_priority = %{"critical" => 4, "high" => 3, "medium" => 2, "low" => 1}
      if (severity_priority[severity] || 0) > (severity_priority[acc] || 0), do: severity, else: acc
    end)
    
    avg_confidence = scans
    |> Enum.map(& &1.confidence_score || 0.0)
    |> Enum.sum()
    |> Kernel./(total_engines)
    
    %{
      engines_total: total_engines,
      engines_detected: detecting_engines,
      detection_ratio: detecting_engines / total_engines,
      threat_detected: detecting_engines > 0,
      threat_names: threats,
      severity_level: max_severity,
      confidence_score: Float.round(avg_confidence, 3)
    }
  end

  def generate_scan_report(scans) when is_list(scans) do
    aggregate = aggregate_multi_engine_results(scans)
    
    %{
      summary: aggregate,
      risk_level: calculate_risk_level(aggregate),
      recommendations: get_remediation_recommendations(aggregate),
      engine_details: Enum.map(scans, &extract_engine_summary/1),
      scan_timestamp: DateTime.utc_now()
    }
  end

  defp calculate_risk_level(%{detection_ratio: ratio, severity_level: severity}) do
    cond do
      ratio >= 0.7 and severity in ["critical", "high"] -> "critical"
      ratio >= 0.5 or severity == "high" -> "high"
      ratio >= 0.3 or severity == "medium" -> "medium"
      ratio > 0 or severity == "low" -> "low"
      true -> "clean"
    end
  end

  defp get_remediation_recommendations(%{detection_ratio: ratio, severity_level: severity}) do
    case calculate_risk_level(%{detection_ratio: ratio, severity_level: severity}) do
      "critical" -> ["immediate_quarantine", "security_review", "incident_report"]
      "high" -> ["quarantine", "manual_review", "notify_admin"]
      "medium" -> ["manual_review", "extended_monitoring"]
      "low" -> ["log_for_review", "continue_monitoring"]
      "clean" -> ["allow_download", "standard_monitoring"]
    end
  end

  defp extract_engine_summary(scan) do
    %{
      engine: scan.scan_engine,
      version: scan.scan_version,
      threat_detected: scan.threat_detected,
      threats: scan.threat_names,
      confidence: scan.confidence_score,
      scan_time: scan.scan_duration_ms
    }
  end
end