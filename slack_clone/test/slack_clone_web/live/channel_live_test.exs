defmodule SlackCloneWeb.ChannelLiveTest do
  @moduledoc """
  Comprehensive LiveView testing for channel components using London School TDD approach.
  
  Tests component interactions, real-time updates, form submissions, and navigation flows
  with extensive mock verification of collaborator behavior. Focuses on how LiveView
  components collaborate with external services rather than testing internal state.
  """
  
  use SlackCloneWeb.ConnCase
  use SlackCloneWeb.ChannelCase

  import Phoenix.LiveViewTest
  import Mox
  import SlackClone.Factory

  alias SlackClone.Messages.Message
  alias SlackClone.Channels.Channel
  alias SlackCloneWeb.ChannelLive.Show

  # Mock external dependencies following London School approach
  setup :verify_on_exit!
  setup :set_mox_from_context

  describe "Channel LiveView - Mount and Initial Display" do
    setup do
      workspace = build(:workspace, id: "workspace-id")
      channel = build(:channel, 
        id: "channel-id",
        name: "general",
        description: "General discussion",
        workspace: workspace
      )
      user = build(:user, id: "user-id", email: "test@example.com")
      
      %{workspace: workspace, channel: channel, user: user}
    end

    test "mounts channel view with proper service interactions", %{conn: conn, channel: channel, user: user} do
      # Mock the collaborators - focusing on behavior verification
      MockChannels
      |> expect(:get_channel_with_workspace, fn "channel-id" ->
        {:ok, channel}
      end)
      |> expect(:list_channel_members, fn "channel-id" ->
        {:ok, [user]}
      end)

      MockMessages
      |> expect(:list_recent_messages, fn "channel-id", %{limit: 50, user_id: "user-id"} ->
        {:ok, []}
      end)

      MockPresence
      |> expect(:list_presence, fn "channel:channel-id" ->
        %{"user-id" => %{metas: [%{online_at: DateTime.utc_now()}]}}
      end)

      conn = log_in_user(conn, user)
      
      {:ok, view, html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Verify the view displays channel information
      assert html =~ "# #{channel.name}"
      assert html =~ channel.description
      assert html =~ "1 member"
      
      # Verify presence of key interactive elements
      assert has_element?(view, "form[phx-submit='send_message']")
      assert has_element?(view, "textarea[name='message[content]']")
      assert has_element?(view, "[data-testid='member-list']")
    end

    test "handles channel not found gracefully", %{conn: conn, user: user} do
      MockChannels
      |> expect(:get_channel_with_workspace, fn "nonexistent" ->
        {:error, :not_found}
      end)

      conn = log_in_user(conn, user)
      
      assert {:error, {:live_redirect, %{to: "/workspaces"}}} = 
        live(conn, ~p"/channels/nonexistent")
    end

    test "redirects unauthorized users", %{conn: conn, channel: channel, user: user} do
      MockChannels
      |> expect(:get_channel_with_workspace, fn "channel-id" ->
        {:ok, channel}
      end)

      MockAuthz
      |> expect(:can_view_channel?, fn ^user, ^channel ->
        false
      end)

      conn = log_in_user(conn, user)
      
      assert {:error, {:live_redirect, %{to: "/unauthorized"}}} = 
        live(conn, ~p"/channels/#{channel.id}")
    end
  end

  describe "Channel LiveView - Message Interactions" do
    setup do
      workspace = build(:workspace, id: "workspace-id")
      channel = build(:channel, id: "channel-id", workspace: workspace)
      user = build(:user, id: "user-id")
      
      # Setup successful mount mocks
      MockChannels
      |> stub(:get_channel_with_workspace, fn _ -> {:ok, channel} end)
      |> stub(:list_channel_members, fn _ -> {:ok, [user]} end)
      
      MockMessages
      |> stub(:list_recent_messages, fn _, _ -> {:ok, []} end)
      
      MockPresence
      |> stub(:list_presence, fn _ -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)
      
      %{workspace: workspace, channel: channel, user: user}
    end

    test "sends new message with proper service collaboration", %{conn: conn, channel: channel, user: user} do
      message_content = "Hello everyone!"
      new_message = build(:message, 
        id: "message-id",
        content: message_content,
        user: user,
        channel: channel
      )

      # Mock the message creation workflow
      MockMessages
      |> expect(:create_message, fn %{
        content: ^message_content,
        user_id: "user-id",
        channel_id: "channel-id"
      } ->
        {:ok, new_message}
      end)

      # Mock the broadcasting behavior
      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub, 
        "channel:channel-id", 
        {:new_message, ^new_message} ->
        :ok
      end)

      # Mock notification services
      MockNotifications
      |> expect(:notify_message_mentions, fn ^new_message ->
        :ok
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Send message via form submission
      result = view
      |> form("form[phx-submit='send_message']", %{
        "message" => %{"content" => message_content}
      })
      |> render_submit()
      
      # Verify message was processed (form should be cleared)
      assert result =~ "value=\"\"" # Empty textarea value
      
      # Verify the LiveView received the broadcast and updated
      send(view.pid, {:new_message, new_message})
      
      assert render(view) =~ message_content
      assert has_element?(view, "[data-message-id='message-id']")
    end

    test "handles message creation failure appropriately", %{conn: conn, channel: channel, user: user} do
      MockMessages
      |> expect(:create_message, fn _ ->
        {:error, %Ecto.Changeset{errors: [content: {"can't be blank", []}]}}
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      result = view
      |> form("form[phx-submit='send_message']", %{
        "message" => %{"content" => ""}
      })
      |> render_submit()
      
      # Should display error message
      assert result =~ "can&#39;t be blank"
      # Should not broadcast anything (no PubSub mock expectations)
    end

    test "handles real-time message updates via PubSub", %{conn: conn, channel: channel, user: user} do
      other_user = build(:user, id: "other-user-id", username: "otheruser")
      incoming_message = build(:message,
        id: "incoming-message-id",
        content: "Message from another user",
        user: other_user,
        channel: channel
      )

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Simulate receiving broadcast message
      send(view.pid, {:new_message, incoming_message})
      
      # Verify the message appears in the view
      updated_html = render(view)
      assert updated_html =~ "Message from another user"
      assert updated_html =~ "otheruser"
      assert has_element?(view, "[data-message-id='incoming-message-id']")
    end

    test "shows typing indicators with presence updates", %{conn: conn, channel: channel, user: user} do
      MockPresence
      |> expect(:track, fn 
        view_pid, "channel:channel-id", "user-id", %{typing: true} ->
        :ok
      end)
      |> expect(:update, fn
        view_pid, "channel:channel-id", "user-id", %{typing: false} ->
        :ok
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Simulate typing start
      render_hook(view, "typing_start", %{})
      
      # Simulate typing stop
      render_hook(view, "typing_stop", %{})
      
      # Verify presence was updated (mocks verify the calls)
    end
  end

  describe "Channel LiveView - Message Threading" do
    setup do
      workspace = build(:workspace, id: "workspace-id")
      channel = build(:channel, id: "channel-id", workspace: workspace)
      user = build(:user, id: "user-id")
      parent_message = build(:message, 
        id: "parent-message-id",
        content: "Original message",
        user: user,
        channel: channel
      )
      
      # Standard mount mocks
      MockChannels
      |> stub(:get_channel_with_workspace, fn _ -> {:ok, channel} end)
      |> stub(:list_channel_members, fn _ -> {:ok, [user]} end)
      
      MockMessages
      |> stub(:list_recent_messages, fn _, _ -> {:ok, [parent_message]} end)
      
      MockPresence
      |> stub(:list_presence, fn _ -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)
      
      %{workspace: workspace, channel: channel, user: user, parent_message: parent_message}
    end

    test "opens thread view for message", %{conn: conn, channel: channel, user: user, parent_message: parent_message} do
      MockMessages
      |> expect(:get_thread_messages, fn "parent-message-id" ->
        {:ok, []}
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Click reply button to open thread
      result = view
      |> element("[data-message-id='parent-message-id'] button[phx-click='open_thread']")
      |> render_click(%{"message_id" => "parent-message-id"})
      
      # Should show thread view
      assert result =~ "Thread"
      assert result =~ "Reply to thread"
      assert has_element?(view, "[data-testid='thread-view']")
    end

    test "sends threaded reply with proper service collaboration", %{conn: conn, channel: channel, user: user, parent_message: parent_message} do
      reply_content = "This is a threaded reply"
      thread_reply = build(:message,
        id: "reply-message-id",
        content: reply_content,
        user: user,
        channel: channel,
        thread_id: "parent-message-id"
      )

      MockMessages
      |> expect(:get_thread_messages, fn "parent-message-id" -> {:ok, []} end)
      |> expect(:create_thread_reply, fn %{
        content: ^reply_content,
        user_id: "user-id",
        channel_id: "channel-id",
        thread_id: "parent-message-id"
      } ->
        {:ok, thread_reply}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "thread:parent-message-id",
        {:new_thread_reply, ^thread_reply} ->
        :ok
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Open thread first
      view
      |> element("[data-message-id='parent-message-id'] button[phx-click='open_thread']")
      |> render_click(%{"message_id" => "parent-message-id"})
      
      # Send threaded reply
      result = view
      |> form("form[phx-submit='send_thread_reply']", %{
        "message" => %{"content" => reply_content, "thread_id" => "parent-message-id"}
      })
      |> render_submit()
      
      # Verify thread reply was processed
      assert result =~ reply_content
      assert has_element?(view, "[data-message-id='reply-message-id']")
    end
  end

  describe "Channel LiveView - Message Reactions" do
    setup do
      workspace = build(:workspace, id: "workspace-id")
      channel = build(:channel, id: "channel-id", workspace: workspace)
      user = build(:user, id: "user-id")
      message = build(:message, 
        id: "message-id",
        content: "React to this!",
        user: user,
        channel: channel
      )
      
      # Standard mount mocks
      MockChannels
      |> stub(:get_channel_with_workspace, fn _ -> {:ok, channel} end)
      |> stub(:list_channel_members, fn _ -> {:ok, [user]} end)
      
      MockMessages
      |> stub(:list_recent_messages, fn _, _ -> {:ok, [message]} end)
      
      MockPresence
      |> stub(:list_presence, fn _ -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)
      
      %{workspace: workspace, channel: channel, user: user, message: message}
    end

    test "adds reaction to message with service collaboration", %{conn: conn, channel: channel, user: user, message: message} do
      reaction = build(:reaction,
        emoji: "👍",
        user: user,
        message: message
      )

      MockReactions
      |> expect(:add_reaction, fn %{
        emoji: "👍",
        user_id: "user-id",
        message_id: "message-id"
      } ->
        {:ok, reaction}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:channel-id",
        {:reaction_added, ^reaction} ->
        :ok
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Add reaction by clicking emoji
      result = view
      |> element("[data-message-id='message-id'] button[phx-click='add_reaction']")
      |> render_click(%{"emoji" => "👍", "message_id" => "message-id"})
      
      # Verify reaction was added
      send(view.pid, {:reaction_added, reaction})
      updated_html = render(view)
      assert updated_html =~ "👍"
      assert has_element?(view, "[data-reaction-emoji='👍']")
    end

    test "removes reaction when clicked again", %{conn: conn, channel: channel, user: user, message: message} do
      MockReactions
      |> expect(:remove_reaction, fn %{
        emoji: "👍",
        user_id: "user-id", 
        message_id: "message-id"
      } ->
        :ok
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:channel-id",
        {:reaction_removed, %{emoji: "👍", message_id: "message-id", user_id: "user-id"}} ->
        :ok
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Remove reaction
      result = view
      |> element("[data-message-id='message-id'] button[phx-click='remove_reaction']")
      |> render_click(%{"emoji" => "👍", "message_id" => "message-id"})
      
      # Verify reaction was removed
      send(view.pid, {:reaction_removed, %{emoji: "👍", message_id: "message-id", user_id: "user-id"}})
      updated_html = render(view)
      refute updated_html =~ "👍"
    end
  end

  describe "Channel LiveView - File Uploads and Attachments" do
    setup do
      workspace = build(:workspace, id: "workspace-id")
      channel = build(:channel, id: "channel-id", workspace: workspace)
      user = build(:user, id: "user-id")
      
      # Standard mount mocks
      MockChannels
      |> stub(:get_channel_with_workspace, fn _ -> {:ok, channel} end)
      |> stub(:list_channel_members, fn _ -> {:ok, [user]} end)
      
      MockMessages
      |> stub(:list_recent_messages, fn _, _ -> {:ok, []} end)
      
      MockPresence
      |> stub(:list_presence, fn _ -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)
      
      %{workspace: workspace, channel: channel, user: user}
    end

    test "uploads file with message using file service collaboration", %{conn: conn, channel: channel, user: user} do
      file_upload = %{
        "name" => "document.pdf",
        "size" => 1024,
        "type" => "application/pdf"
      }
      
      uploaded_file = build(:file_attachment,
        id: "file-id",
        filename: "document.pdf",
        file_size: 1024,
        content_type: "application/pdf"
      )
      
      message_with_file = build(:message,
        id: "message-with-file-id",
        content: "Here's the document",
        user: user,
        channel: channel,
        attachments: [uploaded_file]
      )

      MockFileUpload
      |> expect(:upload_file, fn ^file_upload, "user-id" ->
        {:ok, uploaded_file}
      end)

      MockMessages
      |> expect(:create_message_with_attachments, fn %{
        content: "Here's the document",
        user_id: "user-id",
        channel_id: "channel-id",
        attachment_ids: ["file-id"]
      } ->
        {:ok, message_with_file}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:channel-id",
        {:new_message, ^message_with_file} ->
        :ok
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Upload file
      result = view
      |> form("form[phx-submit='send_message']", %{
        "message" => %{"content" => "Here's the document"},
        "file_upload" => file_upload
      })
      |> render_submit()
      
      # Verify file upload was processed
      send(view.pid, {:new_message, message_with_file})
      updated_html = render(view)
      assert updated_html =~ "document.pdf"
      assert has_element?(view, "[data-attachment-id='file-id']")
    end

    test "handles file upload errors gracefully", %{conn: conn, channel: channel, user: user} do
      file_upload = %{
        "name" => "huge_file.pdf",
        "size" => 50_000_000, # 50MB
        "type" => "application/pdf"
      }

      MockFileUpload
      |> expect(:upload_file, fn ^file_upload, "user-id" ->
        {:error, :file_too_large}
      end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      result = view
      |> form("form[phx-submit='send_message']", %{
        "message" => %{"content" => "Big file"},
        "file_upload" => file_upload
      })
      |> render_submit()
      
      # Should show error message
      assert result =~ "File too large"
      # Should not create message (no Messages mock expectation)
    end
  end

  describe "Channel LiveView - Navigation and State Management" do
    setup do
      workspace = build(:workspace, id: "workspace-id")
      channel1 = build(:channel, id: "channel1-id", name: "general", workspace: workspace)
      channel2 = build(:channel, id: "channel2-id", name: "random", workspace: workspace)
      user = build(:user, id: "user-id")
      
      %{workspace: workspace, channel1: channel1, channel2: channel2, user: user}
    end

    test "navigates between channels preserving state", %{conn: conn, channel1: channel1, channel2: channel2, user: user} do
      # Mock for first channel
      MockChannels
      |> expect(:get_channel_with_workspace, fn "channel1-id" -> {:ok, channel1} end)
      |> expect(:list_channel_members, fn "channel1-id" -> {:ok, [user]} end)
      |> expect(:get_channel_with_workspace, fn "channel2-id" -> {:ok, channel2} end)
      |> expect(:list_channel_members, fn "channel2-id" -> {:ok, [user]} end)
      
      MockMessages
      |> expect(:list_recent_messages, fn "channel1-id", _ -> {:ok, []} end)
      |> expect(:list_recent_messages, fn "channel2-id", _ -> {:ok, []} end)
      
      MockPresence
      |> expect(:list_presence, fn "channel:channel1-id" -> %{} end)
      |> expect(:list_presence, fn "channel:channel2-id" -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/channels/#{channel1.id}")
      
      # Verify we're in the first channel
      assert html =~ "# general"
      
      # Navigate to second channel
      {:ok, view2, html2} = view |> element("a", "random") |> render_click()
      |> follow_redirect(conn)
      
      # Verify navigation to second channel
      assert html2 =~ "# random"
      
      # Verify the view maintains proper state
      assert view2.pid != view.pid # New LiveView process
    end

    test "handles deep linking to specific message thread", %{conn: conn, channel1: channel1, user: user} do
      parent_message = build(:message, id: "parent-id", channel: channel1, user: user)
      thread_messages = build_list(3, :message, thread_id: "parent-id", channel: channel1, user: user)

      MockChannels
      |> expect(:get_channel_with_workspace, fn "channel1-id" -> {:ok, channel1} end)
      |> expect(:list_channel_members, fn "channel1-id" -> {:ok, [user]} end)
      
      MockMessages
      |> expect(:list_recent_messages, fn "channel1-id", _ -> {:ok, [parent_message]} end)
      |> expect(:get_thread_messages, fn "parent-id" -> {:ok, thread_messages} end)
      
      MockPresence
      |> expect(:list_presence, fn "channel:channel1-id" -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)

      conn = log_in_user(conn, user)
      
      # Navigate with thread parameter
      {:ok, view, html} = live(conn, ~p"/channels/#{channel1.id}?thread=parent-id")
      
      # Should automatically open the thread
      assert html =~ "Thread"
      assert length(Enum.filter(String.split(html, "\n"), &(&1 =~ "data-message-id"))) == 4 # parent + 3 replies
      assert has_element?(view, "[data-testid='thread-view']")
    end

    test "maintains scroll position during real-time updates", %{conn: conn, channel1: channel1, user: user} do
      existing_messages = build_list(20, :message, channel: channel1, user: user)

      MockChannels
      |> stub(:get_channel_with_workspace, fn "channel1-id" -> {:ok, channel1} end)
      |> stub(:list_channel_members, fn "channel1-id" -> {:ok, [user]} end)
      
      MockMessages
      |> stub(:list_recent_messages, fn "channel1-id", _ -> {:ok, existing_messages} end)
      
      MockPresence
      |> stub(:list_presence, fn "channel:channel1-id" -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel1.id}")
      
      # Simulate scrolling to a specific position
      render_hook(view, "scroll_position_changed", %{"scroll_top" => 500})
      
      # Simulate new message arriving
      new_message = build(:message, channel: channel1, user: user)
      send(view.pid, {:new_message, new_message})
      
      updated_html = render(view)
      
      # Should preserve scroll position (verify scroll restoration script)
      assert updated_html =~ "scrollTop = 500"
    end
  end

  describe "Channel LiveView - Error Handling and Edge Cases" do
    setup do
      workspace = build(:workspace, id: "workspace-id")
      channel = build(:channel, id: "channel-id", workspace: workspace)
      user = build(:user, id: "user-id")
      
      %{workspace: workspace, channel: channel, user: user}
    end

    test "handles network connectivity issues gracefully", %{conn: conn, channel: channel, user: user} do
      MockChannels
      |> expect(:get_channel_with_workspace, fn "channel-id" -> {:ok, channel} end)
      |> expect(:list_channel_members, fn "channel-id" -> {:ok, [user]} end)
      
      MockMessages
      |> expect(:list_recent_messages, fn "channel-id", _ -> {:ok, []} end)
      |> expect(:create_message, fn _ -> {:error, :network_timeout} end)
      
      MockPresence
      |> stub(:list_presence, fn _ -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Attempt to send message during network issue
      result = view
      |> form("form[phx-submit='send_message']", %{
        "message" => %{"content" => "Test message"}
      })
      |> render_submit()
      
      # Should show network error message
      assert result =~ "Connection error"
      assert result =~ "retry"
      assert has_element?(view, "[data-testid='network-error']")
    end

    test "handles rapid message sending with rate limiting", %{conn: conn, channel: channel, user: user} do
      MockChannels
      |> stub(:get_channel_with_workspace, fn "channel-id" -> {:ok, channel} end)
      |> stub(:list_channel_members, fn "channel-id" -> {:ok, [user]} end)
      
      MockMessages
      |> stub(:list_recent_messages, fn "channel-id", _ -> {:ok, []} end)
      |> expect(:create_message, fn _ -> {:ok, build(:message)} end)
      |> expect(:create_message, fn _ -> {:error, :rate_limited} end)
      
      MockPresence
      |> stub(:list_presence, fn _ -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)

      MockPubSub
      |> stub(:broadcast, fn _, _, _ -> :ok end)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Send first message (succeeds)
      view
      |> form("form[phx-submit='send_message']", %{
        "message" => %{"content" => "First message"}
      })
      |> render_submit()
      
      # Send second message immediately (rate limited)
      result = view
      |> form("form[phx-submit='send_message']", %{
        "message" => %{"content" => "Second message"}
      })
      |> render_submit()
      
      # Should show rate limiting message
      assert result =~ "slow down"
      assert has_element?(view, "[data-testid='rate-limit-warning']")
    end

    test "recovers from temporary service failures", %{conn: conn, channel: channel, user: user} do
      MockChannels
      |> expect(:get_channel_with_workspace, fn "channel-id" -> {:ok, channel} end)
      |> expect(:list_channel_members, fn "channel-id" -> {:ok, [user]} end)
      
      MockMessages
      |> expect(:list_recent_messages, fn "channel-id", _ -> {:error, :service_unavailable} end)
      |> expect(:list_recent_messages, fn "channel-id", _ -> {:ok, []} end) # Recovery attempt
      
      MockPresence
      |> stub(:list_presence, fn _ -> %{} end)

      MockAuthz
      |> stub(:can_view_channel?, fn _, _ -> true end)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/channels/#{channel.id}")
      
      # Should show service unavailable message initially
      assert html =~ "Service temporarily unavailable"
      assert has_element?(view, "button[phx-click='retry_load_messages']")
      
      # Click retry button
      result = view
      |> element("button[phx-click='retry_load_messages']")
      |> render_click()
      
      # Should successfully load after retry
      assert result =~ "Messages loaded"
      refute result =~ "Service temporarily unavailable"
    end
  end

  # Helper function for user authentication
  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Guardian.Plug.sign_in(user)
    |> assign(:current_user, user)
  end
end