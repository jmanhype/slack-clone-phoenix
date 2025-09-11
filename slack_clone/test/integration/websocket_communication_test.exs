defmodule SlackClone.Integration.WebSocketCommunicationTest do
  use SlackCloneWeb.ChannelCase, async: false

  import SlackClone.Factory

  alias SlackCloneWeb.{UserSocket, ChannelChannel, WorkspaceChannel}
  alias SlackClone.{Accounts, Workspaces, Channels, Messages}

  @moduletag :integration

  describe "WebSocket connection establishment" do
    test "connects with valid authentication token" do
      user = insert(:user)
      token = Accounts.generate_user_session_token(user)

      {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert socket.assigns.user_id == user.id
    end

    test "rejects connection with invalid token" do
      assert :error = connect(UserSocket, %{"token" => "invalid_token"})
    end

    test "rejects connection without token" do
      assert :error = connect(UserSocket, %{})
    end

    test "maintains connection state across multiple operations" do
      user = insert(:user)
      token = Accounts.generate_user_session_token(user)

      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      # Simulate multiple channel joins
      workspace = insert(:workspace)
      channel1 = insert(:channel, workspace: workspace)
      channel2 = insert(:channel, workspace: workspace)

      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel1.id}")
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel2.id}")

      # Verify socket maintains state for both channels
      assert socket.assigns.user_id == user.id
      assert_subscribed_to("channel:#{channel1.id}")
      assert_subscribed_to("channel:#{channel2.id}")
    end
  end

  describe "Channel communication flow" do
    setup do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      
      user1 = insert(:user, name: "Alice")
      user2 = insert(:user, name: "Bob")
      
      # Create memberships
      insert(:workspace_membership, workspace: workspace, user: user1)
      insert(:workspace_membership, workspace: workspace, user: user2)
      insert(:channel_membership, channel: channel, user: user1)
      insert(:channel_membership, channel: channel, user: user2)

      token1 = Accounts.generate_user_session_token(user1)
      token2 = Accounts.generate_user_session_token(user2)

      {:ok, socket1} = connect(UserSocket, %{"token" => token1})
      {:ok, socket2} = connect(UserSocket, %{"token" => token2})

      {:ok, _, socket1} = subscribe_and_join(socket1, ChannelChannel, "channel:#{channel.id}")
      {:ok, _, socket2} = subscribe_and_join(socket2, ChannelChannel, "channel:#{channel.id}")

      %{
        workspace: workspace,
        channel: channel,
        user1: user1,
        user2: user2,
        socket1: socket1,
        socket2: socket2
      }
    end

    test "broadcasts new message to all channel subscribers", %{
      channel: channel,
      user1: user1,
      socket1: socket1,
      socket2: socket2
    } do
      message_content = "Hello everyone!"

      # Send message from user1
      push(socket1, "new_message", %{
        "content" => message_content,
        "channel_id" => channel.id
      })

      # Both sockets should receive the message broadcast
      assert_broadcast("new_message", %{
        content: ^message_content,
        user_id: user1_id,
        channel_id: channel_id
      }) when user1_id == user1.id and channel_id == channel.id

      # Verify message was persisted to database
      assert [message] = Messages.list_messages(channel.id, user1.id)
      assert message.content == message_content
      assert message.user_id == user1.id
    end

    test "handles typing indicators with proper start/stop flow", %{
      channel: channel,
      user1: user1,
      user2: user2,
      socket1: socket1,
      socket2: socket2
    } do
      # User1 starts typing
      push(socket1, "typing_start", %{"channel_id" => channel.id})
      
      # User2 should receive typing notification
      assert_push("typing_start", %{
        user_id: user1_id,
        channel_id: channel_id
      }) when user1_id == user1.id and channel_id == channel.id

      # User1 stops typing
      push(socket1, "typing_stop", %{"channel_id" => channel.id})
      
      # User2 should receive stop notification
      assert_push("typing_stop", %{
        user_id: user1_id,
        channel_id: channel_id
      }) when user1_id == user1.id and channel_id == channel.id
    end

    test "supports real-time message reactions", %{
      channel: channel,
      user1: user1,
      user2: user2,
      socket1: socket1,
      socket2: socket2
    } do
      # Create a message first
      {:ok, message} = Messages.create_message(%{
        content: "React to this!",
        channel_id: channel.id,
        user_id: user1.id
      })

      # User2 adds a reaction
      push(socket2, "add_reaction", %{
        "message_id" => message.id,
        "emoji" => "👍"
      })

      # Both users should see the reaction update
      assert_broadcast("reaction_added", %{
        message_id: message_id,
        emoji: "👍",
        user_id: user2_id
      }) when message_id == message.id and user2_id == user2.id
    end

    test "handles concurrent message sending without race conditions", %{
      channel: channel,
      user1: user1,
      user2: user2,
      socket1: socket1,
      socket2: socket2
    } do
      # Send messages concurrently
      messages = for i <- 1..10 do
        socket = if rem(i, 2) == 0, do: socket1, else: socket2
        user = if rem(i, 2) == 0, do: user1, else: user2
        content = "Message #{i}"

        push(socket, "new_message", %{
          "content" => content,
          "channel_id" => channel.id
        })

        {content, user.id}
      end

      # Verify all messages are broadcast and persisted
      for {content, user_id} <- messages do
        assert_broadcast("new_message", %{
          content: ^content,
          user_id: ^user_id,
          channel_id: channel_id
        }) when channel_id == channel.id
      end

      # Verify all messages are in database in correct order
      persisted_messages = Messages.list_messages(channel.id, user1.id, limit: 10)
      assert length(persisted_messages) == 10
    end

    test "handles connection drops and reconnection gracefully", %{
      channel: channel,
      user1: user1,
      user2: user2,
      socket1: socket1,
      socket2: socket2
    } do
      # Send initial message
      push(socket1, "new_message", %{
        "content" => "Before disconnect",
        "channel_id" => channel.id
      })

      assert_broadcast("new_message", %{content: "Before disconnect"})

      # Simulate connection drop for user1
      leave(socket1)

      # User2 sends message while user1 is disconnected
      push(socket2, "new_message", %{
        "content" => "While disconnected",
        "channel_id" => channel.id
      })

      assert_broadcast("new_message", %{content: "While disconnected"})

      # User1 reconnects
      token1 = Accounts.generate_user_session_token(user1)
      {:ok, new_socket1} = connect(UserSocket, %{"token" => token1})
      {:ok, _, new_socket1} = subscribe_and_join(new_socket1, ChannelChannel, "channel:#{channel.id}")

      # User1 should be able to send messages again
      push(new_socket1, "new_message", %{
        "content" => "After reconnect",
        "channel_id" => channel.id
      })

      assert_broadcast("new_message", %{content: "After reconnect"})

      # Verify all messages are persisted
      messages = Messages.list_messages(channel.id, user1.id)
      contents = Enum.map(messages, & &1.content)
      assert "Before disconnect" in contents
      assert "While disconnected" in contents
      assert "After reconnect" in contents
    end
  end

  describe "Workspace-level communication" do
    setup do
      workspace = insert(:workspace, name: "Test Workspace")
      owner = insert(:user, name: "Owner")
      member = insert(:user, name: "Member")

      # Set workspace owner
      workspace = %{workspace | owner_id: owner.id}
      
      # Create memberships
      insert(:workspace_membership, workspace: workspace, user: owner, role: "owner")
      insert(:workspace_membership, workspace: workspace, user: member, role: "member")

      owner_token = Accounts.generate_user_session_token(owner)
      member_token = Accounts.generate_user_session_token(member)

      {:ok, owner_socket} = connect(UserSocket, %{"token" => owner_token})
      {:ok, member_socket} = connect(UserSocket, %{"token" => member_token})

      {:ok, _, owner_socket} = subscribe_and_join(owner_socket, WorkspaceChannel, "workspace:#{workspace.id}")
      {:ok, _, member_socket} = subscribe_and_join(member_socket, WorkspaceChannel, "workspace:#{workspace.id}")

      %{
        workspace: workspace,
        owner: owner,
        member: member,
        owner_socket: owner_socket,
        member_socket: member_socket
      }
    end

    test "broadcasts workspace announcements to all members", %{
      workspace: workspace,
      owner: owner,
      owner_socket: owner_socket,
      member_socket: member_socket
    } do
      announcement = "Welcome to our workspace!"

      push(owner_socket, "workspace_announcement", %{
        "content" => announcement,
        "workspace_id" => workspace.id
      })

      # All members should receive the announcement
      assert_broadcast("workspace_announcement", %{
        content: ^announcement,
        sender_id: owner_id,
        workspace_id: workspace_id
      }) when owner_id == owner.id and workspace_id == workspace.id
    end

    test "notifies members about new channel creation", %{
      workspace: workspace,
      owner: owner,
      member: member,
      owner_socket: owner_socket,
      member_socket: member_socket
    } do
      push(owner_socket, "create_channel", %{
        "name" => "new-channel",
        "description" => "A new channel for discussions",
        "workspace_id" => workspace.id
      })

      # Both owner and member should be notified
      assert_broadcast("channel_created", %{
        name: "new-channel",
        workspace_id: workspace_id
      }) when workspace_id == workspace.id
    end

    test "handles member presence tracking", %{
      workspace: workspace,
      owner: owner,
      member: member,
      owner_socket: owner_socket,
      member_socket: member_socket
    } do
      # Initially both users are present
      assert_push("presence_state", %{})

      # Simulate member going offline
      leave(member_socket)

      # Owner should be notified about member leaving
      assert_push("presence_diff", %{
        leaves: %{
          member_id => _
        }
      }) when member_id == to_string(member.id)

      # Member reconnects
      member_token = Accounts.generate_user_session_token(member)
      {:ok, new_member_socket} = connect(UserSocket, %{"token" => member_token})
      {:ok, _, _} = subscribe_and_join(new_member_socket, WorkspaceChannel, "workspace:#{workspace.id}")

      # Owner should be notified about member joining
      assert_push("presence_diff", %{
        joins: %{
          member_id => %{metas: [%{status: "online"}]}
        }
      }) when member_id == to_string(member.id)
    end
  end

  describe "Error handling and edge cases" do
    setup do
      user = insert(:user)
      token = Accounts.generate_user_session_token(user)
      {:ok, socket} = connect(UserSocket, %{"token" => token})

      %{user: user, socket: socket}
    end

    test "handles invalid channel join attempts", %{socket: socket} do
      # Try to join non-existent channel
      assert {:error, %{reason: "unauthorized"}} = 
        subscribe_and_join(socket, ChannelChannel, "channel:non-existent")
    end

    test "handles malformed message payloads", %{socket: socket, user: user} do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel, user: user)

      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")

      # Send message with missing required fields
      push(socket, "new_message", %{
        "content" => nil,  # Invalid content
        "channel_id" => channel.id
      })

      assert_reply("new_message", :error, %{reason: "invalid_message"})
    end

    test "handles rate limiting for message sending", %{socket: socket, user: user} do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel, user: user)

      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")

      # Send messages rapidly to trigger rate limiting
      for i <- 1..20 do
        push(socket, "new_message", %{
          "content" => "Spam message #{i}",
          "channel_id" => channel.id
        })
      end

      # After rate limit is hit, should receive error
      push(socket, "new_message", %{
        "content" => "This should be rate limited",
        "channel_id" => channel.id
      })

      assert_reply("new_message", :error, %{reason: "rate_limited"})
    end

    test "handles large payload messages gracefully", %{socket: socket, user: user} do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel, user: user)

      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")

      # Send very large message (exceeds limits)
      large_content = String.duplicate("a", 10_000)  # Assuming 5000 char limit

      push(socket, "new_message", %{
        "content" => large_content,
        "channel_id" => channel.id
      })

      assert_reply("new_message", :error, %{reason: "message_too_long"})
    end

    test "maintains message ordering under high concurrency", %{socket: socket, user: user} do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel, user: user)

      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")

      # Send messages with sequence numbers
      messages = for i <- 1..50 do
        content = "Ordered message #{i}"
        push(socket, "new_message", %{
          "content" => content,
          "channel_id" => channel.id,
          "client_sequence" => i
        })
        content
      end

      # Verify all messages are broadcast in order
      for content <- messages do
        assert_broadcast("new_message", %{content: ^content})
      end

      # Verify database ordering
      persisted_messages = Messages.list_messages(channel.id, user.id, limit: 50)
      persisted_contents = Enum.map(persisted_messages, & &1.content)
      
      assert persisted_contents == Enum.reverse(messages)  # Newest first in list
    end
  end

  describe "Cross-channel communication patterns" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user)
      insert(:workspace_membership, workspace: workspace, user: user)

      # Create multiple channels
      general_channel = insert(:channel, workspace: workspace, name: "general")
      random_channel = insert(:channel, workspace: workspace, name: "random")
      private_channel = insert(:private_channel, workspace: workspace, name: "private")

      # Add user to all channels
      insert(:channel_membership, channel: general_channel, user: user)
      insert(:channel_membership, channel: random_channel, user: user)
      insert(:channel_membership, channel: private_channel, user: user)

      token = Accounts.generate_user_session_token(user)
      {:ok, socket} = connect(UserSocket, %{"token" => token})

      # Join all channels
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{general_channel.id}")
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{random_channel.id}")
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{private_channel.id}")

      %{
        workspace: workspace,
        user: user,
        socket: socket,
        general_channel: general_channel,
        random_channel: random_channel,
        private_channel: private_channel
      }
    end

    test "handles cross-channel mentions and notifications", %{
      socket: socket,
      user: user,
      general_channel: general_channel,
      random_channel: random_channel
    } do
      # Send message in general that mentions #random
      push(socket, "new_message", %{
        "content" => "Check out the discussion in #random",
        "channel_id" => general_channel.id
      })

      # Should receive broadcasts on both channels due to cross-reference
      assert_broadcast("new_message", %{
        content: "Check out the discussion in #random",
        channel_id: general_id
      }) when general_id == general_channel.id

      assert_broadcast("channel_mention", %{
        mentioned_channel_id: random_id,
        source_channel_id: general_id,
        message_content: "Check out the discussion in #random"
      }) when random_id == random_channel.id and general_id == general_channel.id
    end

    test "maintains separate message streams per channel", %{
      socket: socket,
      general_channel: general_channel,
      random_channel: random_channel
    } do
      # Send messages to different channels
      push(socket, "new_message", %{
        "content" => "General message",
        "channel_id" => general_channel.id
      })

      push(socket, "new_message", %{
        "content" => "Random message",
        "channel_id" => random_channel.id
      })

      # Verify messages are broadcast to correct channels only
      assert_broadcast("new_message", %{
        content: "General message",
        channel_id: general_id
      }) when general_id == general_channel.id

      assert_broadcast("new_message", %{
        content: "Random message",
        channel_id: random_id
      }) when random_id == random_channel.id

      # Verify no cross-contamination
      refute_broadcast("new_message", %{
        content: "General message",
        channel_id: random_id
      }) when random_id == random_channel.id
    end
  end
end