defmodule SlackClone.MessagesTest do
  use SlackClone.DataCase, async: true

  import Mox
  alias SlackClone.Messages
  alias SlackClone.Messages.Message

  # London School TDD - Focus on message behavior and interactions
  setup :verify_on_exit!

  defmock(MockRepo, for: Ecto.Repo)
  defmock(MockPubSub, for: Phoenix.PubSub)
  defmock(MockChannelService, for: SlackClone.Channels)
  defmock(MockSearchService, for: SlackClone.Search)
  defmock(MockNotificationService, for: SlackClone.Notifications)
  defmock(MockMentionParser, for: SlackClone.Messages.MentionParser)

  describe "message creation - outside-in TDD" do
    test "creates message with proper event broadcasting and mention processing" do
      channel_id = "channel-123"
      user_id = "user-456"
      content = "Hello @john, check this out!"
      
      message_attrs = %{
        content: content,
        channel_id: channel_id,
        user_id: user_id
      }

      created_message = build(:message,
        id: "message-789",
        content: content,
        channel_id: channel_id,
        user_id: user_id,
        inserted_at: DateTime.utc_now()
      )

      mentioned_users = [build(:user, id: "john-id", username: "john")]

      # Verify the conversation between collaborators
      MockMentionParser
      |> expect(:extract_mentions, fn ^content -> ["@john"] end)
      |> expect(:resolve_mentions, fn ["@john"] -> mentioned_users end)

      MockChannelService
      |> expect(:can_access?, fn ^channel_id, ^user_id -> true end)

      MockRepo
      |> expect(:insert, fn changeset ->
        assert changeset.changes.content == content
        {:ok, created_message}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{channel_id}",
        {:new_message, ^created_message}
        -> :ok
      end)

      MockNotificationService
      |> expect(:send_mention_notifications, fn ^mentioned_users, ^created_message -> :ok end)

      MockSearchService
      |> expect(:index_message, fn ^created_message -> :ok end)

      result = Messages.create_message(message_attrs)
      assert {:ok, message} = result
      assert message.content == content
      assert message.channel_id == channel_id
      assert message.user_id == user_id
    end

    test "fails message creation when user lacks channel access" do
      channel_id = "private-channel"
      user_id = "unauthorized-user"
      message_attrs = %{
        content: "Trying to post",
        channel_id: channel_id,
        user_id: user_id
      }

      MockChannelService
      |> expect(:can_access?, fn ^channel_id, ^user_id -> false end)

      # Should not proceed with any other operations
      MockRepo |> expect(:insert, 0, fn _ -> {:ok, %{}} end)
      MockPubSub |> expect(:broadcast, 0, fn _, _, _ -> :ok end)

      result = Messages.create_message(message_attrs)
      assert {:error, :unauthorized} = result
    end

    test "handles message creation with file attachments" do
      channel_id = "channel-123"
      user_id = "user-456"
      content = "Check out these files!"
      attachments = [
        %{filename: "document.pdf", size: 1024, url: "https://cdn.example.com/doc.pdf"},
        %{filename: "image.jpg", size: 2048, url: "https://cdn.example.com/img.jpg"}
      ]

      message_attrs = %{
        content: content,
        channel_id: channel_id,
        user_id: user_id,
        attachments: attachments
      }

      created_message = build(:message, id: "message-with-files")

      MockChannelService
      |> expect(:can_access?, fn ^channel_id, ^user_id -> true end)

      MockMentionParser
      |> expect(:extract_mentions, fn ^content -> [] end)

      MockRepo
      |> expect(:insert, fn _changeset -> {:ok, created_message} end)
      |> expect(:insert_all, fn "message_attachments", attachment_records ->
        assert length(attachment_records) == 2
        {2, nil}
      end)

      MockPubSub
      |> expect(:broadcast, fn _, _, {:new_message, ^created_message} -> :ok end)

      MockSearchService
      |> expect(:index_message, fn ^created_message -> :ok end)

      result = Messages.create_message(message_attrs)
      assert {:ok, message} = result
    end
  end

  describe "message editing - behavior verification" do
    test "edits message with proper history tracking and re-indexing" do
      message_id = "message-123"
      user_id = "user-456"
      new_content = "Updated message content"
      
      original_message = build(:message,
        id: message_id,
        user_id: user_id,
        content: "Original content",
        edited: false
      )

      updated_message = %{original_message | 
        content: new_content,
        edited: true,
        edited_at: DateTime.utc_now()
      }

      MockRepo
      |> expect(:get, fn Message, ^message_id -> original_message end)
      |> expect(:update, fn changeset ->
        assert changeset.changes.content == new_content
        assert changeset.changes.edited == true
        {:ok, updated_message}
      end)
      |> expect(:insert, fn edit_history_changeset ->
        # Verify edit history is being tracked
        assert edit_history_changeset.changes.original_content == "Original content"
        {:ok, %{message_id: message_id, original_content: "Original content"}}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{original_message.channel_id}",
        {:message_edited, ^updated_message}
        -> :ok
      end)

      MockSearchService
      |> expect(:reindex_message, fn ^updated_message -> :ok end)

      result = Messages.edit_message(message_id, user_id, new_content)
      assert {:ok, message} = result
      assert message.content == new_content
      assert message.edited == true
    end

    test "prevents editing by unauthorized user" do
      message_id = "message-123"
      unauthorized_user_id = "other-user"
      
      original_message = build(:message,
        id: message_id,
        user_id: "original-author",
        content: "Original content"
      )

      MockRepo
      |> expect(:get, fn Message, ^message_id -> original_message end)

      # Should not proceed with editing operations
      MockRepo |> expect(:update, 0, fn _ -> {:ok, %{}} end)
      MockPubSub |> expect(:broadcast, 0, fn _, _, _ -> :ok end)

      result = Messages.edit_message(message_id, unauthorized_user_id, "Hacked content")
      assert {:error, :unauthorized} = result
    end

    test "prevents editing after time limit expires" do
      message_id = "old-message"
      user_id = "user-456"
      
      old_message = build(:message,
        id: message_id,
        user_id: user_id,
        content: "Old content",
        inserted_at: DateTime.add(DateTime.utc_now(), -3601, :second)  # 1 hour + 1 second ago
      )

      MockRepo
      |> expect(:get, fn Message, ^message_id -> old_message end)

      result = Messages.edit_message(message_id, user_id, "Too late to edit")
      assert {:error, :edit_time_expired} = result
    end
  end

  describe "message deletion - collaboration patterns" do
    test "soft deletes message with proper cleanup workflow" do
      message_id = "message-123"
      user_id = "user-456"
      
      message = build(:message,
        id: message_id,
        user_id: user_id,
        content: "Message to delete",
        deleted: false
      )

      deleted_message = %{message | deleted: true, deleted_at: DateTime.utc_now()}

      MockRepo
      |> expect(:get, fn Message, ^message_id -> message end)
      |> expect(:update, fn changeset ->
        assert changeset.changes.deleted == true
        {:ok, deleted_message}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{message.channel_id}",
        {:message_deleted, ^deleted_message}
        -> :ok
      end)

      MockSearchService
      |> expect(:remove_from_index, fn ^message_id -> :ok end)

      # Clean up any associated reactions and thread replies
      MockRepo
      |> expect(:update_all, fn reactions_query, [set: [deleted: true]] -> {2, nil} end)
      |> expect(:update_all, fn replies_query, [set: [thread_deleted: true]] -> {1, nil} end)

      result = Messages.delete_message(message_id, user_id)
      assert {:ok, deleted_msg} = result
      assert deleted_msg.deleted == true
    end

    test "allows admin to delete any message" do
      message_id = "message-123"
      admin_user_id = "admin-user"
      
      message = build(:message,
        id: message_id,
        user_id: "different-user",  # Not the admin
        content: "Message to delete"
      )

      MockChannelService
      |> expect(:is_channel_admin?, fn ^admin_user_id, channel_id -> 
        assert channel_id == message.channel_id
        true
      end)

      MockRepo
      |> expect(:get, fn Message, ^message_id -> message end)
      |> expect(:update, fn _changeset -> {:ok, %{message | deleted: true}} end)
      |> expect(:update_all, 2, fn _, _ -> {0, nil} end)  # reactions and replies cleanup

      MockPubSub
      |> expect(:broadcast, fn _, _, {:message_deleted, _} -> :ok end)

      MockSearchService
      |> expect(:remove_from_index, fn ^message_id -> :ok end)

      result = Messages.delete_message(message_id, admin_user_id)
      assert {:ok, deleted_msg} = result
      assert deleted_msg.deleted == true
    end
  end

  describe "message threading - interaction testing" do
    test "creates thread reply with proper parent message linking" do
      parent_message_id = "parent-123"
      channel_id = "channel-456" 
      user_id = "user-789"
      reply_content = "This is a reply to the thread"

      parent_message = build(:message,
        id: parent_message_id,
        channel_id: channel_id,
        thread_count: 0
      )

      reply_message = build(:message,
        id: "reply-456",
        content: reply_content,
        channel_id: channel_id,
        user_id: user_id,
        thread_parent_id: parent_message_id
      )

      updated_parent = %{parent_message | thread_count: 1, last_reply_at: DateTime.utc_now()}

      MockRepo
      |> expect(:get, fn Message, ^parent_message_id -> parent_message end)
      |> expect(:insert, fn reply_changeset ->
        assert reply_changeset.changes.thread_parent_id == parent_message_id
        {:ok, reply_message}
      end)
      |> expect(:update, fn parent_changeset ->
        assert parent_changeset.changes.thread_count == 1
        {:ok, updated_parent}
      end)

      MockChannelService
      |> expect(:can_access?, fn ^channel_id, ^user_id -> true end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{channel_id}",
        {:thread_reply, ^reply_message, ^updated_parent}
        -> :ok
      end)
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "thread:#{parent_message_id}",
        {:new_reply, ^reply_message}
        -> :ok
      end)

      result = Messages.create_thread_reply(parent_message_id, user_id, reply_content)
      assert {:ok, {reply, parent}} = result
      assert reply.thread_parent_id == parent_message_id
      assert parent.thread_count == 1
    end

    test "retrieves thread with all replies in chronological order" do
      parent_message_id = "parent-123"
      
      parent_message = build(:message, id: parent_message_id, thread_count: 3)
      thread_replies = [
        build(:message, thread_parent_id: parent_message_id, inserted_at: ~N[2024-01-01 10:00:00]),
        build(:message, thread_parent_id: parent_message_id, inserted_at: ~N[2024-01-01 11:00:00]),
        build(:message, thread_parent_id: parent_message_id, inserted_at: ~N[2024-01-01 12:00:00])
      ]

      MockRepo
      |> expect(:get, fn Message, ^parent_message_id -> parent_message end)
      |> expect(:all, fn replies_query ->
        # Verify query orders by inserted_at ASC
        thread_replies
      end)

      result = Messages.get_thread(parent_message_id)
      assert {:ok, {parent, replies}} = result
      assert parent.id == parent_message_id
      assert length(replies) == 3
      
      # Verify chronological order
      timestamps = Enum.map(replies, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, DateTime)
    end
  end

  describe "message reactions - contract testing" do
    test "adds reaction with proper aggregation and broadcasting" do
      message_id = "message-123"
      user_id = "user-456"
      emoji = "👍"

      message = build(:message, id: message_id, reaction_counts: %{})
      existing_reaction = nil  # User hasn't reacted with this emoji yet

      MockRepo
      |> expect(:get, fn Message, ^message_id -> message end)
      |> expect(:get_by, fn "message_reactions", 
        [message_id: ^message_id, user_id: ^user_id, emoji: ^emoji] -> existing_reaction
      end)
      |> expect(:insert, fn reaction_changeset ->
        {:ok, %{message_id: message_id, user_id: user_id, emoji: emoji}}
      end)
      |> expect(:update, fn message_changeset ->
        updated_counts = Map.put(message.reaction_counts, emoji, 1)
        {:ok, %{message | reaction_counts: updated_counts}}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{message.channel_id}",
        {:reaction_added, %{message_id: ^message_id, emoji: ^emoji, user_id: ^user_id}}
        -> :ok
      end)

      result = Messages.add_reaction(message_id, user_id, emoji)
      assert {:ok, updated_message} = result
      assert updated_message.reaction_counts[emoji] == 1
    end

    test "removes existing reaction with count decrement" do
      message_id = "message-123"
      user_id = "user-456"
      emoji = "👍"

      message = build(:message, id: message_id, reaction_counts: %{emoji => 2})
      existing_reaction = %{id: "reaction-789", message_id: message_id, user_id: user_id, emoji: emoji}

      MockRepo
      |> expect(:get, fn Message, ^message_id -> message end)
      |> expect(:get_by, fn "message_reactions", 
        [message_id: ^message_id, user_id: ^user_id, emoji: ^emoji] -> existing_reaction
      end)
      |> expect(:delete, fn ^existing_reaction -> {:ok, existing_reaction} end)
      |> expect(:update, fn message_changeset ->
        updated_counts = Map.put(message.reaction_counts, emoji, 1)
        {:ok, %{message | reaction_counts: updated_counts}}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{message.channel_id}",
        {:reaction_removed, %{message_id: ^message_id, emoji: ^emoji, user_id: ^user_id}}
        -> :ok
      end)

      result = Messages.toggle_reaction(message_id, user_id, emoji)
      assert {:ok, updated_message} = result
      assert updated_message.reaction_counts[emoji] == 1
    end
  end

  describe "message search - external service integration" do
    test "searches messages with proper filtering and ranking" do
      channel_id = "channel-123"
      user_id = "user-456"
      search_query = "important meeting"
      
      search_results = [
        build(:message, content: "Tomorrow's meeting is very important"),
        build(:message, content: "Important update about the meeting time")
      ]

      MockChannelService
      |> expect(:can_access?, fn ^channel_id, ^user_id -> true end)

      MockSearchService
      |> expect(:search_messages, fn query_params ->
        assert query_params.query == search_query
        assert query_params.channel_id == channel_id
        assert query_params.user_id == user_id
        search_results
      end)

      result = Messages.search_messages(channel_id, user_id, search_query)
      assert {:ok, messages} = result
      assert length(messages) == 2
      assert Enum.all?(messages, &String.contains?(&1.content, "meeting"))
    end

    test "returns empty results when user lacks channel access" do
      channel_id = "private-channel"
      user_id = "unauthorized-user"
      search_query = "secret info"

      MockChannelService
      |> expect(:can_access?, fn ^channel_id, ^user_id -> false end)

      # Should not call search service
      MockSearchService |> expect(:search_messages, 0, fn _ -> [] end)

      result = Messages.search_messages(channel_id, user_id, search_query)
      assert {:error, :unauthorized} = result
    end
  end

  describe "message validation - contract definition" do
    test "validates message length limits" do
      long_content = String.duplicate("a", 5001)  # Exceeds 5000 character limit
      
      message_attrs = %{
        content: long_content,
        channel_id: "channel-123",
        user_id: "user-456"
      }

      error_changeset = %Ecto.Changeset{
        valid?: false,
        errors: [content: {"should be at most 5000 character(s)", [count: 5000, validation: :length]}]
      }

      MockChannelService
      |> expect(:can_access?, fn _, _ -> true end)

      MockRepo
      |> expect(:insert, fn _changeset -> {:error, error_changeset} end)

      result = Messages.create_message(message_attrs)
      assert {:error, changeset} = result
      refute changeset.valid?
    end

    test "validates required fields presence" do
      incomplete_attrs = %{
        content: nil,  # Required field missing
        channel_id: "channel-123"
        # user_id missing
      }

      error_changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          content: {"can't be blank", [validation: :required]},
          user_id: {"can't be blank", [validation: :required]}
        ]
      }

      MockRepo
      |> expect(:insert, fn _changeset -> {:error, error_changeset} end)

      result = Messages.create_message(incomplete_attrs)
      assert {:error, changeset} = result
      refute changeset.valid?
    end
  end
end