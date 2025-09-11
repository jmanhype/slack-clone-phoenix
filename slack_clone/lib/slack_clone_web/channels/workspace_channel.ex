defmodule SlackCloneWeb.WorkspaceChannel do
  @moduledoc """
  WebSocket channel for workspace-level real-time communication.
  Handles workspace events, user presence, and cross-channel notifications.
  """
  use SlackCloneWeb, :channel

  alias SlackClone.PubSub
  alias SlackCloneWeb.Presence

  @impl true
  def join("workspace:" <> workspace_id, params, socket) do
    user = socket.assigns.current_user
    
    # Verify user has access to workspace
    case authorize_workspace_access(workspace_id, user) do
      {:ok, workspace} ->
        # Track user presence in workspace
        send(self(), :after_join)
        
        socket = 
          socket
          |> assign(:workspace_id, workspace_id)
          |> assign(:workspace, workspace)

        {:ok, %{workspace: workspace, user: user}, socket}
      
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user = socket.assigns.current_user
    workspace_id = socket.assigns.workspace_id
    
    # Track presence
    {:ok, _} = Presence.track(socket, user.id, %{
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url,
      status: "online",
      joined_at: System.system_time(:second)
    })

    # Subscribe to workspace events
    PubSub.subscribe_to_workspace(workspace_id)

    # Send current workspace state
    push(socket, "workspace_state", %{
      channels: load_workspace_channels(workspace_id),
      online_users: Presence.list(socket)
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("user_status_change", %{"status" => status}, socket) do
    user_id = socket.assigns.current_user.id
    workspace_id = socket.assigns.workspace_id

    # Update presence with new status
    {:ok, _} = Presence.update(socket, user_id, fn meta ->
      %{meta | status: status, updated_at: System.system_time(:second)}
    end)

    # Broadcast status change
    PubSub.broadcast_user_status_change(workspace_id, user_id, status)

    {:noreply, socket}
  end

  def handle_in("create_channel", %{"name" => name, "description" => description, "type" => type}, socket) do
    user = socket.assigns.current_user
    workspace_id = socket.assigns.workspace_id

    case create_channel(workspace_id, %{
      name: name,
      description: description,
      type: type,
      created_by: user.id
    }) do
      {:ok, channel} ->
        # Broadcast new channel to workspace
        PubSub.broadcast_channel_created(workspace_id, channel)
        
        push(socket, "channel_created", %{channel: channel})
        {:noreply, socket}

      {:error, changeset} ->
        push(socket, "error", %{
          event: "create_channel",
          errors: format_changeset_errors(changeset)
        })
        {:noreply, socket}
    end
  end

  def handle_in("join_channel", %{"channel_id" => channel_id}, socket) do
    user = socket.assigns.current_user
    workspace_id = socket.assigns.workspace_id

    case join_channel(channel_id, user.id) do
      {:ok, membership} ->
        # Join the channel's Phoenix channel
        SlackCloneWeb.Endpoint.subscribe("channel:#{channel_id}")
        
        # Broadcast user joined event
        PubSub.broadcast_user_joined_channel(channel_id, workspace_id, user)
        
        push(socket, "channel_joined", %{
          channel_id: channel_id,
          membership: membership
        })
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "error", %{
          event: "join_channel",
          reason: reason
        })
        {:noreply, socket}
    end
  end

  def handle_in("leave_channel", %{"channel_id" => channel_id}, socket) do
    user_id = socket.assigns.current_user.id
    workspace_id = socket.assigns.workspace_id

    case leave_channel(channel_id, user_id) do
      {:ok, _} ->
        # Unsubscribe from channel events
        SlackCloneWeb.Endpoint.unsubscribe("channel:#{channel_id}")
        
        # Broadcast user left event
        PubSub.broadcast_user_left_channel(channel_id, workspace_id, user_id)
        
        push(socket, "channel_left", %{channel_id: channel_id})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "error", %{
          event: "leave_channel",
          reason: reason
        })
        {:noreply, socket}
    end
  end

  def handle_in("get_workspace_info", _params, socket) do
    workspace_id = socket.assigns.workspace_id
    
    info = %{
      channels: load_workspace_channels(workspace_id),
      members: load_workspace_members(workspace_id),
      online_users: Presence.list(socket),
      unread_counts: load_unread_counts(workspace_id, socket.assigns.current_user.id)
    }

    push(socket, "workspace_info", info)
    {:noreply, socket}
  end

  # Handle PubSub events from other parts of the system
  @impl true
  def handle_info({:new_message, message}, socket) do
    # Forward message notifications (for unread counts, etc.)
    push(socket, "new_message_notification", %{
      channel_id: message.channel_id,
      message_id: message.id,
      user_id: message.user_id
    })
    {:noreply, socket}
  end

  def handle_info({:channel_created, channel}, socket) do
    push(socket, "channel_created", %{channel: channel})
    {:noreply, socket}
  end

  def handle_info({:channel_updated, channel}, socket) do
    push(socket, "channel_updated", %{channel: channel})
    {:noreply, socket}
  end

  def handle_info({:channel_deleted, channel_data}, socket) do
    push(socket, "channel_deleted", channel_data)
    {:noreply, socket}
  end

  def handle_info({:user_status_change, status_data}, socket) do
    push(socket, "user_status_change", status_data)
    {:noreply, socket}
  end

  def handle_info({:workspace_updated, workspace}, socket) do
    push(socket, "workspace_updated", %{workspace: workspace})
    {:noreply, socket}
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    push(socket, "presence_diff", diff)
    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    # Clean up any resources
    workspace_id = socket.assigns[:workspace_id]
    if workspace_id do
      PubSub.unsubscribe_from_workspace(workspace_id)
    end
    
    :ok
  end

  # Private helper functions
  
  defp authorize_workspace_access(workspace_id, user) do
    # Mock authorization - replace with actual workspace membership check
    case workspace_id do
      "unauthorized" -> {:error, "Access denied"}
      _ -> {:ok, %{id: workspace_id, name: "Mock Workspace"}}
    end
  end

  defp load_workspace_channels(workspace_id) do
    # Mock channels - replace with actual data loading
    [
      %{
        id: "general",
        name: "general",
        description: "General discussion",
        type: "public",
        workspace_id: workspace_id,
        member_count: 5
      },
      %{
        id: "random",
        name: "random",
        description: "Random stuff",
        type: "public", 
        workspace_id: workspace_id,
        member_count: 3
      }
    ]
  end

  defp load_workspace_members(workspace_id) do
    # Mock members - replace with actual data loading
    [
      %{id: "user_1", name: "John Doe", email: "john@example.com", role: "admin"},
      %{id: "user_2", name: "Jane Smith", email: "jane@example.com", role: "member"}
    ]
  end

  defp load_unread_counts(workspace_id, user_id) do
    # Mock unread counts - replace with actual data loading
    %{
      "general" => 0,
      "random" => 2
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # Mock functions - replace with actual implementations
  defp create_channel(_workspace_id, _params), do: {:error, :not_implemented}
  defp join_channel(_channel_id, _user_id), do: {:error, :not_implemented}
  defp leave_channel(_channel_id, _user_id), do: {:error, :not_implemented}
end