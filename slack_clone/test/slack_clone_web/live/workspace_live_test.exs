defmodule SlackCloneWeb.WorkspaceLiveTest do
  @moduledoc """
  LiveView testing for workspace components following London School TDD.
  Tests component interactions, real-time updates, form submissions, and navigation flows.
  """
  
  use SlackCloneWeb.ConnCase
  
  import Phoenix.LiveViewTest
  import SlackClone.Factory
  import Mox
  
  alias SlackClone.{Workspaces, Channels, Messages, Accounts}
  alias SlackClone.Workspaces.Workspace
  alias SlackCloneWeb.WorkspaceLive.Index
  
  # Setup mocks for LiveView dependencies
  setup :verify_on_exit!
  setup :set_mox_from_context
  
  setup %{conn: conn} do
    user = insert(:user)
    workspace = insert(:workspace, owner: user)
    channel = insert(:channel, workspace: workspace, creator: user)
    
    # Mock workspace membership
    MockRepo
    |> stub(:get_by, fn 
      Workspace, [id: workspace_id, slug: slug] when workspace_id == workspace.id -> 
        %{workspace | slug: slug}
      _, _ -> nil
    end)
    |> stub(:preload, fn workspace, [:owner, :channels] -> 
      %{workspace | owner: user, channels: [channel]}
    end)
    
    conn = 
      conn
      |> log_in_user(user)
      |> assign(:current_workspace, workspace)
    
    %{conn: conn, user: user, workspace: workspace, channel: channel}
  end
  
  describe "workspace index page" do
    test "displays workspace name and channel list", %{conn: conn, workspace: workspace, channel: channel} do
      MockWorkspaces
      |> expect(:get_workspace_with_channels, fn workspace_id ->
        {:ok, %{workspace | channels: [channel]}}
      end)
      
      {:ok, _index_live, html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      assert html =~ workspace.name
      assert html =~ channel.name
      assert html =~ "data-testid=\"workspace-header\""
      assert html =~ "data-testid=\"channel-list\""
    end
    
    test "shows loading state during workspace fetch", %{conn: conn, workspace: workspace} do
      # Simulate slow workspace loading
      MockWorkspaces
      |> expect(:get_workspace_with_channels, fn _workspace_id ->
        Process.sleep(100)
        {:ok, workspace}
      end)
      
      {:ok, index_live, html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Should show loading indicator initially
      assert html =~ "data-testid=\"loading-spinner\""
      
      # Wait for loading to complete
      assert render(index_live) =~ workspace.name
      refute render(index_live) =~ "data-testid=\"loading-spinner\""
    end
    
    test "handles workspace not found error gracefully", %{conn: conn} do
      MockWorkspaces
      |> expect(:get_workspace_with_channels, fn _workspace_id ->
        {:error, :not_found}
      end)
      
      {:ok, _index_live, html} = live(conn, ~p"/workspaces/non-existent-workspace")
      
      assert html =~ "Workspace not found"
      assert html =~ "data-testid=\"error-message\""
    end
  end
  
  describe "channel navigation" do
    test "navigates to channel when clicked", %{conn: conn, workspace: workspace, channel: channel} do
      MockChannels
      |> expect(:get_channel_with_messages, fn channel_id ->
        {:ok, %{channel | messages: []}}
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Click on channel in sidebar
      index_live
      |> element("[data-testid=\"channel-link-#{channel.id}\"]")
      |> render_click()
      
      # Should navigate to channel view
      assert_patch(index_live, ~p"/workspaces/#{workspace.slug}/channels/#{channel.id}")
    end
    
    test "updates active channel in sidebar", %{conn: conn, workspace: workspace, channel: channel} do
      another_channel = insert(:channel, workspace: workspace)
      
      MockChannels
      |> expect(:get_channel_with_messages, 2, fn _channel_id ->
        {:ok, %{channel | messages: []}}
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Click on first channel
      index_live
      |> element("[data-testid=\"channel-link-#{channel.id}\"]")
      |> render_click()
      
      assert has_element?(index_live, "[data-testid=\"channel-link-#{channel.id}\"][aria-current=\"page\"]")
      
      # Click on second channel
      index_live
      |> element("[data-testid=\"channel-link-#{another_channel.id}\"]")
      |> render_click()
      
      assert has_element?(index_live, "[data-testid=\"channel-link-#{another_channel.id}\"][aria-current=\"page\"]")
      refute has_element?(index_live, "[data-testid=\"channel-link-#{channel.id}\"][aria-current=\"page\"]")
    end
    
    test "persists channel selection across page refreshes", %{conn: conn, workspace: workspace, channel: channel} do
      MockChannels
      |> expect(:get_channel_with_messages, fn _channel_id ->
        {:ok, %{channel | messages: []}}
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Navigate to specific channel
      index_live
      |> element("[data-testid=\"channel-link-#{channel.id}\"]")
      |> render_click()
      
      # Simulate page refresh by creating new LiveView
      {:ok, _new_live, html} = live(conn, ~p"/workspaces/#{workspace.slug}/channels/#{channel.id}")
      
      assert html =~ channel.name
      assert html =~ "data-testid=\"channel-messages\""
    end
  end
  
  describe "channel creation form" do
    test "shows create channel modal when button clicked", %{conn: conn, workspace: workspace} do
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Click create channel button
      index_live
      |> element("[data-testid=\"create-channel-button\"]")
      |> render_click()
      
      assert has_element?(index_live, "[data-testid=\"create-channel-modal\"]")
      assert has_element?(index_live, "form[phx-submit=\"create_channel\"]")
    end
    
    test "successfully creates new channel via form submission", %{conn: conn, workspace: workspace, user: user} do
      new_channel = build(:channel, workspace: workspace, creator: user)
      
      MockChannels
      |> expect(:create_channel, fn channel_attrs ->
        assert channel_attrs.name == new_channel.name
        assert channel_attrs.workspace_id == workspace.id
        assert channel_attrs.creator_id == user.id
        {:ok, new_channel}
      end)
      |> expect(:broadcast_channel_created, fn created_channel ->
        assert created_channel.id == new_channel.id
        :ok
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Open create channel modal
      index_live
      |> element("[data-testid=\"create-channel-button\"]")
      |> render_click()
      
      # Submit form with channel data
      index_live
      |> form("[data-testid=\"create-channel-form\"]", channel: %{
        name: new_channel.name,
        description: new_channel.description,
        is_private: false
      })
      |> render_submit()
      
      # Should close modal and show success message
      refute has_element?(index_live, "[data-testid=\"create-channel-modal\"]")
      assert has_element?(index_live, "[data-testid=\"success-flash\"]")
      
      # Should add channel to sidebar
      assert has_element?(index_live, "[data-testid=\"channel-link-#{new_channel.id}\"]")
    end
    
    test "shows validation errors for invalid channel data", %{conn: conn, workspace: workspace} do
      MockChannels
      |> expect(:create_channel, fn _channel_attrs ->
        {:error, %Ecto.Changeset{
          errors: [name: {"can't be blank", [validation: :required]}],
          valid?: false
        }}
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Open modal and submit invalid form
      index_live
      |> element("[data-testid=\"create-channel-button\"]")
      |> render_click()
      
      index_live
      |> form("[data-testid=\"create-channel-form\"]", channel: %{
        name: "",  # Invalid: empty name
        description: "Test description"
      })
      |> render_submit()
      
      # Should keep modal open with error message
      assert has_element?(index_live, "[data-testid=\"create-channel-modal\"]")
      assert has_element?(index_live, "[data-testid=\"field-error\"]", "can't be blank")
    end
    
    test "cancels channel creation and closes modal", %{conn: conn, workspace: workspace} do
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Open modal
      index_live
      |> element("[data-testid=\"create-channel-button\"]")
      |> render_click()
      
      assert has_element?(index_live, "[data-testid=\"create-channel-modal\"]")
      
      # Click cancel button
      index_live
      |> element("[data-testid=\"cancel-channel-creation\"]")
      |> render_click()
      
      # Should close modal
      refute has_element?(index_live, "[data-testid=\"create-channel-modal\"]")
    end
  end
  
  describe "real-time workspace updates" do
    test "adds new channel to sidebar when created by another user", %{conn: conn, workspace: workspace} do
      new_channel = insert(:channel, workspace: workspace)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Simulate channel created by another user via PubSub
      send(index_live.pid, %Phoenix.Socket.Broadcast{
        topic: "workspace:#{workspace.id}",
        event: "channel_created",
        payload: %{channel: new_channel}
      })
      
      # Should add new channel to sidebar
      assert render(index_live) =~ new_channel.name
      assert has_element?(index_live, "[data-testid=\"channel-link-#{new_channel.id}\"]")
    end
    
    test "removes channel from sidebar when deleted", %{conn: conn, workspace: workspace, channel: channel} do
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Verify channel is initially present
      assert has_element?(index_live, "[data-testid=\"channel-link-#{channel.id}\"]")
      
      # Simulate channel deletion via PubSub
      send(index_live.pid, %Phoenix.Socket.Broadcast{
        topic: "workspace:#{workspace.id}",
        event: "channel_deleted",
        payload: %{channel_id: channel.id}
      })
      
      # Should remove channel from sidebar
      refute has_element?(index_live, "[data-testid=\"channel-link-#{channel.id}\"]")
    end
    
    test "updates channel name when renamed", %{conn: conn, workspace: workspace, channel: channel} do
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      new_name = "updated-channel-name"
      
      # Simulate channel rename via PubSub
      send(index_live.pid, %Phoenix.Socket.Broadcast{
        topic: "workspace:#{workspace.id}",
        event: "channel_updated",
        payload: %{channel: %{channel | name: new_name}}
      })
      
      # Should update channel name in sidebar
      assert render(index_live) =~ new_name
      refute render(index_live) =~ channel.name
    end
    
    test "shows user presence indicators in real-time", %{conn: conn, workspace: workspace, user: user} do
      other_user = insert(:user)
      
      MockPresence
      |> expect(:track_user_presence, fn workspace_id, user_id ->
        assert workspace_id == workspace.id
        assert user_id == other_user.id
        :ok
      end)
      |> expect(:list_workspace_presence, fn workspace_id ->
        assert workspace_id == workspace.id
        [%{user_id: user.id, status: "active"}, %{user_id: other_user.id, status: "active"}]
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Simulate user coming online via presence
      send(index_live.pid, %Phoenix.Socket.Broadcast{
        topic: "presence:workspace:#{workspace.id}",
        event: "presence_diff",
        payload: %{
          joins: %{other_user.id => %{status: "active"}},
          leaves: %{}
        }
      })
      
      # Should show presence indicator for online user
      assert has_element?(index_live, "[data-testid=\"user-presence-#{other_user.id}\"]")
      assert has_element?(index_live, "[data-status=\"active\"]")
    end
  end
  
  describe "workspace settings modal" do
    test "opens workspace settings when gear icon clicked", %{conn: conn, workspace: workspace} do
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      index_live
      |> element("[data-testid=\"workspace-settings-button\"]")
      |> render_click()
      
      assert has_element?(index_live, "[data-testid=\"workspace-settings-modal\"]")
      assert has_element?(index_live, "form[phx-submit=\"update_workspace\"]")
    end
    
    test "updates workspace settings successfully", %{conn: conn, workspace: workspace} do
      updated_workspace = %{workspace | name: "Updated Workspace Name"}
      
      MockWorkspaces
      |> expect(:update_workspace, fn workspace_id, attrs ->
        assert workspace_id == workspace.id
        assert attrs.name == "Updated Workspace Name"
        {:ok, updated_workspace}
      end)
      |> expect(:broadcast_workspace_updated, fn updated_ws ->
        assert updated_ws.id == workspace.id
        :ok
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Open settings modal
      index_live
      |> element("[data-testid=\"workspace-settings-button\"]")
      |> render_click()
      
      # Submit updated settings
      index_live
      |> form("[data-testid=\"workspace-settings-form\"]", workspace: %{
        name: "Updated Workspace Name",
        description: "New description"
      })
      |> render_submit()
      
      # Should close modal and update workspace name
      refute has_element?(index_live, "[data-testid=\"workspace-settings-modal\"]")
      assert render(index_live) =~ "Updated Workspace Name"
      assert has_element?(index_live, "[data-testid=\"success-flash\"]")
    end
    
    test "handles workspace update errors gracefully", %{conn: conn, workspace: workspace} do
      MockWorkspaces
      |> expect(:update_workspace, fn _workspace_id, _attrs ->
        {:error, %Ecto.Changeset{
          errors: [name: {"has already been taken", []}],
          valid?: false
        }}
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Open settings and submit invalid update
      index_live
      |> element("[data-testid=\"workspace-settings-button\"]")
      |> render_click()
      
      index_live
      |> form("[data-testid=\"workspace-settings-form\"]", workspace: %{
        name: "Duplicate Name"
      })
      |> render_submit()
      
      # Should keep modal open with error
      assert has_element?(index_live, "[data-testid=\"workspace-settings-modal\"]")
      assert has_element?(index_live, "[data-testid=\"field-error\"]", "has already been taken")
    end
  end
  
  describe "keyboard shortcuts" do
    test "opens channel creation modal with Ctrl+K", %{conn: conn, workspace: workspace} do
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Send keyboard shortcut event
      index_live
      |> element("body")
      |> render_hook("keydown", %{"key" => "k", "ctrlKey" => true})
      
      assert has_element?(index_live, "[data-testid=\"create-channel-modal\"]")
    end
    
    test "focuses message input with '/' key", %{conn: conn, workspace: workspace, channel: channel} do
      MockChannels
      |> expect(:get_channel_with_messages, fn _channel_id ->
        {:ok, %{channel | messages: []}}
      end)
      
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}/channels/#{channel.id}")
      
      # Send slash key to focus message input
      index_live
      |> element("body")
      |> render_hook("keydown", %{"key" => "/"})
      
      # Should focus the message input field
      assert has_element?(index_live, "[data-testid=\"message-input\"]:focus-within")
    end
  end
  
  describe "responsive design" do
    test "shows mobile menu button on small screens", %{conn: conn, workspace: workspace} do
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Simulate mobile viewport
      index_live
      |> element("body")
      |> render_hook("viewport_change", %{"width" => 375, "height" => 667})
      
      assert has_element?(index_live, "[data-testid=\"mobile-menu-button\"]")
    end
    
    test "toggles sidebar on mobile menu click", %{conn: conn, workspace: workspace} do
      {:ok, index_live, _html} = live(conn, ~p"/workspaces/#{workspace.slug}")
      
      # Simulate mobile viewport
      index_live
      |> element("body")
      |> render_hook("viewport_change", %{"width" => 375, "height" => 667})
      
      # Click mobile menu button
      index_live
      |> element("[data-testid=\"mobile-menu-button\"]")
      |> render_click()
      
      # Should show mobile sidebar
      assert has_element?(index_live, "[data-testid=\"sidebar\"][data-mobile-visible=\"true\"]")
      
      # Click again to hide
      index_live
      |> element("[data-testid=\"mobile-menu-button\"]")
      |> render_click()
      
      refute has_element?(index_live, "[data-testid=\"sidebar\"][data-mobile-visible=\"true\"]")
    end
  end
end