defmodule SlackCloneWeb.Api.MessageControllerTest do
  @moduledoc """
  Comprehensive functional tests for message API endpoints within channels.
  Tests message posting, retrieval, updating, deletion, and real-time features.
  """
  use SlackCloneWeb.ConnCase, async: true
  use SlackClone.Factory

  import SlackClone.AccountsFixtures
  alias SlackClone.{Messages, Channels, Workspaces}
  alias SlackClone.Guardian

  describe "GET /api/workspaces/:workspace_id/channels/:channel_id/messages - List messages" do
    setup :setup_authenticated_channel

    test "lists messages in chronological order", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      # Create messages with different timestamps
      message1 = insert(:message, channel: channel, user: user, content: "First message", 
                       inserted_at: ~U[2024-01-01 10:00:00Z])
      message2 = insert(:message, channel: channel, user: user, content: "Second message", 
                       inserted_at: ~U[2024-01-01 10:01:00Z])
      message3 = insert(:message, channel: channel, user: user, content: "Third message", 
                       inserted_at: ~U[2024-01-01 10:02:00Z])

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages")
      
      messages = json_response(conn, 200)["data"]
      contents = Enum.map(messages, & &1["content"])
      
      assert length(messages) == 3
      assert contents == ["First message", "Second message", "Third message"]
    end

    test "includes message metadata", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      message = insert(:message, 
        channel: channel, 
        user: user,
        content: "Test message",
        metadata: %{"edited" => false, "reactions" => []}
      )

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages")
      
      [message_data] = json_response(conn, 200)["data"]
      
      assert message_data["id"] == message.id
      assert message_data["content"] == "Test message"
      assert message_data["user_id"] == user.id
      assert message_data["channel_id"] == channel.id
      assert message_data["metadata"] == %{"edited" => false, "reactions" => []}
      assert message_data["inserted_at"] != nil
      assert message_data["updated_at"] != nil
    end

    test "paginates messages with limit", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      # Create 25 messages
      for i <- 1..25 do
        insert(:message, channel: channel, user: user, content: "Message #{i}")
      end

      # Request with limit
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?limit=10")
      
      messages = json_response(conn, 200)["data"]
      
      assert length(messages) == 10
    end

    test "paginates messages with cursor", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      # Create messages
      messages = for i <- 1..5 do
        insert(:message, channel: channel, user: user, content: "Message #{i}")
      end
      
      # Get first page
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?limit=3")
      response = json_response(conn, 200)
      first_page = response["data"]
      cursor = response["pagination"]["next_cursor"]
      
      assert length(first_page) == 3
      assert cursor != nil
      
      # Get second page
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?limit=3&cursor=#{cursor}")
      second_page = json_response(conn, 200)["data"]
      
      assert length(second_page) == 2
      
      # Ensure no overlap
      first_ids = Enum.map(first_page, & &1["id"])
      second_ids = Enum.map(second_page, & &1["id"])
      assert MapSet.disjoint?(MapSet.new(first_ids), MapSet.new(second_ids))
    end

    test "filters messages by date range", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      # Create messages on different days
      old_message = insert(:message, channel: channel, user: user, content: "Old message",
                          inserted_at: ~U[2024-01-01 10:00:00Z])
      new_message = insert(:message, channel: channel, user: user, content: "New message",
                          inserted_at: ~U[2024-01-10 10:00:00Z])

      # Filter messages after 2024-01-05
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?since=2024-01-05T00:00:00Z")
      
      messages = json_response(conn, 200)["data"]
      contents = Enum.map(messages, & &1["content"])
      
      assert length(messages) == 1
      assert "New message" in contents
      assert "Old message" not in contents
    end

    test "returns 403 for private channel non-member", %{conn: conn, workspace: workspace} do
      private_channel = insert(:channel, workspace: workspace, is_private: true)
      
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{private_channel.id}/messages")
      
      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent channel", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/non-existent-id/messages")
      
      assert json_response(conn, 404)
    end

    test "includes user information in messages", %{conn: conn, workspace: workspace, channel: channel} do
      sender = insert(:user, name: "John Doe", username: "johndoe")
      message = insert(:message, channel: channel, user: sender, content: "Hello")

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages")
      
      [message_data] = json_response(conn, 200)["data"]
      user_data = message_data["user"]
      
      assert user_data["id"] == sender.id
      assert user_data["name"] == "John Doe"
      assert user_data["username"] == "johndoe"
    end
  end

  describe "POST /api/workspaces/:workspace_id/channels/:channel_id/messages - Create message" do
    setup :setup_authenticated_channel

    test "creates message with valid content", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      message_attrs = %{
        content: "Hello, world!",
        type: "text"
      }

      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: message_attrs)
      
      assert %{
        "id" => message_id,
        "content" => "Hello, world!",
        "type" => "text",
        "user_id" => user_id,
        "channel_id" => channel_id
      } = json_response(conn, 201)["data"]
      
      assert user_id == user.id
      assert channel_id == channel.id
      assert message_id != nil
    end

    test "creates message with mentions", %{conn: conn, workspace: workspace, channel: channel} do
      mentioned_user = insert(:user, username: "johndoe")
      
      message_attrs = %{
        content: "Hello @johndoe, how are you?",
        type: "text",
        mentions: [mentioned_user.id]
      }

      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: message_attrs)
      
      assert %{
        "content" => "Hello @johndoe, how are you?",
        "mentions" => mentions
      } = json_response(conn, 201)["data"]
      
      assert mentioned_user.id in mentions
    end

    test "creates thread reply message", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      parent_message = insert(:message, channel: channel, user: user)
      
      reply_attrs = %{
        content: "This is a reply",
        type: "text",
        thread_id: parent_message.id
      }

      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: reply_attrs)
      
      assert %{
        "content" => "This is a reply",
        "thread_id" => thread_id
      } = json_response(conn, 201)["data"]
      
      assert thread_id == parent_message.id
    end

    test "creates message with attachments", %{conn: conn, workspace: workspace, channel: channel} do
      message_attrs = %{
        content: "Check out this file",
        type: "text",
        attachments: [
          %{
            filename: "document.pdf",
            url: "https://example.com/document.pdf",
            content_type: "application/pdf",
            file_size: 1024
          }
        ]
      }

      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: message_attrs)
      
      assert %{
        "content" => "Check out this file",
        "attachments" => attachments
      } = json_response(conn, 201)["data"]
      
      assert length(attachments) == 1
      assert List.first(attachments)["filename"] == "document.pdf"
    end

    test "validates required content", %{conn: conn, workspace: workspace, channel: channel} do
      message_attrs = %{type: "text"}  # Missing content
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: message_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"content" => ["can't be blank"]} = errors
    end

    test "validates content length", %{conn: conn, workspace: workspace, channel: channel} do
      long_content = String.duplicate("a", 10001)  # Exceeds limit
      message_attrs = %{content: long_content, type: "text"}
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: message_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"content" => _} = errors
    end

    test "returns 403 for private channel non-member", %{conn: conn, workspace: workspace} do
      private_channel = insert(:channel, workspace: workspace, is_private: true)
      message_attrs = %{content: "Hello", type: "text"}
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{private_channel.id}/messages", message: message_attrs)
      
      assert json_response(conn, 403)
    end

    test "returns 403 for archived channel", %{conn: conn, workspace: workspace} do
      archived_channel = insert(:channel, workspace: workspace, is_archived: true)
      message_attrs = %{content: "Hello", type: "text"}
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{archived_channel.id}/messages", message: message_attrs)
      
      assert json_response(conn, 403)
    end

    test "handles concurrent message creation", %{conn: conn, workspace: workspace, channel: channel} do
      message_attrs = %{content: "Concurrent message", type: "text"}
      
      # Simulate concurrent requests
      tasks = 
        1..10
        |> Enum.map(fn i ->
          Task.async(fn ->
            post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", 
                 message: Map.put(message_attrs, :content, "Message #{i}"))
          end)
        end)
        |> Enum.map(&Task.await/1)
      
      successful_requests = Enum.count(tasks, &(&1.status == 201))
      
      # All should succeed
      assert successful_requests == 10
    end
  end

  describe "PUT /api/messages/:id - Update message" do
    setup :setup_authenticated_channel

    test "updates own message content", %{conn: conn, channel: channel, user: user} do
      message = insert(:message, channel: channel, user: user, content: "Original content")
      
      update_attrs = %{content: "Updated content"}
      
      conn = put(conn, ~p"/api/messages/#{message.id}", message: update_attrs)
      
      assert %{
        "id" => message_id,
        "content" => "Updated content",
        "metadata" => metadata
      } = json_response(conn, 200)["data"]
      
      assert message_id == message.id
      assert metadata["edited"] == true
      assert metadata["edited_at"] != nil
    end

    test "preserves original content in metadata", %{conn: conn, channel: channel, user: user} do
      message = insert(:message, channel: channel, user: user, content: "Original content")
      
      update_attrs = %{content: "Updated content"}
      
      conn = put(conn, ~p"/api/messages/#{message.id}", message: update_attrs)
      
      metadata = json_response(conn, 200)["data"]["metadata"]
      
      assert metadata["original_content"] == "Original content"
      assert metadata["edit_history"] != nil
    end

    test "returns 403 for other user's message", %{conn: conn, channel: channel} do
      other_user = insert(:user)
      message = insert(:message, channel: channel, user: other_user)
      
      update_attrs = %{content: "Unauthorized update"}
      
      conn = put(conn, ~p"/api/messages/#{message.id}", message: update_attrs)
      
      assert json_response(conn, 403)
    end

    test "validates updated content", %{conn: conn, channel: channel, user: user} do
      message = insert(:message, channel: channel, user: user)
      
      update_attrs = %{content: ""}  # Empty content
      
      conn = put(conn, ~p"/api/messages/#{message.id}", message: update_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"content" => ["can't be blank"]} = errors
    end

    test "allows admin to edit any message", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      insert(:workspace_membership, workspace: workspace, user: user, role: "admin")
      
      other_user = insert(:user)
      message = insert(:message, channel: channel, user: other_user, content: "Original")
      
      update_attrs = %{content: "Edited by admin"}
      
      conn = put(conn, ~p"/api/messages/#{message.id}", message: update_attrs)
      
      assert %{"content" => "Edited by admin"} = json_response(conn, 200)["data"]
    end

    test "prevents editing messages older than time limit", %{conn: conn, channel: channel, user: user} do
      # Create old message (older than edit time limit)
      old_time = DateTime.add(DateTime.utc_now(), -3600, :second)  # 1 hour ago
      message = insert(:message, channel: channel, user: user, inserted_at: old_time)
      
      update_attrs = %{content: "Updated content"}
      
      conn = put(conn, ~p"/api/messages/#{message.id}", message: update_attrs)
      
      assert json_response(conn, 403)["error"]["message"] =~ "edit time limit"
    end
  end

  describe "DELETE /api/messages/:id - Delete message" do
    setup :setup_authenticated_channel

    test "soft deletes own message", %{conn: conn, channel: channel, user: user} do
      message = insert(:message, channel: channel, user: user, content: "To be deleted")
      
      conn = delete(conn, ~p"/api/messages/#{message.id}")
      
      assert response(conn, 204)
      
      # Verify message is soft deleted
      updated_message = Repo.get!(Message, message.id)
      assert updated_message.content == "[deleted]"
      assert updated_message.metadata["deleted"] == true
      assert updated_message.metadata["deleted_at"] != nil
    end

    test "returns 403 for other user's message", %{conn: conn, channel: channel} do
      other_user = insert(:user)
      message = insert(:message, channel: channel, user: other_user)
      
      conn = delete(conn, ~p"/api/messages/#{message.id}")
      
      assert json_response(conn, 403)
    end

    test "allows admin to delete any message", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      insert(:workspace_membership, workspace: workspace, user: user, role: "admin")
      
      other_user = insert(:user)
      message = insert(:message, channel: channel, user: other_user)
      
      conn = delete(conn, ~p"/api/messages/#{message.id}")
      
      assert response(conn, 204)
    end

    test "hard deletes thread replies when parent is deleted", %{conn: conn, channel: channel, user: user} do
      parent_message = insert(:message, channel: channel, user: user)
      reply1 = insert(:message, channel: channel, user: user, thread_id: parent_message.id)
      reply2 = insert(:message, channel: channel, user: user, thread_id: parent_message.id)
      
      conn = delete(conn, ~p"/api/messages/#{parent_message.id}")
      
      assert response(conn, 204)
      
      # Verify replies are also deleted
      assert Repo.get(Message, reply1.id) == nil
      assert Repo.get(Message, reply2.id) == nil
    end

    test "prevents deletion of messages older than time limit", %{conn: conn, channel: channel, user: user} do
      # Create old message
      old_time = DateTime.add(DateTime.utc_now(), -3600, :second)  # 1 hour ago
      message = insert(:message, channel: channel, user: user, inserted_at: old_time)
      
      conn = delete(conn, ~p"/api/messages/#{message.id}")
      
      assert json_response(conn, 403)["error"]["message"] =~ "delete time limit"
    end
  end

  describe "POST /api/messages/:id/reactions - Add reaction" do
    setup :setup_authenticated_channel

    test "adds reaction to message", %{conn: conn, channel: channel, user: user} do
      message = insert(:message, channel: channel)
      
      reaction_attrs = %{emoji: "👍"}
      
      conn = post(conn, ~p"/api/messages/#{message.id}/reactions", reaction: reaction_attrs)
      
      assert %{
        "id" => reaction_id,
        "emoji" => "👍",
        "user_id" => user_id,
        "message_id" => message_id
      } = json_response(conn, 201)["data"]
      
      assert user_id == user.id
      assert message_id == message.id
    end

    test "prevents duplicate reactions from same user", %{conn: conn, channel: channel, user: user} do
      message = insert(:message, channel: channel)
      
      # Add first reaction
      reaction_attrs = %{emoji: "👍"}
      post(conn, ~p"/api/messages/#{message.id}/reactions", reaction: reaction_attrs)
      
      # Try to add same reaction again
      conn = post(conn, ~p"/api/messages/#{message.id}/reactions", reaction: reaction_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"user_id" => ["has already been taken"]} = errors
    end

    test "allows different emojis from same user", %{conn: conn, channel: channel, user: user} do
      message = insert(:message, channel: channel)
      
      # Add first reaction
      post(conn, ~p"/api/messages/#{message.id}/reactions", reaction: %{emoji: "👍"})
      
      # Add different reaction
      conn = post(conn, ~p"/api/messages/#{message.id}/reactions", reaction: %{emoji: "❤️"})
      
      assert %{"emoji" => "❤️"} = json_response(conn, 201)["data"]
    end

    test "validates emoji format", %{conn: conn, channel: channel} do
      message = insert(:message, channel: channel)
      
      reaction_attrs = %{emoji: "invalid_emoji"}
      
      conn = post(conn, ~p"/api/messages/#{message.id}/reactions", reaction: reaction_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"emoji" => _} = errors
    end
  end

  describe "DELETE /api/messages/:id/reactions/:reaction_id - Remove reaction" do
    setup :setup_authenticated_channel

    test "removes own reaction", %{conn: conn, channel: channel, user: user} do
      message = insert(:message, channel: channel)
      reaction = insert(:reaction, message: message, user: user, emoji: "👍")
      
      conn = delete(conn, ~p"/api/messages/#{message.id}/reactions/#{reaction.id}")
      
      assert response(conn, 204)
      
      # Verify reaction is deleted
      assert Repo.get(Reaction, reaction.id) == nil
    end

    test "returns 403 for other user's reaction", %{conn: conn, channel: channel} do
      other_user = insert(:user)
      message = insert(:message, channel: channel)
      reaction = insert(:reaction, message: message, user: other_user)
      
      conn = delete(conn, ~p"/api/messages/#{message.id}/reactions/#{reaction.id}")
      
      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent reaction", %{conn: conn, channel: channel} do
      message = insert(:message, channel: channel)
      
      conn = delete(conn, ~p"/api/messages/#{message.id}/reactions/non-existent-id")
      
      assert json_response(conn, 404)
    end
  end

  describe "Message search and filtering" do
    setup :setup_authenticated_channel

    test "searches messages by content", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      insert(:message, channel: channel, user: user, content: "Hello world")
      insert(:message, channel: channel, user: user, content: "Goodbye everyone")
      insert(:message, channel: channel, user: user, content: "World peace")

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?search=world")
      
      messages = json_response(conn, 200)["data"]
      contents = Enum.map(messages, & &1["content"])
      
      assert length(messages) == 2
      assert "Hello world" in contents
      assert "World peace" in contents
      assert "Goodbye everyone" not in contents
    end

    test "filters messages by user", %{conn: conn, workspace: workspace, channel: channel} do
      user1 = insert(:user, username: "alice")
      user2 = insert(:user, username: "bob")
      
      insert(:message, channel: channel, user: user1, content: "Message from Alice")
      insert(:message, channel: channel, user: user2, content: "Message from Bob")

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?user_id=#{user1.id}")
      
      messages = json_response(conn, 200)["data"]
      
      assert length(messages) == 1
      assert List.first(messages)["content"] == "Message from Alice"
    end

    test "filters messages by type", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      insert(:message, channel: channel, user: user, content: "Text message", type: "text")
      insert(:message, channel: channel, user: user, content: "System message", type: "system")

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?type=text")
      
      messages = json_response(conn, 200)["data"]
      
      assert length(messages) == 1
      assert List.first(messages)["type"] == "text"
    end

    test "excludes deleted messages from search", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      active_message = insert(:message, channel: channel, user: user, content: "Active message")
      deleted_message = insert(:message, channel: channel, user: user, content: "[deleted]",
                              metadata: %{"deleted" => true})

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages")
      
      messages = json_response(conn, 200)["data"]
      contents = Enum.map(messages, & &1["content"])
      
      assert "Active message" in contents
      assert "[deleted]" not in contents
    end
  end

  describe "Real-time message features" do
    setup :setup_authenticated_channel

    test "message includes timestamp for real-time ordering", %{conn: conn, workspace: workspace, channel: channel} do
      message_attrs = %{content: "Real-time message", type: "text"}
      
      before_time = DateTime.utc_now()
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: message_attrs)
      after_time = DateTime.utc_now()
      
      response_data = json_response(conn, 201)["data"]
      {:ok, inserted_at, _} = DateTime.from_iso8601(response_data["inserted_at"])
      
      assert DateTime.compare(inserted_at, before_time) in [:gt, :eq]
      assert DateTime.compare(inserted_at, after_time) in [:lt, :eq]
    end

    test "message includes unique ID for client tracking", %{conn: conn, workspace: workspace, channel: channel} do
      message_attrs = %{content: "Tracked message", type: "text"}
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: message_attrs)
      
      response_data = json_response(conn, 201)["data"]
      
      assert response_data["id"] != nil
      assert is_binary(response_data["id"])
      assert String.length(response_data["id"]) > 0
    end

    test "handles message ordering with microsecond precision", %{conn: conn, workspace: workspace, channel: channel} do
      # Create multiple messages rapidly
      messages = 
        for i <- 1..5 do
          attrs = %{content: "Message #{i}", type: "text"}
          response = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: attrs)
          json_response(response, 201)["data"]
        end
      
      # Verify all have unique timestamps
      timestamps = Enum.map(messages, & &1["inserted_at"])
      unique_timestamps = Enum.uniq(timestamps)
      
      assert length(timestamps) == length(unique_timestamps)
    end
  end

  # Test helper functions
  defp setup_authenticated_channel(_context) do
    user = insert(:user)
    workspace = insert(:workspace, owner: user)
    channel = insert(:channel, workspace: workspace, is_private: false)
    
    # Add user to channel
    insert(:channel_membership, channel: channel, user: user, role: "member")
    
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    
    conn = 
      build_conn()
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")
    
    %{conn: conn, user: user, workspace: workspace, channel: channel, token: token}
  end
end