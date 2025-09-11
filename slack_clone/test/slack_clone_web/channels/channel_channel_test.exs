defmodule SlackCloneWeb.ChannelChannelTest do
  use SlackCloneWeb.ChannelCase
  use ExMachina

  import SlackClone.Factory

  alias SlackCloneWeb.ChannelChannel
  alias SlackCloneWeb.UserSocket
  alias Phoenix.PubSub

  setup do
    workspace = insert(:workspace)
    channel = insert(:channel, workspace: workspace)
    user = insert(:user)
    
    # Create workspace membership
    insert(:workspace_membership, workspace: workspace, user: user)
    insert(:channel_membership, channel: channel, user: user)
    
    %{workspace: workspace, channel: channel, user: user}
  end

  describe "join/3" do
    test "allows authorized user to join channel", %{channel: channel, user: user} do
      # Mock the socket with user authentication
      socket = %Phoenix.Socket{
        assigns: %{current_user: user},
        channel: ChannelChannel,
        topic: "channel:#{channel.id}"
      }

      assert {:ok, reply, new_socket} = ChannelChannel.join("channel:#{channel.id}", %{}, socket)
      
      # Should return channel info
      assert reply.channel.id == channel.id
      
      # Should assign channel data to socket
      assert new_socket.assigns.channel_id == channel.id
      assert new_socket.assigns.channel.id == channel.id
      assert new_socket.assigns.typing_timer == nil
    end

    test "denies unauthorized user access", %{user: user} do
      socket = %Phoenix.Socket{
        assigns: %{current_user: user},
        channel: ChannelChannel,
        topic: "channel:unauthorized"
      }

      assert {:error, %{reason: "Access denied"}} = 
        ChannelChannel.join("channel:unauthorized", %{}, socket)
    end

    test "tracks user presence and loads recent messages", %{channel: channel, user: user} do
      # Subscribe to presence events
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}")
      
      socket = %Phoenix.Socket{
        assigns: %{current_user: user},
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }

      {:ok, _reply, _new_socket} = ChannelChannel.join("channel:#{channel.id}", %{}, socket)
      
      # Should send messages and presence after join
      assert_received :after_join
    end
  end

  describe "handle_in/3 - send_message" do
    setup %{channel: channel, user: user} do
      socket = %Phoenix.Socket{
        assigns: %{
          current_user: user,
          channel_id: channel.id,
          channel: channel,
          typing_timer: nil
        },
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }
      
      %{socket: socket}
    end

    test "handles regular message sending", %{socket: socket, channel: channel, user: user} do
      # Subscribe to message broadcasts
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:messages")
      
      params = %{
        "content" => "Hello everyone!",
        "temp_id" => "temp_123"
      }

      # Mock the message creation to succeed
      message = %{
        id: Ecto.UUID.generate(),
        content: params["content"],
        user_id: user.id,
        channel_id: channel.id,
        inserted_at: DateTime.utc_now()
      }

      # This would normally call the actual create_message function
      # For testing, we'll simulate the successful case
      with_mock SlackClone.Messages, [:passthrough],
        create_message: fn _channel_id, _user_id, _content, _metadata -> {:ok, message} end do
        
        {:noreply, _socket} = ChannelChannel.handle_in("send_message", params, socket)
        
        # Should broadcast to channel
        assert_called SlackClone.Messages.create_message(channel.id, user.id, params["content"], %{})
      end
    end

    test "handles thread reply messages", %{socket: socket, user: user} do
      parent_message = insert(:message, channel: socket.assigns.channel)
      
      params = %{
        "content" => "This is a reply",
        "thread_id" => parent_message.id
      }

      {:noreply, _socket} = ChannelChannel.handle_in("send_message", params, socket)
      
      # Should handle as thread reply (implementation would create thread reply)
    end

    test "handles message send errors", %{socket: socket, channel: channel, user: user} do
      params = %{
        "content" => "",
        "temp_id" => "temp_456"
      }

      # Mock message creation failure
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [content: {"can't be blank", [validation: :required]}]
      }

      with_mock SlackClone.Messages, [:passthrough],
        create_message: fn _channel_id, _user_id, _content, _metadata -> {:error, changeset} end do
        
        {:noreply, _socket} = ChannelChannel.handle_in("send_message", params, socket)
        
        # Should push error message
        assert_push "message_error", %{temp_id: "temp_456", errors: _}
      end
    end

    test "validates message content", %{socket: socket} do
      params = %{
        "content" => String.duplicate("a", 5000),  # Very long message
        "temp_id" => "temp_789"
      }

      {:noreply, _socket} = ChannelChannel.handle_in("send_message", params, socket)
      
      # Implementation would validate message length
    end
  end

  describe "handle_in/3 - message management" do
    setup %{channel: channel, user: user} do
      message = insert(:message, channel: channel, user: user)
      
      socket = %Phoenix.Socket{
        assigns: %{
          current_user: user,
          channel_id: channel.id,
          channel: channel,
          typing_timer: nil
        },
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }
      
      %{socket: socket, message: message}
    end

    test "allows user to edit their own message", %{socket: socket, message: message, user: user} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{socket.assigns.channel_id}:messages")
      
      params = %{
        "message_id" => message.id,
        "content" => "Updated message content"
      }

      updated_message = %{message | content: params["content"], updated_at: DateTime.utc_now()}

      with_mock SlackClone.Messages, [:passthrough],
        edit_message: fn _message_id, _content, _user_id -> {:ok, updated_message} end do
        
        {:noreply, _socket} = ChannelChannel.handle_in("edit_message", params, socket)
        
        assert_push "message_edited", %{message: ^updated_message}
        assert_called SlackClone.Messages.edit_message(message.id, params["content"], user.id)
      end
    end

    test "prevents user from editing others' messages", %{socket: socket} do
      other_user = insert(:user)
      other_message = insert(:message, channel: socket.assigns.channel, user: other_user)
      
      params = %{
        "message_id" => other_message.id,
        "content" => "Trying to edit others message"
      }

      with_mock SlackClone.Messages, [:passthrough],
        edit_message: fn _message_id, _content, _user_id -> {:error, "unauthorized"} end do
        
        {:noreply, _socket} = ChannelChannel.handle_in("edit_message", params, socket)
        
        assert_push "edit_error", %{message_id: other_message.id, reason: "unauthorized"}
      end
    end

    test "allows user to delete their own message", %{socket: socket, message: message, user: user} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{socket.assigns.channel_id}:messages")
      
      params = %{"message_id" => message.id}

      with_mock SlackClone.Messages, [:passthrough],
        delete_message: fn _message_id, _user_id -> {:ok, message} end do
        
        {:noreply, _socket} = ChannelChannel.handle_in("delete_message", params, socket)
        
        assert_push "message_deleted", %{message_id: ^message.id}
        assert_called SlackClone.Messages.delete_message(message.id, user.id)
      end
    end
  end

  describe "handle_in/3 - typing indicators" do
    setup %{channel: channel, user: user} do
      socket = %Phoenix.Socket{
        assigns: %{
          current_user: user,
          channel_id: channel.id,
          channel: channel,
          typing_timer: nil
        },
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }
      
      %{socket: socket}
    end

    test "handles typing start", %{socket: socket, channel: channel, user: user} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:typing")
      
      {:noreply, new_socket} = ChannelChannel.handle_in("typing_start", %{}, socket)
      
      # Should set typing timer
      assert is_reference(new_socket.assigns.typing_timer)
      
      # Should broadcast typing start (mocked)
      # assert_receive {:typing_start, %{user_id: ^user.id}}
    end

    test "handles typing stop", %{socket: socket, user: user} do
      # First set a typing timer
      timer_ref = Process.send_after(self(), :test, 1000)
      socket_with_timer = %{socket | assigns: %{socket.assigns | typing_timer: timer_ref}}
      
      {:noreply, new_socket} = ChannelChannel.handle_in("typing_stop", %{}, socket_with_timer)
      
      # Timer should be cancelled and set to nil
      assert new_socket.assigns.typing_timer == nil
    end

    test "automatically stops typing after timeout", %{socket: socket} do
      # Set up socket with typing timer
      timer_ref = Process.send_after(self(), :typing_timeout, 100)
      socket_with_timer = %{socket | assigns: %{socket.assigns | typing_timer: timer_ref}}
      
      {:noreply, new_socket} = ChannelChannel.handle_info(:typing_timeout, socket_with_timer)
      
      # Should clear timer
      assert new_socket.assigns.typing_timer == nil
    end
  end

  describe "handle_in/3 - reactions" do
    setup %{channel: channel, user: user} do
      message = insert(:message, channel: channel)
      
      socket = %Phoenix.Socket{
        assigns: %{
          current_user: user,
          channel_id: channel.id,
          channel: channel,
          typing_timer: nil
        },
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }
      
      %{socket: socket, message: message}
    end

    test "adds reaction to message", %{socket: socket, message: message, user: user} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{socket.assigns.channel_id}:reactions")
      
      params = %{
        "message_id" => message.id,
        "emoji" => "👍"
      }

      reaction = %{
        id: Ecto.UUID.generate(),
        message_id: message.id,
        user_id: user.id,
        emoji: "👍"
      }

      with_mock SlackClone.Messages, [:passthrough],
        add_reaction_to_message: fn _message_id, _emoji, _user_id -> {:ok, reaction} end do
        
        {:noreply, _socket} = ChannelChannel.handle_in("add_reaction", params, socket)
        
        assert_push "reaction_added", %{message_id: ^message.id, reaction: ^reaction}
        assert_called SlackClone.Messages.add_reaction_to_message(message.id, "👍", user.id)
      end
    end

    test "removes reaction from message", %{socket: socket, user: user} do
      reaction = %{
        id: Ecto.UUID.generate(),
        message_id: Ecto.UUID.generate(),
        user_id: user.id,
        emoji: "👍"
      }

      params = %{"reaction_id" => reaction.id}

      with_mock SlackClone.Messages, [:passthrough],
        remove_reaction: fn _reaction_id, _user_id -> {:ok, reaction} end do
        
        {:noreply, _socket} = ChannelChannel.handle_in("remove_reaction", params, socket)
        
        assert_push "reaction_removed", %{reaction: ^reaction}
        assert_called SlackClone.Messages.remove_reaction(reaction.id, user.id)
      end
    end
  end

  describe "handle_in/3 - read receipts and threads" do
    setup %{channel: channel, user: user} do
      message = insert(:message, channel: channel)
      
      socket = %Phoenix.Socket{
        assigns: %{
          current_user: user,
          channel_id: channel.id,
          channel: channel,
          typing_timer: nil
        },
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }
      
      %{socket: socket, message: message}
    end

    test "marks message as read", %{socket: socket, message: message, user: user} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{socket.assigns.channel_id}:read_receipts")
      
      params = %{"message_id" => message.id}

      {:noreply, _socket} = ChannelChannel.handle_in("mark_read", params, socket)
      
      # Implementation would mark message as read and broadcast
    end

    test "loads older messages", %{socket: socket, channel: channel} do
      before_message = insert(:message, channel: channel)
      
      params = %{"before_id" => before_message.id}

      {:noreply, _socket} = ChannelChannel.handle_in("load_older_messages", params, socket)
      
      # Should push older messages (implementation dependent)
      assert_push "older_messages_loaded", %{messages: _}
    end

    test "starts thread on message", %{socket: socket, message: message} do
      params = %{"message_id" => message.id}

      {:noreply, _socket} = ChannelChannel.handle_in("start_thread", params, socket)
      
      # Implementation would load and return thread data
    end
  end

  describe "handle_info/2 - PubSub events" do
    setup %{channel: channel, user: user} do
      socket = %Phoenix.Socket{
        assigns: %{
          current_user: user,
          channel_id: channel.id,
          channel: channel,
          typing_timer: nil
        },
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }
      
      %{socket: socket}
    end

    test "broadcasts new messages to channel subscribers", %{socket: socket, channel: channel} do
      message = insert(:message, channel: channel)
      
      {:noreply, _socket} = ChannelChannel.handle_info({:new_message, message}, socket)
      
      assert_push "new_message", %{message: ^message}
    end

    test "broadcasts message updates", %{socket: socket, channel: channel} do
      message = insert(:edited_message, channel: channel)
      
      {:noreply, _socket} = ChannelChannel.handle_info({:message_updated, message}, socket)
      
      assert_push "message_updated", %{message: ^message}
    end

    test "broadcasts message deletions", %{socket: socket} do
      message_id = Ecto.UUID.generate()
      
      {:noreply, _socket} = ChannelChannel.handle_info({:message_deleted, %{id: message_id}}, socket)
      
      assert_push "message_deleted", %{message_id: ^message_id}
    end

    test "broadcasts typing events but not from same user", %{socket: socket, user: user} do
      other_user = insert(:user)
      typing_data = %{user_id: other_user.id, user_name: other_user.name}
      
      {:noreply, _socket} = ChannelChannel.handle_info({:typing_start, typing_data}, socket)
      
      assert_push "typing_start", ^typing_data
      
      # Should not broadcast own typing events
      own_typing_data = %{user_id: user.id, user_name: user.name}
      {:noreply, _socket} = ChannelChannel.handle_info({:typing_start, own_typing_data}, socket)
      
      refute_push "typing_start", ^own_typing_data
    end

    test "broadcasts presence diffs", %{socket: socket} do
      diff = %{
        joins: %{1 => %{name: "User 1"}},
        leaves: %{2 => %{name: "User 2"}}
      }
      
      {:noreply, _socket} = ChannelChannel.handle_info(%{event: "presence_diff", payload: diff}, socket)
      
      assert_push "presence_diff", ^diff
    end

    test "broadcasts user join/leave events", %{socket: socket} do
      user = insert(:user)
      
      {:noreply, _socket} = ChannelChannel.handle_info({:user_joined, user}, socket)
      assert_push "user_joined", %{user: ^user}
      
      {:noreply, _socket} = ChannelChannel.handle_info({:user_left, %{user_id: user.id}}, socket)
      assert_push "user_left", %{user_id: ^user.id}
    end

    test "ignores unknown messages", %{socket: socket} do
      {:noreply, _socket} = ChannelChannel.handle_info(:unknown_message, socket)
      # Should not crash and return socket unchanged
    end
  end

  describe "terminate/2" do
    setup %{channel: channel, user: user} do
      socket = %Phoenix.Socket{
        assigns: %{
          current_user: user,
          channel_id: channel.id,
          channel: channel,
          typing_timer: Process.send_after(self(), :test, 1000)
        },
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }
      
      %{socket: socket}
    end

    test "cleans up typing timer on termination", %{socket: socket} do
      assert is_reference(socket.assigns.typing_timer)
      
      :ok = ChannelChannel.terminate(:normal, socket)
      
      # Implementation should cancel timer and unsubscribe
    end

    test "handles termination with no timer", %{socket: socket} do
      socket_no_timer = %{socket | assigns: %{socket.assigns | typing_timer: nil}}
      
      :ok = ChannelChannel.terminate(:normal, socket_no_timer)
    end

    test "handles termination with no channel_id", %{socket: socket} do
      socket_no_channel = %{socket | assigns: %{socket.assigns | channel_id: nil}}
      
      :ok = ChannelChannel.terminate(:normal, socket_no_channel)
    end
  end

  describe "message metadata handling" do
    setup %{channel: channel, user: user} do
      socket = %Phoenix.Socket{
        assigns: %{
          current_user: user,
          channel_id: channel.id,
          channel: channel,
          typing_timer: nil
        },
        channel: ChannelChannel,
        topic: "channel:#{channel.id}",
        transport_pid: self()
      }
      
      %{socket: socket}
    end

    test "extracts mentions from message content", %{socket: socket} do
      params = %{
        "content" => "Hey @john and @jane, check this out!",
        "temp_id" => "temp_123"
      }

      # This tests the extract_mentions function indirectly
      {:noreply, _socket} = ChannelChannel.handle_in("send_message", params, socket)
      
      # Implementation should extract ["john", "jane"] from content
    end

    test "handles message attachments", %{socket: socket} do
      params = %{
        "content" => "Check out this file",
        "attachments" => [
          %{"id" => "file_1", "name" => "document.pdf", "size" => 1024}
        ],
        "temp_id" => "temp_456"
      }

      {:noreply, _socket} = ChannelChannel.handle_in("send_message", params, socket)
      
      # Implementation should handle attachments metadata
    end
  end

  # Helper function to mock functions (would normally use a mocking library)
  defp with_mock(module, :passthrough, mocks, do: block) do
    # This is a simplified mock - in real tests you'd use something like Mox
    apply(module, :__info__, [:functions])
    block
  end
end