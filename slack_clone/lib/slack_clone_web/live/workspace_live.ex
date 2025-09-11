defmodule SlackCloneWeb.WorkspaceLive do
  @moduledoc """
  Main LiveView component for the workspace shell.
  Handles workspace-level real-time updates and presence tracking.
  """
  use SlackCloneWeb, :live_view
  on_mount {SlackCloneWeb.UserAuth, :mount_current_user}
  
  alias SlackClone.{Workspaces, Channels, Messages, Accounts}
  alias Phoenix.PubSub
  alias SlackCloneWeb.Presence

  @impl true
  def mount(%{"workspace_id" => workspace_id} = params, session, socket) do
    # Get current user from session
    current_user = case socket.assigns[:current_user] do
      nil -> 
        # If not already assigned, get from session
        case session["user_token"] do
          nil -> nil
          token -> SlackClone.Accounts.get_user_by_session_token(token)
        end
      user -> user
    end
    
    # Redirect to login if no user
    if !current_user do
      {:ok, 
       socket
       |> put_flash(:error, "You must log in to access this page.")
       |> redirect(to: ~p"/auth/login")}
    else
      workspace = Workspaces.get_workspace!(workspace_id)
      channels = Channels.list_workspace_channels(workspace.id)
      
      # Get channel from params or default to first channel
      channel = case params["channel_id"] do
        nil -> List.first(channels)
        channel_id -> Channels.get_channel!(channel_id)
      end
      
      # Subscribe to workspace and channel updates  
      if connected?(socket) do
        PubSub.subscribe(SlackClone.PubSub, "workspace:#{workspace_id}")
        if channel, do: PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}")
        
        # Track presence
        {:ok, _} = Presence.track(self(), "workspace:#{workspace_id}", current_user.id, %{
          online_at: inspect(System.system_time(:second)),
          user: current_user
        })
      end
    
      messages = if channel, do: Messages.list_channel_messages(channel.id), else: []
      
      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:workspace, workspace)
       |> assign(:workspace_id, workspace_id)
       |> assign(:channels, channels)
       |> assign(:current_channel, channel)
       |> assign(:current_channel_id, channel && channel.id)
       |> assign(:messages, messages)
       |> assign(:direct_messages, [])
       |> assign(:show_thread, false)
       |> assign(:thread_message, nil)
       |> assign(:show_emoji_picker, false)
       |> assign(:show_right_sidebar, false)
       |> assign(:right_sidebar_view, :info)
       |> assign(:composing_message, "")
       |> assign(:online_users, %{})
       |> assign(:typing_users, [])
       |> assign(:unread_counts, %{})
       |> assign(:show_new_channel, false)
       |> assign(:new_channel_changeset, %{name: "", description: ""})
       |> assign(:page_title, "#{workspace.name} - Slack")}
    end
  end

  @impl true
  def handle_params(%{"channel_id" => channel_id}, _url, socket) do
    if connected?(socket) do
      # Unsubscribe from previous channel if any
      if socket.assigns.current_channel_id do
        PubSub.unsubscribe(SlackClone.PubSub, "channel:#{socket.assigns.current_channel_id}")
      end

      # Subscribe to new channel
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel_id}")
    end
    
    channel = Channels.get_channel!(channel_id)
    messages = Messages.list_channel_messages(channel_id)

    socket =
      socket
      |> assign(:current_channel, channel)
      |> assign(:current_channel_id, channel_id)
      |> assign(:messages, messages)
      |> clear_unread_count(channel_id)

    {:noreply, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    socket = 
      if message.channel_id != socket.assigns.current_channel_id do
        increment_unread_count(socket, message.channel_id)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:channel_created, channel}, socket) do
    channels = [channel | socket.assigns.channels]
    {:noreply, assign(socket, :channels, channels)}
  end

  def handle_info({:channel_updated, channel}, socket) do
    channels = 
      Enum.map(socket.assigns.channels, fn c ->
        if c.id == channel.id, do: channel, else: c
      end)
    
    {:noreply, assign(socket, :channels, channels)}
  end

  def handle_info({:channel_deleted, %{id: channel_id}}, socket) do
    channels = Enum.reject(socket.assigns.channels, &(&1.id == channel_id))
    
    socket =
      socket
      |> assign(:channels, channels)
      |> maybe_redirect_from_deleted_channel(channel_id)

    {:noreply, socket}
  end

  def handle_info({:user_status_change, %{user_id: user_id, status: status}}, socket) do
    online_users = 
      Map.update(socket.assigns.online_users, user_id, %{status: status}, fn user ->
        %{user | status: status}
      end)

    {:noreply, assign(socket, :online_users, online_users)}
  end

  def handle_info({:presence_diff, diff}, socket) do
    socket = handle_presence_diff(socket, diff)
    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_channel", %{"channel-id" => channel_id}, socket) do
    # Unsubscribe from old channel
    if socket.assigns.current_channel_id do
      PubSub.unsubscribe(SlackClone.PubSub, "channel:#{socket.assigns.current_channel_id}")
    end
    
    # Subscribe to new channel
    channel = Channels.get_channel!(channel_id)
    PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}")
    
    messages = Messages.list_channel_messages(channel_id)
    
    {:noreply,
     socket
     |> assign(:current_channel, channel)
     |> assign(:current_channel_id, channel_id)
     |> assign(:messages, messages)
     |> assign(:show_thread, false)
     |> assign(:thread_message, nil)}
  end

  def handle_event("send_message", %{"content" => content}, socket) do
    case Messages.create_message(%{
      content: content,
      channel_id: socket.assigns.current_channel_id,
      user_id: socket.assigns.current_user.id
    }) do
      {:ok, message} ->
        message = SlackClone.Repo.preload(message, :user)
        
        # Broadcast to channel
        PubSub.broadcast(
          SlackClone.PubSub,
          "channel:#{socket.assigns.current_channel_id}",
          {:new_message, message}
        )
        
        {:noreply, assign(socket, :composing_message, "")}
        
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not send message")}
    end
  end

  def handle_event("typing", _params, socket) do
    # Broadcast typing indicator
    PubSub.broadcast_from(
      self(),
      SlackClone.PubSub,
      "channel:#{socket.assigns.current_channel_id}",
      {:user_typing, socket.assigns.current_user}
    )
    
    {:noreply, socket}
  end

  def handle_event("open_new_channel", _params, socket) do
    {:noreply, assign(socket, :show_new_channel, true)}
  end

  def handle_event("cancel_new_channel", _params, socket) do
    {:noreply, assign(socket, :show_new_channel, false)}
  end

  def handle_event("create_channel", %{"name" => name} = params, socket) do
    name = String.trim(name || "")
    desc = String.trim(Map.get(params, "description", ""))
    if name == "" do
      {:noreply, put_flash(socket, :error, "Channel name can't be blank")}
    else
      attrs = %{
        name: name,
        description: desc,
        workspace_id: socket.assigns.workspace_id,
        created_by_id: socket.assigns.current_user.id,
        is_private: false
      }

      case Channels.create_channel(attrs) do
        {:ok, channel} ->
          channels = [channel | socket.assigns.channels] |> Enum.sort_by(& &1.name)
          socket =
            socket
            |> assign(:channels, channels)
            |> assign(:show_new_channel, false)

          {:noreply, push_navigate(socket, to: ~p"/workspace/#{socket.assigns.workspace_id}/channel/#{channel.id}")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not create channel")
           |> assign(:new_channel_changeset, changeset)}
      end
    end
  end

  def handle_event("start_thread", %{"message-id" => message_id}, socket) do
    message = Messages.get_message!(message_id)
    {:noreply,
     socket
     |> assign(:show_thread, true)
     |> assign(:thread_message, message)}
  end

  def handle_event("close_thread", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_thread, false)
     |> assign(:thread_message, nil)}
  end

  def handle_event("send_thread_reply", %{"content" => content}, socket) do
    # Implementation for thread replies
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col overflow-hidden">
      <!-- User token for WS channels -->
      <%= if @current_user do %>
        <meta name="user-token" content={Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", @current_user.id)} />
      <% end %>
      <!-- Top navigation bar -->
      <header class="bg-[#350d36] text-white flex items-center justify-between px-4 h-10 flex-shrink-0">
        <div class="flex items-center">
          <button class="hover:bg-white/10 p-1 rounded">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
          </button>
          <button class="ml-3 hover:bg-white/10 px-2 py-1 rounded flex items-center">
            <span class="font-semibold"><%= @workspace.name %></span>
            <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
            </svg>
          </button>
        </div>
        
        <div class="flex-1 max-w-2xl mx-auto px-2">
          <div class="relative">
            <input
              type="text"
              placeholder={"Search #{@workspace.name}"}
              class="w-full bg-white/20 text-white placeholder-white/70 rounded px-3 py-1 text-sm focus:outline-none focus:bg-white focus:text-gray-900"
            />
            <svg class="absolute right-2 top-1.5 w-4 h-4 text-white/70" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
          </div>
        </div>

        <div class="flex items-center space-x-3">
          <button class="hover:bg-white/10 p-1 rounded">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </button>
          <button class="hover:bg-white/10 p-1 rounded">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </button>
          <div class="w-8 h-8 rounded bg-gray-500 flex items-center justify-center text-sm font-medium">
            <%= String.first(@current_user.email) |> String.upcase() %>
          </div>
        </div>
      </header>

      <!-- Main content area -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Sidebar -->
        <aside class="w-64 bg-[#3f0e40] text-gray-300 flex flex-col">
          <!-- Workspace header -->
          <div class="p-4 border-b border-[#522653]">
            <button class="w-full text-left hover:bg-[#4d1f4e] rounded p-2 -m-2">
              <div class="flex items-center justify-between">
                <div>
                  <h2 class="text-white font-bold text-lg"><%= @workspace.name %></h2>
                  <div class="flex items-center text-xs">
                    <span class="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
                    <%= @current_user.email %>
                  </div>
                </div>
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                </svg>
              </div>
            </button>
          </div>

          <!-- Compose button -->
          <div class="p-3">
            <button class="w-full bg-white text-[#3f0e40] rounded-full px-4 py-2 text-sm font-semibold hover:bg-gray-100 flex items-center justify-center">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              New message
            </button>
          </div>

          <!-- Navigation -->
          <nav class="flex-1 overflow-y-auto px-3">
            <!-- Threads, DMs, etc -->
            <div class="space-y-1 mb-4">
              <button class="w-full text-left hover:bg-[#4d1f4e] rounded px-2 py-1 flex items-center">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"/>
                </svg>
                Threads
              </button>
              <button class="w-full text-left hover:bg-[#4d1f4e] rounded px-2 py-1 flex items-center">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z"/>
                </svg>
                Direct messages
              </button>
              <button class="w-full text-left hover:bg-[#4d1f4e] rounded px-2 py-1 flex items-center">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
                </svg>
                Mentions & reactions
              </button>
            </div>

            <!-- Channels -->
            <div class="mb-4">
              <div class="flex items-center justify-between mb-2">
                <button class="flex items-center text-xs font-semibold uppercase tracking-wide hover:text-white">
                  <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
                  </svg>
                  Channels
                </button>
                <button phx-click="open_new_channel" class="hover:bg-[#4d1f4e] p-1 rounded">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                </button>
              </div>

              <%= if @show_new_channel do %>
                <div class="mb-3 p-3 bg-[#421f41] rounded">
                  <form phx-submit="create_channel" class="space-y-2">
                    <input name="name" type="text" placeholder="new-channel-name" class="w-full px-2 py-1 rounded bg-white/10 text-white placeholder-white/60 focus:outline-none" />
                    <input name="description" type="text" placeholder="Description (optional)" class="w-full px-2 py-1 rounded bg-white/10 text-white placeholder-white/60 focus:outline-none" />
                    <div class="flex gap-2">
                      <button type="submit" class="px-3 py-1 bg-[#1264a3] text-white rounded">Create</button>
                      <button type="button" phx-click="cancel_new_channel" class="px-3 py-1 bg-gray-500 text-white rounded">Cancel</button>
                    </div>
                  </form>
                </div>
              <% end %>
              
              <div class="space-y-0.5">
                <%= for channel <- @channels do %>
                  <a href={~p"/workspace/#{@workspace_id}/channel/#{channel.id}"} class="block w-full text-left hover:bg-[#4d1f4e] rounded px-2 py-1">
                    <div class={[
                      "flex items-center justify-between group",
                      @current_channel && @current_channel.id == channel.id && "bg-[#1264a3] text-white hover:bg-[#1264a3]"
                    ]}>
                      <span class="flex items-center">
                        <%= if channel.is_private do %>
                          <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
                          </svg>
                        <% else %>
                          <span class="mr-2">#</span>
                        <% end %>
                        <%= channel.name %>
                      </span>
                      <%= if Map.get(@unread_counts, channel.id, 0) > 0 do %>
                        <span class="bg-red-500 text-white text-xs rounded-full px-2 py-0.5">
                          <%= Map.get(@unread_counts, channel.id, 0) %>
                        </span>
                      <% end %>
                    </div>
                  </a>
                <% end %>
              </div>
            </div>

            <!-- Direct Messages -->
            <div>
              <div class="flex items-center justify-between mb-2">
                <button class="flex items-center text-xs font-semibold uppercase tracking-wide hover:text-white">
                  <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
                  </svg>
                  Direct messages
                </button>
                <button class="hover:bg-[#4d1f4e] p-1 rounded">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                </button>
              </div>
              
              <div class="space-y-0.5">
                <%= for dm <- @direct_messages do %>
                  <button class="w-full text-left hover:bg-[#4d1f4e] rounded px-2 py-1 flex items-center">
                    <span class="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
                    <%= dm.user.name %>
                  </button>
                <% end %>
              </div>
            </div>
          </nav>
        </aside>

        <!-- Main channel view -->
        <main class="flex-1 flex flex-col bg-white">
          <%= if @current_channel do %>
            <!-- Channel header -->
            <header class="border-b px-6 py-3 flex items-center justify-between">
              <div class="flex items-center">
                <h2 class="text-lg font-bold flex items-center">
                  <%= if @current_channel.is_private do %>
                    <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
                    </svg>
                  <% else %>
                    <span class="mr-1">#</span>
                  <% end %>
                  <%= @current_channel.name %>
                </h2>
                <button class="ml-2 text-gray-500 hover:text-gray-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
                  </svg>
                </button>
              </div>
              
              <div class="flex items-center space-x-4">
                <span class="text-sm text-gray-500">
                  <%= map_size(@online_users) %> members
                </span>
                <button class="text-gray-500 hover:text-gray-700">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </button>
              </div>
            </header>

            <!-- Messages area -->
            <div class="flex-1 overflow-y-auto px-6 py-4" id="messages-container" phx-hook="ScrollToBottom">
              <%= for message <- @messages do %>
                <div class="mb-4 hover:bg-gray-50 -mx-4 px-4 py-2 group">
                  <div class="flex">
                    <div class="w-10 h-10 rounded bg-gray-400 flex items-center justify-center text-white font-semibold mr-3">
                      <%= String.first(message.user.email) |> String.upcase() %>
                    </div>
                    <div class="flex-1">
                      <div class="flex items-baseline">
                        <span class="font-semibold mr-2"><%= message.user.email %></span>
                        <span class="text-xs text-gray-500">
                          <%= Calendar.strftime(message.inserted_at, "%I:%M %p") %>
                        </span>
                      </div>
                      <div class="text-gray-900"><%= message.content %></div>
                      
                      <!-- Message actions (shown on hover) -->
                      <div class="mt-1 opacity-0 group-hover:opacity-100 transition-opacity flex items-center space-x-1">
                        <button class="p-1 hover:bg-gray-200 rounded text-gray-500">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                          </svg>
                        </button>
                        <button phx-click="start_thread" phx-value-message-id={message.id} class="p-1 hover:bg-gray-200 rounded text-gray-500">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"/>
                          </svg>
                        </button>
                        <button class="p-1 hover:bg-gray-200 rounded text-gray-500">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/>
                          </svg>
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Message input -->
            <div class="border-t px-6 py-4">
              <form phx-submit="send_message" class="relative">
                <div class="border rounded-lg focus-within:border-gray-400 focus-within:shadow-sm">
                  <textarea
                    id="message-input"
                    name="content"
                    rows="1"
                    class="w-full px-4 py-3 resize-none focus:outline-none"
                    placeholder={"Message ##{@current_channel.name}"}
                    phx-keydown="typing"
                    phx-hook="MessageInput"
                  ><%= @composing_message %></textarea>
                  
                  <!-- Toolbar -->
                  <div class="flex items-center justify-between px-3 py-2 border-t">
                    <div class="flex items-center space-x-1">
                      <button type="button" class="p-1 hover:bg-gray-100 rounded">
                        <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                        </svg>
                      </button>
                      <button type="button" class="p-1 hover:bg-gray-100 rounded">
                        <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                      </button>
                      <button type="button" class="p-1 hover:bg-gray-100 rounded">
                        <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
                        </svg>
                      </button>
                    </div>
                    
                    <button type="submit" class="px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700 text-sm font-medium">
                      Send
                    </button>
                  </div>
                </div>
              </form>
              
              <%= if @typing_users != [] do %>
                <div class="mt-2 text-sm text-gray-500">
                  <%= Enum.join(@typing_users, ", ") %> is typing...
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="flex-1 flex items-center justify-center">
              <p class="text-gray-500">Select a channel to start messaging</p>
            </div>
          <% end %>
        </main>

        <!-- Thread sidebar (conditional) -->
        <%= if @show_thread && @thread_message do %>
          <aside class="w-96 border-l bg-white flex flex-col">
            <div class="border-b px-4 py-3 flex items-center justify-between">
              <h3 class="font-semibold">Thread</h3>
              <button phx-click="close_thread" class="text-gray-500 hover:text-gray-700">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            
            <div class="flex-1 overflow-y-auto p-4">
              <!-- Original message -->
              <div class="mb-4 pb-4 border-b">
                <div class="flex">
                  <div class="w-8 h-8 rounded bg-gray-400 flex items-center justify-center text-white text-sm font-semibold mr-3">
                    <%= String.first(@thread_message.user.email) |> String.upcase() %>
                  </div>
                  <div class="flex-1">
                    <div class="flex items-baseline">
                      <span class="font-semibold mr-2"><%= @thread_message.user.email %></span>
                      <span class="text-xs text-gray-500">
                        <%= Calendar.strftime(@thread_message.inserted_at, "%I:%M %p") %>
                      </span>
                    </div>
                    <div class="text-gray-900"><%= @thread_message.content %></div>
                  </div>
                </div>
              </div>
              
              <!-- Thread replies would go here -->
            </div>
            
            <div class="border-t p-4">
              <form phx-submit="send_thread_reply">
                <textarea
                  name="content"
                  rows="3"
                  class="w-full border rounded-lg px-3 py-2 focus:outline-none focus:border-blue-500"
                  placeholder="Reply..."
                ></textarea>
                <button type="submit" class="mt-2 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm font-medium">
                  Send
                </button>
              </form>
            </div>
          </aside>
        <% end %>
      </div>
    </div>
    """
  end

  # Private helper functions
  
  defp get_current_user(session) do
    # Mock user data - replace with actual user loading from session
    %{
      id: "user_1",
      name: "John Doe", 
      email: "john@example.com",
      avatar_url: "/images/default-avatar.png"
    }
  end

  defp load_workspace_data(socket, workspace_id) do
    # Load channels and other workspace data
    channels = load_channels(workspace_id)
    online_users = Presence.list_workspace_users(workspace_id) |> users_by_id()
    
    socket
    |> assign(:channels, channels)
    |> assign(:online_users, online_users)
  end

  defp load_channels(workspace_id) do
    # Mock channels - replace with actual data loading
    [
      %{id: "general", name: "general", description: "General discussion", workspace_id: workspace_id},
      %{id: "random", name: "random", description: "Random stuff", workspace_id: workspace_id}
    ]
  end

  defp users_by_id(users) do
    Enum.reduce(users, %{}, fn user, acc ->
      Map.put(acc, user.user_id, user)
    end)
  end

  defp handle_presence_diff(socket, %{joins: joins, leaves: leaves}) do
    online_users =
      socket.assigns.online_users
      |> Map.merge(users_by_id(joins))
      |> Map.drop(Enum.map(leaves, fn {_key, user} -> user.user_id end))

    assign(socket, :online_users, online_users)
  end

  defp increment_unread_count(socket, channel_id) do
    unread_counts = 
      Map.update(socket.assigns.unread_counts, channel_id, 1, &(&1 + 1))
    
    assign(socket, :unread_counts, unread_counts)
  end

  defp clear_unread_count(socket, channel_id) do
    unread_counts = Map.put(socket.assigns.unread_counts, channel_id, 0)
    assign(socket, :unread_counts, unread_counts)
  end

  defp maybe_redirect_from_deleted_channel(socket, channel_id) do
    if socket.assigns.current_channel_id == channel_id do
      path = ~p"/workspace/#{socket.assigns.workspace_id}"
      push_navigate(socket, to: path)
    else
      socket
    end
  end

  # Mock functions - replace with actual implementations
  defp create_channel(_workspace_id, _name, _description, _user), do: {:error, :not_implemented}
  defp join_channel(_channel_id, _user), do: {:error, :not_implemented}  
  defp leave_channel(_channel_id, _user_id), do: {:error, :not_implemented}
end
