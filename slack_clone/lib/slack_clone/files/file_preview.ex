defmodule SlackClone.Files.FilePreview do
  @moduledoc """
  Schema for storing file preview data including thumbnails, extracted content, and metadata.
  Supports various file types with optimized preview generation.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "file_previews" do
    belongs_to :file_upload, SlackClone.Files.FileUpload

    # Preview content
    field :preview_type, :string # thumbnail, text_extract, code_highlight, pdf_pages, video_frame
    field :content_type, :string # image/jpeg, text/plain, application/json
    field :file_size, :integer
    field :file_path, :string # Storage path for preview file
    field :external_url, :string # CDN/S3 URL if stored externally
    
    # Preview dimensions (for images/videos)
    field :width, :integer
    field :height, :integer
    field :aspect_ratio, :float
    field :duration_seconds, :integer # For video/audio previews
    
    # Text extraction results
    field :extracted_text, :string
    field :text_language, :string
    field :text_encoding, :string
    field :word_count, :integer
    field :character_count, :integer
    
    # Code file analysis
    field :programming_language, :string
    field :line_count, :integer
    field :syntax_highlighted_html, :string
    field :function_definitions, {:array, :string}
    field :import_statements, {:array, :string}
    
    # Document analysis
    field :page_count, :integer
    field :document_title, :string
    field :document_author, :string
    field :document_metadata, :map
    field :table_of_contents, {:array, :map}
    
    # Media analysis
    field :media_format, :string # MP4, AVI, MP3, etc.
    field :bitrate, :integer
    field :frame_rate, :float
    field :audio_channels, :integer
    field :video_codec, :string
    field :audio_codec, :string
    field :has_audio, :boolean
    field :has_video, :boolean
    
    # Image analysis
    field :color_palette, {:array, :string} # Dominant colors as hex codes
    field :has_transparency, :boolean
    field :image_format, :string # JPEG, PNG, GIF, etc.
    field :compression_quality, :integer
    field :exif_data, :map
    field :faces_detected, :integer
    field :objects_detected, {:array, :string}
    
    # Generation status
    field :status, :string # pending, processing, completed, failed, retrying
    field :generation_started_at, :utc_datetime
    field :generation_completed_at, :utc_datetime
    field :generation_duration_ms, :integer
    field :generation_attempts, :integer, default: 1
    field :max_attempts, :integer, default: 3
    
    # Error handling
    field :error_message, :string
    field :error_code, :string
    field :error_details, :map
    field :retry_after, :utc_datetime
    
    # Processing configuration
    field :quality_setting, :string # low, medium, high, original
    field :optimization_level, :string # speed, balanced, quality
    field :processing_priority, :string # low, normal, high, urgent
    field :custom_settings, :map
    
    # Usage and access
    field :access_count, :integer, default: 0
    field :last_accessed_at, :utc_datetime
    field :cache_until, :utc_datetime
    field :is_cached, :boolean, default: false
    field :cache_key, :string
    
    # Security and content analysis
    field :content_hash, :string
    field :is_safe_content, :boolean, default: true
    field :content_warnings, {:array, :string}
    field :adult_content_score, :float, default: 0.0
    field :violence_score, :float, default: 0.0
    field :text_toxicity_score, :float, default: 0.0
    
    # Performance metrics
    field :generation_cpu_time_ms, :integer
    field :memory_peak_mb, :integer
    field :storage_cost_estimate, :float
    field :bandwidth_usage_bytes, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(preview, attrs) do
    preview
    |> cast(attrs, [
      :file_upload_id, :preview_type, :content_type, :file_size, :file_path,
      :external_url, :width, :height, :aspect_ratio, :duration_seconds,
      :extracted_text, :text_language, :text_encoding, :word_count,
      :character_count, :programming_language, :line_count, :syntax_highlighted_html,
      :function_definitions, :import_statements, :page_count, :document_title,
      :document_author, :document_metadata, :table_of_contents, :media_format,
      :bitrate, :frame_rate, :audio_channels, :video_codec, :audio_codec,
      :has_audio, :has_video, :color_palette, :has_transparency, :image_format,
      :compression_quality, :exif_data, :faces_detected, :objects_detected,
      :status, :generation_started_at, :generation_completed_at, :generation_duration_ms,
      :generation_attempts, :max_attempts, :error_message, :error_code,
      :error_details, :retry_after, :quality_setting, :optimization_level,
      :processing_priority, :custom_settings, :access_count, :last_accessed_at,
      :cache_until, :is_cached, :cache_key, :content_hash, :is_safe_content,
      :content_warnings, :adult_content_score, :violence_score, :text_toxicity_score,
      :generation_cpu_time_ms, :memory_peak_mb, :storage_cost_estimate, :bandwidth_usage_bytes
    ])
    |> validate_required([:file_upload_id, :preview_type, :status])
    |> validate_inclusion(:preview_type, ["thumbnail", "text_extract", "code_highlight", "pdf_pages", "video_frame", "audio_waveform"])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "failed", "retrying", "cancelled"])
    |> validate_inclusion(:quality_setting, ["low", "medium", "high", "original"])
    |> validate_inclusion(:optimization_level, ["speed", "balanced", "quality"])
    |> validate_inclusion(:processing_priority, ["low", "normal", "high", "urgent"])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:file_size, greater_than_or_equal_to: 0)
    |> validate_number(:generation_attempts, greater_than_or_equal_to: 1)
    |> validate_number(:max_attempts, greater_than_or_equal_to: 1)
    |> validate_number(:adult_content_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:violence_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:text_toxicity_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:file_upload_id, :preview_type])
    |> put_aspect_ratio()
    |> put_cache_key()
  end

  defp put_aspect_ratio(changeset) do
    width = get_field(changeset, :width)
    height = get_field(changeset, :height)
    
    if width && height && height > 0 do
      put_change(changeset, :aspect_ratio, width / height)
    else
      changeset
    end
  end

  defp put_cache_key(changeset) do
    if get_field(changeset, :cache_key) do
      changeset
    else
      file_upload_id = get_field(changeset, :file_upload_id)
      preview_type = get_field(changeset, :preview_type)
      
      if file_upload_id && preview_type do
        cache_key = "preview:#{file_upload_id}:#{preview_type}:#{System.system_time(:millisecond)}"
        put_change(changeset, :cache_key, cache_key)
      else
        changeset
      end
    end
  end

  def start_generation_changeset(preview) do
    preview
    |> change(%{
      status: "processing",
      generation_started_at: DateTime.utc_now(),
      generation_attempts: preview.generation_attempts + 1
    })
  end

  def complete_generation_changeset(preview, results) do
    now = DateTime.utc_now()
    duration = if preview.generation_started_at do
      DateTime.diff(now, preview.generation_started_at, :millisecond)
    else
      0
    end
    
    changes = %{
      status: "completed",
      generation_completed_at: now,
      generation_duration_ms: duration,
      cache_until: DateTime.add(now, 24 * 3600, :second) # Cache for 24 hours
    }
    
    preview
    |> change(Map.merge(changes, results))
  end

  def fail_generation_changeset(preview, error_info) do
    should_retry = preview.generation_attempts < preview.max_attempts
    
    changes = %{
      status: if(should_retry, do: "failed", else: "retrying"),
      error_message: error_info[:message],
      error_code: error_info[:code],
      error_details: error_info[:details] || %{}
    }
    
    changes = if should_retry do
      Map.put(changes, :retry_after, DateTime.add(DateTime.utc_now(), 300, :second)) # Retry in 5 minutes
    else
      changes
    end
    
    preview
    |> change(changes)
  end

  # Query functions
  def for_file_query(file_upload_id) do
    from p in __MODULE__,
      where: p.file_upload_id == ^file_upload_id,
      order_by: [asc: :preview_type]
  end

  def by_status_query(status) do
    from p in __MODULE__,
      where: p.status == ^status,
      order_by: [asc: :generation_started_at]
  end

  def pending_generation_query(limit \\ 10) do
    from p in __MODULE__,
      where: p.status in ["pending", "retrying"],
      where: is_nil(p.retry_after) or p.retry_after <= ^DateTime.utc_now(),
      order_by: [
        asc: fragment("CASE ? WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END", p.processing_priority),
        asc: :inserted_at
      ],
      limit: ^limit
  end

  def failed_previews_query(days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from p in __MODULE__,
      where: p.status == "failed",
      where: p.generation_attempts >= p.max_attempts,
      where: p.updated_at >= ^cutoff,
      order_by: [desc: :updated_at]
  end

  def cache_expired_query do
    now = DateTime.utc_now()
    
    from p in __MODULE__,
      where: p.is_cached == true,
      where: p.cache_until <= ^now,
      order_by: [asc: :cache_until]
  end

  def popular_previews_query(days_back \\ 30, limit \\ 20) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from p in __MODULE__,
      where: p.last_accessed_at >= ^cutoff,
      where: p.access_count > 0,
      order_by: [desc: :access_count],
      limit: ^limit
  end

  def content_analysis_query(unsafe_threshold \\ 0.7) do
    from p in __MODULE__,
      where: p.is_safe_content == false or
             p.adult_content_score >= ^unsafe_threshold or
             p.violence_score >= ^unsafe_threshold or
             p.text_toxicity_score >= ^unsafe_threshold,
      order_by: [desc: :adult_content_score]
  end

  def performance_stats_query(days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from p in __MODULE__,
      where: p.generation_completed_at >= ^cutoff,
      where: p.status == "completed",
      group_by: p.preview_type,
      select: %{
        preview_type: p.preview_type,
        total_generated: count(p.id),
        avg_generation_time: avg(p.generation_duration_ms),
        avg_file_size: avg(p.file_size),
        success_rate: fragment("ROUND(COUNT(CASE WHEN ? = 'completed' THEN 1 END) * 100.0 / COUNT(*), 2)", p.status),
        total_cpu_time: sum(p.generation_cpu_time_ms),
        avg_memory_usage: avg(p.memory_peak_mb)
      }
  end

  # Helper functions
  def update_access_stats(preview) do
    preview
    |> change(%{
      access_count: preview.access_count + 1,
      last_accessed_at: DateTime.utc_now()
    })
  end

  def is_generation_needed?(file_upload, preview_type) do
    # Check if preview already exists and is valid
    case SlackClone.Repo.get_by(__MODULE__, file_upload_id: file_upload.id, preview_type: preview_type) do
      nil -> true
      %{status: "failed", generation_attempts: attempts, max_attempts: max} when attempts >= max -> false
      %{status: "completed", cache_until: cache_until} -> 
        DateTime.compare(DateTime.utc_now(), cache_until) == :gt
      _ -> false
    end
  end

  def get_supported_preview_types(content_type) do
    case content_type do
      "image/" <> _ -> ["thumbnail"]
      "video/" <> _ -> ["thumbnail", "video_frame"]
      "audio/" <> _ -> ["audio_waveform"]
      "text/" <> _ -> ["text_extract"]
      "application/pdf" -> ["thumbnail", "text_extract", "pdf_pages"]
      "application/json" -> ["code_highlight", "text_extract"]
      type when type in ["application/javascript", "application/typescript"] -> 
        ["code_highlight", "text_extract"]
      _ -> ["text_extract"]
    end
  end

  def estimate_generation_time(content_type, file_size) do
    base_time = case content_type do
      "image/" <> _ -> 2_000  # 2 seconds
      "video/" <> _ -> file_size / 1_000_000 * 10_000  # 10s per MB
      "audio/" <> _ -> file_size / 1_000_000 * 5_000   # 5s per MB
      "application/pdf" -> file_size / 1_000_000 * 15_000  # 15s per MB
      _ -> 1_000  # 1 second default
    end
    
    round(base_time)
  end

  def calculate_storage_cost(file_size, retention_days \\ 30) do
    # Example calculation: $0.023 per GB per month
    gb_size = file_size / (1024 * 1024 * 1024)
    monthly_cost = gb_size * 0.023
    (monthly_cost / 30) * retention_days
  end

  def get_content_safety_summary(preview) do
    max_score = Enum.max([
      preview.adult_content_score || 0.0,
      preview.violence_score || 0.0,
      preview.text_toxicity_score || 0.0
    ])
    
    cond do
      max_score >= 0.9 -> %{level: "high_risk", message: "Content contains high-risk material"}
      max_score >= 0.7 -> %{level: "medium_risk", message: "Content may contain inappropriate material"}
      max_score >= 0.3 -> %{level: "low_risk", message: "Content appears mostly safe with minor concerns"}
      true -> %{level: "safe", message: "Content appears safe for all audiences"}
    end
  end
end