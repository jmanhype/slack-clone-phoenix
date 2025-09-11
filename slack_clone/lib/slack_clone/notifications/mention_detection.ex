defmodule SlackClone.Notifications.MentionDetection do
  @moduledoc """
  Schema for tracking mention detection and processing.
  Stores detected mentions with context and notification triggers.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mention_detections" do
    # Source message information
    belongs_to :message, SlackClone.Chat.Message
    belongs_to :channel, SlackClone.Chat.Channel
    belongs_to :mentioned_by, SlackClone.Accounts.User

    # Mention details
    belongs_to :mentioned_user, SlackClone.Accounts.User
    field :mention_type, :string # user, channel, everyone, here, keyword
    field :mention_text, :string # The actual text that triggered the mention
    field :mention_context, :string # Surrounding text for context
    field :mention_position, :integer # Character position in message
    
    # Detection metadata
    field :detection_method, :string # regex, keyword, special
    field :detection_confidence, :float, default: 1.0
    field :processed_at, :utc_datetime
    
    # Notification tracking
    field :notification_sent, :boolean, default: false
    field :notification_sent_at, :utc_datetime
    field :notification_method, {:array, :string}, default: []
    field :notification_read, :boolean, default: false
    field :notification_read_at, :utc_datetime
    
    # User response tracking
    field :user_responded, :boolean, default: false
    field :user_response_time, :integer # seconds between mention and response
    field :response_message_id, :binary_id
    
    # Mention relevance and filtering
    field :is_relevant, :boolean, default: true
    field :spam_score, :float, default: 0.0
    field :false_positive, :boolean, default: false
    field :user_dismissed, :boolean, default: false
    field :dismissed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(mention_detection, attrs) do
    mention_detection
    |> cast(attrs, [
      :message_id, :channel_id, :mentioned_by_id, :mentioned_user_id,
      :mention_type, :mention_text, :mention_context, :mention_position,
      :detection_method, :detection_confidence, :processed_at,
      :notification_sent, :notification_sent_at, :notification_method,
      :notification_read, :notification_read_at, :user_responded,
      :user_response_time, :response_message_id, :is_relevant,
      :spam_score, :false_positive, :user_dismissed, :dismissed_at
    ])
    |> validate_required([
      :message_id, :channel_id, :mentioned_by_id, :mentioned_user_id,
      :mention_type, :mention_text
    ])
    |> validate_inclusion(:mention_type, ["user", "channel", "everyone", "here", "keyword"])
    |> validate_inclusion(:detection_method, ["regex", "keyword", "special"])
    |> validate_number(:detection_confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:spam_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:processed_at, DateTime.utc_now())
  end

  def mark_notification_sent(mention, methods) do
    mention
    |> change(
      notification_sent: true,
      notification_sent_at: DateTime.utc_now(),
      notification_method: methods
    )
  end

  def mark_notification_read(mention) do
    mention
    |> change(
      notification_read: true,
      notification_read_at: DateTime.utc_now()
    )
  end

  def mark_user_responded(mention, response_message_id) do
    response_time = if mention.processed_at do
      DateTime.diff(DateTime.utc_now(), mention.processed_at, :second)
    else
      nil
    end

    mention
    |> change(
      user_responded: true,
      user_response_time: response_time,
      response_message_id: response_message_id
    )
  end

  def mark_dismissed(mention) do
    mention
    |> change(
      user_dismissed: true,
      dismissed_at: DateTime.utc_now()
    )
  end

  def mark_false_positive(mention) do
    mention
    |> change(
      false_positive: true,
      is_relevant: false
    )
  end

  # Query functions
  def for_user_query(user_id) do
    from m in __MODULE__,
      where: m.mentioned_user_id == ^user_id
  end

  def unread_mentions_query(user_id) do
    from m in __MODULE__,
      where: m.mentioned_user_id == ^user_id,
      where: m.notification_read == false,
      where: m.is_relevant == true,
      where: m.user_dismissed == false
  end

  def recent_mentions_query(user_id, hours_back \\ 24) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours_back, :hour)
    
    from m in __MODULE__,
      where: m.mentioned_user_id == ^user_id,
      where: m.processed_at >= ^cutoff,
      where: m.is_relevant == true,
      order_by: [desc: m.processed_at]
  end

  def pending_notifications_query do
    from m in __MODULE__,
      where: m.notification_sent == false,
      where: m.is_relevant == true,
      where: m.user_dismissed == false,
      where: m.spam_score < 0.7
  end

  def channel_mentions_query(channel_id, days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from m in __MODULE__,
      where: m.channel_id == ^channel_id,
      where: m.processed_at >= ^cutoff,
      where: m.is_relevant == true
  end

  def mention_stats_query(user_id, days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from m in __MODULE__,
      where: m.mentioned_user_id == ^user_id,
      where: m.processed_at >= ^cutoff,
      where: m.is_relevant == true,
      select: %{
        total_mentions: count(m.id),
        read_mentions: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", m.notification_read)),
        responded_mentions: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", m.user_responded)),
        avg_response_time: avg(m.user_response_time),
        mention_types: fragment("array_agg(DISTINCT ?)", m.mention_type)
      }
  end

  # Mention detection functions
  def extract_user_mentions(content) when is_binary(content) do
    # Match @username patterns
    Regex.scan(~r/@([a-zA-Z0-9._-]+)/, content, capture: :all_but_first)
    |> Enum.map(fn [username] -> 
      %{
        type: "user",
        text: "@#{username}",
        username: username,
        position: :binary.match(content, "@#{username}") |> elem(0)
      }
    end)
  end

  def extract_special_mentions(content) when is_binary(content) do
    special_patterns = [
      {"@channel", "channel"},
      {"@everyone", "everyone"}, 
      {"@here", "here"}
    ]
    
    Enum.flat_map(special_patterns, fn {pattern, type} ->
      case :binary.matches(content, pattern) do
        [] -> []
        matches ->
          Enum.map(matches, fn {position, _length} ->
            %{
              type: type,
              text: pattern,
              position: position
            }
          end)
      end
    end)
  end

  def extract_keyword_mentions(content, keywords) when is_binary(content) and is_list(keywords) do
    content_lower = String.downcase(content)
    
    Enum.flat_map(keywords, fn keyword ->
      keyword_lower = String.downcase(keyword)
      case :binary.matches(content_lower, keyword_lower) do
        [] -> []
        matches ->
          Enum.map(matches, fn {position, _length} ->
            %{
              type: "keyword",
              text: keyword,
              position: position,
              confidence: calculate_keyword_confidence(content_lower, keyword_lower, position)
            }
          end)
      end
    end)
  end

  defp calculate_keyword_confidence(content, keyword, position) do
    # Simple confidence calculation based on context
    # Higher confidence if keyword is a whole word
    before_char = if position > 0, do: String.at(content, position - 1), else: " "
    after_pos = position + String.length(keyword)
    after_char = if after_pos < String.length(content), do: String.at(content, after_pos), else: " "
    
    word_boundary_before = before_char in [" ", "\n", "\t", ".", "!", "?", ",", ";", ":"]
    word_boundary_after = after_char in [" ", "\n", "\t", ".", "!", "?", ",", ";", ":"]
    
    cond do
      word_boundary_before and word_boundary_after -> 1.0
      word_boundary_before or word_boundary_after -> 0.8
      true -> 0.6
    end
  end

  def calculate_spam_score(mention_text, content, user_history \\ []) do
    base_score = 0.0
    
    # Check for repetitive mentions
    mention_count = content |> String.split() |> Enum.count(&(&1 == mention_text))
    repetition_penalty = min(mention_count * 0.2, 0.6)
    
    # Check user's recent mention frequency
    recent_mentions = length(user_history)
    frequency_penalty = min(recent_mentions * 0.1, 0.4)
    
    # Simple spam indicators
    spam_indicators = [
      String.contains?(String.downcase(content), "urgent"),
      String.contains?(String.downcase(content), "asap"),
      String.length(content) < 10,
      String.contains?(content, "!!!") or String.contains?(content, "???")
    ]
    
    spam_penalty = Enum.count(spam_indicators, & &1) * 0.15
    
    min(base_score + repetition_penalty + frequency_penalty + spam_penalty, 1.0)
  end

  def get_mention_context(content, position, context_length \\ 50) do
    content_length = String.length(content)
    start_pos = max(0, position - context_length)
    end_pos = min(content_length, position + context_length)
    
    String.slice(content, start_pos, end_pos - start_pos)
    |> String.trim()
  end
end