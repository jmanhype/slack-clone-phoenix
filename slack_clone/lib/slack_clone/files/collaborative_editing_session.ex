defmodule SlackClone.Files.CollaborativeEditingSession do
  @moduledoc """
  Schema for managing real-time collaborative editing sessions on shared files.
  
  Tracks active editing sessions, user participation, operational transforms,
  conflict resolution, and synchronization state for collaborative file editing.
  Supports multiple file types including documents, code, and structured data.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Jason.Encoder, except: [:__meta__]}

  schema "collaborative_editing_sessions" do
    field :session_token, :string
    field :file_type, :string
    field :editing_mode, :string, default: "concurrent"
    field :max_participants, :integer, default: 10
    field :current_participants, :integer, default: 0
    field :is_active, :boolean, default: true
    field :last_activity_at, :utc_datetime
    field :document_version, :integer, default: 1
    field :operational_transforms, {:array, :map}, default: []
    field :conflict_resolution_strategy, :string, default: "last_write_wins"
    field :auto_save_interval, :integer, default: 30
    field :session_timeout_minutes, :integer, default: 60
    field :cursor_positions, :map, default: %{}
    field :selection_ranges, :map, default: %{}
    field :user_colors, :map, default: %{}
    field :sync_state, :string, default: "synchronized"
    field :pending_operations, {:array, :map}, default: []
    field :last_checkpoint_at, :utc_datetime
    field :checkpoint_interval_seconds, :integer, default: 300
    field :bandwidth_optimization, :boolean, default: true
    field :compression_enabled, :boolean, default: true
    field :undo_stack_size, :integer, default: 100
    field :redo_stack_size, :integer, default: 100
    field :collaborative_features, :map, default: %{}
    field :permissions, :map, default: %{}
    field :access_level, :string, default: "read_write"
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :total_edits, :integer, default: 0
    field :total_conflicts, :integer, default: 0
    field :conflicts_resolved, :integer, default: 0
    field :data_transferred_bytes, :integer, default: 0
    field :peak_participants, :integer, default: 0
    field :average_response_time_ms, :integer, default: 0
    field :quality_metrics, :map, default: %{}
    field :session_notes, :string
    field :tags, {:array, :string}, default: []
    field :status, :string, default: "active"

    # Associations
    belongs_to :file_upload, SlackClone.Files.FileUpload
    belongs_to :workspace, SlackClone.Workspaces.Workspace
    belongs_to :channel, SlackClone.Channels.Channel
    belongs_to :created_by, SlackClone.Accounts.User
    belongs_to :current_editor, SlackClone.Accounts.User

    has_many :session_participants, SlackClone.Files.SessionParticipant
    has_many :operation_logs, SlackClone.Files.OperationLog
    has_many :conflict_logs, SlackClone.Files.ConflictLog

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new collaborative editing session.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :file_type, :editing_mode, :max_participants, :conflict_resolution_strategy,
      :auto_save_interval, :session_timeout_minutes, :bandwidth_optimization,
      :compression_enabled, :undo_stack_size, :redo_stack_size,
      :collaborative_features, :permissions, :access_level, :session_notes,
      :tags, :file_upload_id, :workspace_id, :channel_id, :created_by_id
    ])
    |> validate_required([
      :file_type, :editing_mode, :file_upload_id, :workspace_id, :created_by_id
    ])
    |> validate_inclusion(:editing_mode, ["concurrent", "sequential", "locked", "review"])
    |> validate_inclusion(:conflict_resolution_strategy, [
      "last_write_wins", "first_write_wins", "merge_changes", "manual_resolution",
      "operational_transform", "version_branching"
    ])
    |> validate_inclusion(:access_level, ["read_only", "comment_only", "read_write", "admin"])
    |> validate_inclusion(:sync_state, [
      "synchronized", "synchronizing", "conflict", "diverged", "error"
    ])
    |> validate_inclusion(:status, ["active", "paused", "completed", "cancelled", "error"])
    |> validate_number(:max_participants, greater_than: 0, less_than_or_equal_to: 50)
    |> validate_number(:auto_save_interval, greater_than: 5, less_than_or_equal_to: 300)
    |> validate_number(:session_timeout_minutes, greater_than: 5, less_than_or_equal_to: 480)
    |> validate_number(:undo_stack_size, greater_than: 10, less_than_or_equal_to: 1000)
    |> validate_number(:redo_stack_size, greater_than: 10, less_than_or_equal_to: 1000)
    |> validate_length(:tags, max: 10)
    |> validate_length(:session_notes, max: 2000)
    |> generate_session_token()
    |> set_timestamps()
    |> foreign_key_constraint(:file_upload_id)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:created_by_id)
    |> foreign_key_constraint(:current_editor_id)
    |> unique_constraint([:file_upload_id, :session_token])
  end

  @doc """
  Update changeset for modifying session state and configuration.
  """
  def update_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :current_participants, :is_active, :last_activity_at, :document_version,
      :operational_transforms, :cursor_positions, :selection_ranges, :sync_state,
      :pending_operations, :last_checkpoint_at, :current_editor_id, :total_edits,
      :total_conflicts, :conflicts_resolved, :data_transferred_bytes, 
      :peak_participants, :average_response_time_ms, :quality_metrics,
      :ended_at, :status, :session_notes
    ])
    |> validate_inclusion(:sync_state, [
      "synchronized", "synchronizing", "conflict", "diverged", "error"
    ])
    |> validate_inclusion(:status, ["active", "paused", "completed", "cancelled", "error"])
    |> validate_number(:current_participants, greater_than_or_equal_to: 0)
    |> validate_number(:document_version, greater_than: 0)
    |> validate_number(:total_edits, greater_than_or_equal_to: 0)
    |> validate_number(:total_conflicts, greater_than_or_equal_to: 0)
    |> validate_number(:conflicts_resolved, greater_than_or_equal_to: 0)
    |> validate_number(:data_transferred_bytes, greater_than_or_equal_to: 0)
    |> validate_number(:peak_participants, greater_than_or_equal_to: 0)
    |> validate_number(:average_response_time_ms, greater_than_or_equal_to: 0)
    |> update_activity_timestamp()
    |> check_session_limits()
  end

  # Private functions for changeset operations

  defp generate_session_token(changeset) do
    if get_change(changeset, :session_token) do
      changeset
    else
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      put_change(changeset, :session_token, token)
    end
  end

  defp set_timestamps(changeset) do
    now = DateTime.utc_now()
    changeset
    |> put_change(:started_at, now)
    |> put_change(:last_activity_at, now)
    |> put_change(:last_checkpoint_at, now)
  end

  defp update_activity_timestamp(changeset) do
    put_change(changeset, :last_activity_at, DateTime.utc_now())
  end

  defp check_session_limits(changeset) do
    current_participants = get_field(changeset, :current_participants, 0)
    max_participants = get_field(changeset, :max_participants, 10)

    if current_participants > max_participants do
      add_error(changeset, :current_participants, "exceeds maximum allowed participants")
    else
      changeset
    end
  end

  # Query functions

  @doc """
  Returns active collaborative editing sessions for a specific file.
  """
  def active_sessions_for_file(query \\ __MODULE__, file_id) do
    from s in query,
      where: s.file_upload_id == ^file_id and s.is_active == true and s.status == "active",
      order_by: [desc: s.last_activity_at]
  end

  @doc """
  Returns collaborative editing sessions for a workspace.
  """
  def sessions_for_workspace(query \\ __MODULE__, workspace_id) do
    from s in query,
      where: s.workspace_id == ^workspace_id,
      order_by: [desc: s.last_activity_at]
  end

  @doc """
  Returns sessions that have been inactive for longer than their timeout.
  """
  def expired_sessions(query \\ __MODULE__) do
    from s in query,
      where: s.is_active == true and s.status == "active",
      where: fragment("? + (? * interval '1 minute') < now()", 
        s.last_activity_at, s.session_timeout_minutes)
  end

  @doc """
  Returns sessions with conflicts that need resolution.
  """
  def sessions_with_conflicts(query \\ __MODULE__) do
    from s in query,
      where: s.sync_state in ["conflict", "diverged"] and s.is_active == true,
      order_by: [desc: s.total_conflicts]
  end

  @doc """
  Returns sessions by editing mode.
  """
  def sessions_by_mode(query \\ __MODULE__, editing_mode) do
    from s in query,
      where: s.editing_mode == ^editing_mode
  end

  # Business logic functions

  @doc """
  Adds an operational transform to the session's transform log.
  """
  def add_operational_transform(session, operation) do
    current_transforms = session.operational_transforms || []
    new_transforms = [operation | current_transforms]
    
    # Keep only the most recent 1000 operations to prevent unlimited growth
    trimmed_transforms = Enum.take(new_transforms, 1000)
    
    %{session | operational_transforms: trimmed_transforms}
  end

  @doc """
  Updates cursor position for a user in the collaborative session.
  """
  def update_cursor_position(session, user_id, cursor_data) do
    current_positions = session.cursor_positions || %{}
    updated_positions = Map.put(current_positions, to_string(user_id), cursor_data)
    
    %{session | cursor_positions: updated_positions}
  end

  @doc """
  Updates selection range for a user in the collaborative session.
  """
  def update_selection_range(session, user_id, selection_data) do
    current_ranges = session.selection_ranges || %{}
    updated_ranges = Map.put(current_ranges, to_string(user_id), selection_data)
    
    %{session | selection_ranges: updated_ranges}
  end

  @doc """
  Assigns a color to a user for visual identification in the editor.
  """
  def assign_user_color(session, user_id) do
    current_colors = session.user_colors || %{}
    
    if Map.has_key?(current_colors, to_string(user_id)) do
      session
    else
      # Predefined set of colors for users
      available_colors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", 
        "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9"
      ]
      
      used_colors = Map.values(current_colors)
      available = available_colors -- used_colors
      
      new_color = if Enum.empty?(available) do
        Enum.random(available_colors)
      else
        Enum.random(available)
      end
      
      updated_colors = Map.put(current_colors, to_string(user_id), new_color)
      %{session | user_colors: updated_colors}
    end
  end

  @doc """
  Calculates session quality metrics based on performance and collaboration data.
  """
  def calculate_quality_metrics(session) do
    conflict_rate = if session.total_edits > 0 do
      (session.total_conflicts / session.total_edits) * 100
    else
      0.0
    end
    
    resolution_rate = if session.total_conflicts > 0 do
      (session.conflicts_resolved / session.total_conflicts) * 100
    else
      100.0
    end
    
    efficiency_score = case session.average_response_time_ms do
      ms when ms < 100 -> 100
      ms when ms < 500 -> 85
      ms when ms < 1000 -> 70
      ms when ms < 2000 -> 50
      _ -> 25
    end
    
    collaboration_score = case session.peak_participants do
      1 -> 25
      participants when participants <= 3 -> 50
      participants when participants <= 6 -> 75
      participants when participants <= 10 -> 90
      _ -> 95
    end
    
    %{
      conflict_rate: Float.round(conflict_rate, 2),
      resolution_rate: Float.round(resolution_rate, 2),
      efficiency_score: efficiency_score,
      collaboration_score: collaboration_score,
      overall_quality: Float.round((resolution_rate + efficiency_score + collaboration_score) / 3, 2)
    }
  end

  @doc """
  Determines if a session should be automatically saved based on activity.
  """
  def should_auto_save?(session) do
    if session.last_checkpoint_at do
      seconds_since_checkpoint = DateTime.diff(DateTime.utc_now(), session.last_checkpoint_at)
      seconds_since_checkpoint >= session.checkpoint_interval_seconds
    else
      true
    end
  end

  @doc """
  Gets recommended conflict resolution strategy based on session characteristics.
  """
  def recommend_resolution_strategy(session) do
    cond do
      session.current_participants <= 2 ->
        "manual_resolution"
      session.file_type in ["code", "config", "data"] ->
        "operational_transform"
      session.conflict_rate > 20 ->
        "version_branching"
      true ->
        "last_write_wins"
    end
  end

  @doc """
  Checks if a user can join the collaborative editing session.
  """
  def can_user_join?(session, user_id) do
    cond do
      not session.is_active or session.status != "active" ->
        {:error, :session_inactive}
      session.current_participants >= session.max_participants ->
        {:error, :session_full}
      session.access_level == "read_only" ->
        {:error, :read_only_session}
      Map.get(session.permissions, to_string(user_id), "none") == "blocked" ->
        {:error, :user_blocked}
      true ->
        :ok
    end
  end

  @doc """
  Estimates bandwidth requirements for a collaborative editing session.
  """
  def estimate_bandwidth_requirements(session) do
    base_bandwidth = case session.file_type do
      "text" -> 5  # KB/s per user
      "code" -> 10
      "document" -> 15
      "presentation" -> 25
      "spreadsheet" -> 20
      _ -> 10
    end
    
    participant_multiplier = session.current_participants || 1
    compression_factor = if session.compression_enabled, do: 0.6, else: 1.0
    optimization_factor = if session.bandwidth_optimization, do: 0.8, else: 1.0
    
    estimated_kb_per_second = base_bandwidth * participant_multiplier * compression_factor * optimization_factor
    
    %{
      estimated_bandwidth_kbps: Float.round(estimated_kb_per_second, 1),
      recommended_connection: cond do
        estimated_kb_per_second < 50 -> "broadband"
        estimated_kb_per_second < 200 -> "high_speed"
        true -> "enterprise"
      end,
      optimization_enabled: session.bandwidth_optimization,
      compression_enabled: session.compression_enabled
    }
  end
end