defmodule SlackClone.Files.ShareableLink do
  @moduledoc """
  Schema for managing secure, temporary shareable links for file downloads.
  Provides granular access control with expiration and usage tracking.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shareable_links" do
    belongs_to :file_upload, SlackClone.Files.FileUpload
    belongs_to :created_by, SlackClone.Accounts.User
    belongs_to :workspace, SlackClone.Accounts.Workspace

    # Link configuration
    field :token, :string # Unique access token
    field :short_code, :string # Human-readable short code (e.g., "abc123")
    field :url_path, :string # Full URL path
    field :is_active, :boolean, default: true
    field :is_public, :boolean, default: false # Public links don't require authentication
    
    # Access control
    field :requires_authentication, :boolean, default: true
    field :requires_workspace_membership, :boolean, default: true
    field :password_protected, :boolean, default: false
    field :password_hash, :string
    field :password_hint, :string
    
    # Permissions
    field :can_download, :boolean, default: true
    field :can_preview, :boolean, default: true
    field :can_share, :boolean, default: false # Can others create new links from this link
    field :can_comment, :boolean, default: false
    field :watermark_enabled, :boolean, default: false
    
    # Expiration settings
    field :expires_at, :utc_datetime
    field :max_downloads, :integer # nil = unlimited
    field :max_unique_users, :integer # nil = unlimited
    field :valid_from, :utc_datetime
    field :auto_expire_after_download, :boolean, default: false
    
    # Usage tracking
    field :download_count, :integer, default: 0
    field :view_count, :integer, default: 0
    field :unique_users_count, :integer, default: 0
    field :last_accessed_at, :utc_datetime
    field :first_accessed_at, :utc_datetime
    
    # Geographic restrictions
    field :allowed_countries, {:array, :string} # ISO country codes
    field :blocked_countries, {:array, :string}
    field :ip_whitelist, {:array, :string}
    field :ip_blacklist, {:array, :string}
    
    # Time-based restrictions
    field :allowed_hours_start, :integer # 0-23, hour of day
    field :allowed_hours_end, :integer # 0-23, hour of day
    field :allowed_days, {:array, :integer} # 1-7, days of week (Monday=1)
    field :timezone, :string, default: "UTC"
    
    # Security settings
    field :require_user_agent, :boolean, default: false
    field :allowed_user_agents, {:array, :string}
    field :require_referrer, :boolean, default: false
    field :allowed_referrers, {:array, :string}
    field :rate_limit_per_hour, :integer # Downloads per hour per IP
    field :rate_limit_per_day, :integer # Downloads per day per IP
    
    # Audit and compliance
    field :purpose, :string # sharing_reason: "client_review", "external_collaboration", etc.
    field :internal_notes, :string
    field :compliance_tags, {:array, :string}
    field :data_classification, :string # public, internal, confidential, restricted
    field :requires_audit_log, :boolean, default: false
    
    # Notification settings
    field :notify_on_access, :boolean, default: false
    field :notify_on_download, :boolean, default: false
    field :notify_on_expiry, :boolean, default: false
    field :notification_emails, {:array, :string}
    field :webhook_url, :string
    
    # Analytics
    field :conversion_tracking_id, :string
    field :campaign_source, :string
    field :campaign_medium, :string
    field :campaign_name, :string
    field :utm_parameters, :map
    
    # Custom metadata
    field :custom_title, :string
    field :custom_description, :string
    field :custom_metadata, :map, default: %{}
    field :branding_options, :map, default: %{}
    
    # Status tracking
    field :status, :string, default: "active" # active, expired, disabled, revoked, suspended
    field :revoked_at, :utc_datetime
    field :revoked_by_id, :binary_id
    field :revoke_reason, :string
    field :suspension_reason, :string
    
    # Performance optimization
    field :cache_duration_seconds, :integer, default: 3600
    field :cdn_enabled, :boolean, default: false
    field :compression_enabled, :boolean, default: true
    field :streaming_enabled, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [
      :file_upload_id, :created_by_id, :workspace_id, :token, :short_code, :url_path,
      :is_active, :is_public, :requires_authentication, :requires_workspace_membership,
      :password_protected, :password_hash, :password_hint, :can_download, :can_preview,
      :can_share, :can_comment, :watermark_enabled, :expires_at, :max_downloads,
      :max_unique_users, :valid_from, :auto_expire_after_download, :download_count,
      :view_count, :unique_users_count, :last_accessed_at, :first_accessed_at,
      :allowed_countries, :blocked_countries, :ip_whitelist, :ip_blacklist,
      :allowed_hours_start, :allowed_hours_end, :allowed_days, :timezone,
      :require_user_agent, :allowed_user_agents, :require_referrer, :allowed_referrers,
      :rate_limit_per_hour, :rate_limit_per_day, :purpose, :internal_notes,
      :compliance_tags, :data_classification, :requires_audit_log, :notify_on_access,
      :notify_on_download, :notify_on_expiry, :notification_emails, :webhook_url,
      :conversion_tracking_id, :campaign_source, :campaign_medium, :campaign_name,
      :utm_parameters, :custom_title, :custom_description, :custom_metadata,
      :branding_options, :status, :revoked_at, :revoked_by_id, :revoke_reason,
      :suspension_reason, :cache_duration_seconds, :cdn_enabled, :compression_enabled,
      :streaming_enabled
    ])
    |> validate_required([:file_upload_id, :created_by_id, :token])
    |> validate_inclusion(:status, ["active", "expired", "disabled", "revoked", "suspended"])
    |> validate_inclusion(:data_classification, ["public", "internal", "confidential", "restricted", nil])
    |> validate_number(:allowed_hours_start, greater_than_or_equal_to: 0, less_than_or_equal_to: 23)
    |> validate_number(:allowed_hours_end, greater_than_or_equal_to: 0, less_than_or_equal_to: 23)
    |> validate_number(:max_downloads, greater_than: 0)
    |> validate_number(:max_unique_users, greater_than: 0)
    |> validate_number(:rate_limit_per_hour, greater_than: 0)
    |> validate_number(:rate_limit_per_day, greater_than: 0)
    |> validate_number(:cache_duration_seconds, greater_than_or_equal_to: 0)
    |> unique_constraint(:token)
    |> unique_constraint(:short_code)
    |> validate_expiration_logic()
    |> put_url_path()
  end

  defp validate_expiration_logic(changeset) do
    expires_at = get_field(changeset, :expires_at)
    valid_from = get_field(changeset, :valid_from)
    
    if expires_at && valid_from && DateTime.compare(expires_at, valid_from) != :gt do
      add_error(changeset, :expires_at, "must be after valid_from date")
    else
      changeset
    end
  end

  defp put_url_path(changeset) do
    if get_field(changeset, :url_path) do
      changeset
    else
      token = get_field(changeset, :token)
      short_code = get_field(changeset, :short_code)
      
      path = if short_code do
        "/share/#{short_code}"
      else
        "/s/#{token}"
      end
      
      put_change(changeset, :url_path, path)
    end
  end

  def create_changeset(file_upload_id, created_by_id, opts \\ []) do
    now = DateTime.utc_now()
    token = generate_secure_token()
    short_code = if Keyword.get(opts, :generate_short_code, false), do: generate_short_code(), else: nil
    
    default_expires = DateTime.add(now, Keyword.get(opts, :expires_in_hours, 24) * 3600, :second)
    
    attrs = %{
      file_upload_id: file_upload_id,
      created_by_id: created_by_id,
      workspace_id: Keyword.get(opts, :workspace_id),
      token: token,
      short_code: short_code,
      expires_at: Keyword.get(opts, :expires_at, default_expires),
      valid_from: Keyword.get(opts, :valid_from, now),
      is_public: Keyword.get(opts, :is_public, false),
      requires_authentication: Keyword.get(opts, :requires_authentication, true),
      max_downloads: Keyword.get(opts, :max_downloads),
      max_unique_users: Keyword.get(opts, :max_unique_users),
      purpose: Keyword.get(opts, :purpose),
      data_classification: Keyword.get(opts, :data_classification, "internal")
    }
    
    %__MODULE__{}
    |> changeset(attrs)
  end

  def set_password_changeset(link, password) do
    password_hash = hash_password(password)
    
    link
    |> change(%{
      password_protected: true,
      password_hash: password_hash
    })
  end

  def track_access_changeset(link, access_info \\ %{}) do
    now = DateTime.utc_now()
    
    changes = %{
      view_count: link.view_count + 1,
      last_accessed_at: now
    }
    
    changes = if is_nil(link.first_accessed_at) do
      Map.put(changes, :first_accessed_at, now)
    else
      changes
    end
    
    # Track unique users if we have user info
    changes = if access_info[:user_id] do
      # This would need to check if user_id is new
      changes
    else
      changes
    end
    
    link
    |> change(changes)
  end

  def track_download_changeset(link) do
    changes = %{
      download_count: link.download_count + 1,
      last_accessed_at: DateTime.utc_now()
    }
    
    # Auto-expire after download if configured
    changes = if link.auto_expire_after_download do
      Map.merge(changes, %{
        status: "expired",
        is_active: false
      })
    else
      changes
    end
    
    link
    |> change(changes)
  end

  def revoke_changeset(link, revoked_by_id, reason) do
    link
    |> change(%{
      status: "revoked",
      is_active: false,
      revoked_at: DateTime.utc_now(),
      revoked_by_id: revoked_by_id,
      revoke_reason: reason
    })
  end

  def extend_expiration_changeset(link, new_expires_at) do
    if DateTime.compare(new_expires_at, DateTime.utc_now()) == :gt do
      link
      |> change(%{
        expires_at: new_expires_at,
        status: "active",
        is_active: true
      })
    else
      link
      |> add_error(:expires_at, "cannot extend to a past date")
    end
  end

  # Query functions
  def for_file_query(file_upload_id) do
    from l in __MODULE__,
      where: l.file_upload_id == ^file_upload_id,
      order_by: [desc: :inserted_at]
  end

  def active_links_query do
    now = DateTime.utc_now()
    
    from l in __MODULE__,
      where: l.is_active == true,
      where: l.status == "active",
      where: l.expires_at > ^now,
      where: is_nil(l.valid_from) or l.valid_from <= ^now
  end

  def expired_links_query do
    now = DateTime.utc_now()
    
    from l in __MODULE__,
      where: l.expires_at <= ^now and l.status != "expired",
      order_by: [asc: :expires_at]
  end

  def expiring_soon_query(hours_ahead \\ 24) do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, hours_ahead * 3600, :second)
    
    from l in __MODULE__,
      where: l.is_active == true,
      where: l.status == "active",
      where: l.expires_at > ^now,
      where: l.expires_at <= ^cutoff,
      where: l.notify_on_expiry == true,
      order_by: [asc: :expires_at]
  end

  def by_token_query(token) do
    from l in __MODULE__,
      where: l.token == ^token,
      where: l.is_active == true,
      where: l.status == "active"
  end

  def by_short_code_query(short_code) do
    from l in __MODULE__,
      where: l.short_code == ^short_code,
      where: l.is_active == true,
      where: l.status == "active"
  end

  def usage_stats_query(days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from l in __MODULE__,
      where: l.inserted_at >= ^cutoff,
      select: %{
        total_links: count(l.id),
        active_links: sum(fragment("CASE WHEN ? AND ? = 'active' THEN 1 ELSE 0 END", l.is_active, l.status)),
        expired_links: sum(fragment("CASE WHEN ? <= ? THEN 1 ELSE 0 END", l.expires_at, ^DateTime.utc_now())),
        password_protected: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", l.password_protected)),
        public_links: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", l.is_public)),
        total_downloads: sum(l.download_count),
        total_views: sum(l.view_count),
        avg_downloads_per_link: avg(l.download_count)
      }
  end

  def popular_links_query(days_back \\ 7, limit \\ 10) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from l in __MODULE__,
      where: l.last_accessed_at >= ^cutoff,
      order_by: [desc: l.download_count, desc: l.view_count],
      limit: ^limit
  end

  def security_violations_query do
    from l in __MODULE__,
      where: l.status == "suspended" or 
             not is_nil(l.suspension_reason) or
             fragment("array_length(?, 1) > 0", l.ip_blacklist),
      order_by: [desc: :updated_at]
  end

  def compliance_report_query(classification) do
    from l in __MODULE__,
      where: l.data_classification == ^classification,
      where: l.requires_audit_log == true,
      select: %{
        link_id: l.id,
        file_upload_id: l.file_upload_id,
        created_by_id: l.created_by_id,
        purpose: l.purpose,
        download_count: l.download_count,
        last_accessed_at: l.last_accessed_at,
        expires_at: l.expires_at,
        compliance_tags: l.compliance_tags
      },
      order_by: [desc: :inserted_at]
  end

  # Helper functions
  defp generate_secure_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp generate_short_code do
    # Generate human-readable 6-character code
    chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    for _ <- 1..6, into: "", do: <<Enum.random(String.graphemes(chars))>>
  end

  defp hash_password(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  def verify_password(link, password) do
    if link.password_protected && link.password_hash do
      Bcrypt.verify_pass(password, link.password_hash)
    else
      false
    end
  end

  def is_accessible?(link, access_context \\ %{}) do
    now = DateTime.utc_now()
    
    cond do
      # Check basic status
      not link.is_active or link.status != "active" ->
        {:error, :inactive}
      
      # Check expiration
      link.expires_at && DateTime.compare(link.expires_at, now) != :gt ->
        {:error, :expired}
      
      # Check valid from
      link.valid_from && DateTime.compare(now, link.valid_from) == :lt ->
        {:error, :not_yet_valid}
      
      # Check download limits
      link.max_downloads && link.download_count >= link.max_downloads ->
        {:error, :download_limit_exceeded}
      
      # Check time restrictions
      not is_time_allowed?(link, now) ->
        {:error, :time_restricted}
      
      # Check geographic restrictions
      not is_location_allowed?(link, access_context[:country_code]) ->
        {:error, :geographic_restriction}
      
      # Check IP restrictions
      not is_ip_allowed?(link, access_context[:ip_address]) ->
        {:error, :ip_restricted}
      
      true ->
        :ok
    end
  end

  defp is_time_allowed?(link, datetime) do
    # Check allowed hours
    hour_allowed = if link.allowed_hours_start && link.allowed_hours_end do
      user_datetime = DateTime.shift_zone!(datetime, link.timezone || "UTC")
      hour = user_datetime.hour
      
      # Handle overnight ranges (e.g., 22-6)
      if link.allowed_hours_start <= link.allowed_hours_end do
        hour >= link.allowed_hours_start && hour <= link.allowed_hours_end
      else
        hour >= link.allowed_hours_start || hour <= link.allowed_hours_end
      end
    else
      true
    end
    
    # Check allowed days
    day_allowed = if link.allowed_days && length(link.allowed_days) > 0 do
      user_date = DateTime.to_date(datetime)
      weekday = Date.day_of_week(user_date)
      weekday in link.allowed_days
    else
      true
    end
    
    hour_allowed && day_allowed
  end

  defp is_location_allowed?(link, country_code) do
    cond do
      # If no country code provided, assume allowed
      is_nil(country_code) -> true
      # If blocked countries list exists and country is in it
      link.blocked_countries && country_code in link.blocked_countries -> false
      # If allowed countries list exists and country is not in it
      link.allowed_countries && length(link.allowed_countries) > 0 && country_code not in link.allowed_countries -> false
      # Otherwise allowed
      true -> true
    end
  end

  defp is_ip_allowed?(link, ip_address) do
    cond do
      # If no IP provided, assume allowed
      is_nil(ip_address) -> true
      # If IP is blacklisted
      link.ip_blacklist && ip_address in link.ip_blacklist -> false
      # If whitelist exists and IP is not in it
      link.ip_whitelist && length(link.ip_whitelist) > 0 && ip_address not in link.ip_whitelist -> false
      # Otherwise allowed
      true -> true
    end
  end

  def get_access_url(link, base_url \\ nil) do
    base = base_url || "https://app.example.com"
    "#{base}#{link.url_path}"
  end

  def calculate_usage_metrics(link) do
    now = DateTime.utc_now()
    
    # Calculate conversion rate
    conversion_rate = if link.view_count > 0 do
      (link.download_count / link.view_count) * 100
    else
      0.0
    end
    
    # Calculate time until expiration
    expires_in_hours = if link.expires_at do
      DateTime.diff(link.expires_at, now, :hour)
    else
      nil
    end
    
    # Calculate usage efficiency
    usage_efficiency = cond do
      link.max_downloads && link.max_downloads > 0 ->
        (link.download_count / link.max_downloads) * 100
      true -> nil
    end
    
    %{
      conversion_rate: Float.round(conversion_rate, 2),
      expires_in_hours: expires_in_hours,
      usage_efficiency: usage_efficiency && Float.round(usage_efficiency, 2),
      is_expired: link.expires_at && DateTime.compare(link.expires_at, now) != :gt,
      days_active: DateTime.diff(now, link.inserted_at, :day),
      avg_downloads_per_day: if link.download_count > 0 do
        days = max(DateTime.diff(now, link.inserted_at, :day), 1)
        Float.round(link.download_count / days, 2)
      else
        0.0
      end
    }
  end

  def generate_qr_code_data(link) do
    access_url = get_access_url(link)
    %{
      url: access_url,
      title: link.custom_title || "Shared File",
      description: link.custom_description,
      qr_data: access_url
    }
  end
end