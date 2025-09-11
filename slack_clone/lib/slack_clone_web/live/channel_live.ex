defmodule SlackCloneWeb.ChannelLive do
  @moduledoc """
  LiveView component for individual channel view with real-time messaging,
  typing indicators, and message management.
  """
  use SlackCloneWeb, :live_component

  alias SlackClone.PubSubHelper, as: PubSub
  alias SlackCloneWeb.Presence

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:messages, [])
      |> assign(:typing_users, %{})
      |> assign(:message_input, "")
      |> assign(:thread_message_id, nil)
      |> assign(:loading, true)
      |> assign(:typing_timer, nil)

    {:ok, socket}
  end

  @impl true
  def update(%{channel_id: channel_id} = assigns, socket) do
    if connected?(socket) do
      # Subscribe to channel events if not already subscribed
      PubSub.subscribe_to_channel(channel_id)
      
      # Track user presence in channel
      Presence.track_user_in_channel(channel_id, assigns.current_user.id, %{
        name: assigns.current_user.name,
        avatar_url: assigns.current_user.avatar_url
      })
    end

    socket =
      socket
      |> assign(assigns)
      |> load_channel_data(channel_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    if String.trim(content) != "" do
      case send_message(socket.assigns.channel_id, content, socket.assigns.current_user) do
        {:ok, message} ->
          # Clear typing indicator
          stop_typing(socket)
          
          socket =
            socket
            |> assign(:message_input, "")
            |> cancel_typing_timer()

          {:noreply, socket}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("typing_start", %{"content" => content}, socket) do
    # Start typing indicator
    start_typing(socket)
    
    # Cancel existing timer and set new one
    socket =
      socket
      |> cancel_typing_timer()
      |> schedule_typing_stop()
      |> assign(:message_input, content)

    {:noreply, socket}
  end

  def handle_event("delete_message", %{"message_id" => message_id}, socket) do
    case delete_message(message_id, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, socket}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete message")}
    end
  end

  def handle_event("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    case edit_message(message_id, content, socket.assigns.current_user) do
      {:ok, _message} ->
        {:noreply, socket}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to edit message")}
    end
  end

  def handle_event("add_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    case add_reaction(message_id, emoji, socket.assigns.current_user) do
      {:ok, _reaction} ->
        {:noreply, socket}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add reaction")}
    end
  end

  def handle_event("open_thread", %{"message_id" => message_id}, socket) do
    socket = assign(socket, :thread_message_id, message_id)
    {:noreply, socket}
  end

  def handle_event("close_thread", _params, socket) do
    socket = assign(socket, :thread_message_id, nil)
    {:noreply, socket}
  end

  def handle_event("mark_as_read", %{"message_id" => message_id}, socket) do
    mark_message_as_read(message_id, socket.assigns.current_user.id)
    {:noreply, socket}
  end

  # Handle real-time events
  @impl true
  def handle_info({:new_message, message}, socket) do
    messages = [message | socket.assigns.messages] |> Enum.take(100) # Limit to last 100
    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:message_updated, message}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn m ->
        if m.id == message.id, do: message, else: m
      end)
    
    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:message_deleted, %{id: message_id}}, socket) do
    messages = Enum.reject(socket.assigns.messages, &(&1.id == message_id))
    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:typing_start, %{user_id: user_id, user_name: user_name}}, socket) do
    if user_id != socket.assigns.current_user.id do
      typing_users = 
        Map.put(socket.assigns.typing_users, user_id, %{
          name: user_name,
          started_at: System.system_time(:millisecond)
        })
      
      {:noreply, assign(socket, :typing_users, typing_users)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:typing_stop, %{user_id: user_id}}, socket) do
    typing_users = Map.delete(socket.assigns.typing_users, user_id)
    {:noreply, assign(socket, :typing_users, typing_users)}
  end

  def handle_info({:reaction_added, %{message_id: message_id, reaction: reaction}}, socket) do
    messages = 
      Enum.map(socket.assigns.messages, fn message ->
        if message.id == message_id do
          reactions = [reaction | (message.reactions || [])]
          %{message | reactions: reactions}
        else
          message
        end
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:reaction_removed, %{message_id: message_id, reaction: reaction}}, socket) do
    messages = 
      Enum.map(socket.assigns.messages, fn message ->
        if message.id == message_id do
          reactions = 
            (message.reactions || [])
            |> Enum.reject(&(&1.id == reaction.id))
          %{message | reactions: reactions}
        else
          message
        end
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:message_read, %{message_id: message_id, user_id: user_id}}, socket) do
    messages = 
      Enum.map(socket.assigns.messages, fn message ->
        if message.id == message_id do
          read_receipts = [user_id | (message.read_receipts || [])] |> Enum.uniq()
          %{message | read_receipts: read_receipts}
        else
          message
        end
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info(:stop_typing_indicator, socket) do
    stop_typing(socket)
    socket = assign(socket, :typing_timer, nil)
    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <!-- Channel Header -->
      <div class="border-b border-slack-border p-4 bg-white">
        <h2 class="text-lg font-bold text-slack-text-primary flex items-center">
          # <%= @channel.name %>
          <span class="text-sm font-normal text-slack-text-secondary ml-2">
            <%= @channel.description %>
          </span>
        </h2>
        
        <div class="flex items-center mt-2 space-x-4">
          <span class="text-sm text-slack-text-secondary">
            <%= length(@channel_users) %> members
          </span>
        </div>
      </div>

      <!-- Messages Area -->
      <div class="flex-1 flex">
        <!-- Main Messages -->
        <div class="flex-1 flex flex-col">
          <div 
            id="messages-container"
            class="flex-1 overflow-y-auto p-4 space-y-4"
            phx-hook="ScrollToBottom"
          >
            <%= if @loading do %>
              <div class="text-center py-8">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-slack-primary mx-auto"></div>
                <p class="text-slack-text-secondary mt-2">Loading messages...</p>
              </div>
            <% else %>
              <%= for message <- Enum.reverse(@messages) do %>
                <.live_component
                  module={SlackCloneWeb.MessageLive}
                  id={"message-#{message.id}"}
                  message={message}
                  current_user={@current_user}
                  can_edit={message.user_id == @current_user.id}
                  can_delete={message.user_id == @current_user.id}
                />
              <% end %>
            <% end %>
          </div>

          <!-- Typing Indicators -->
          <%= if map_size(@typing_users) > 0 do %>
            <div class="px-4 py-2 border-t border-slack-border-light">
              <.typing_indicator typing_users={@typing_users} />
            </div>
          <% end %>

          <!-- Message Input -->
          <div class="border-t border-slack-border p-4 bg-white">
            <form phx-submit="send_message" phx-target={@myself} class="flex items-end space-x-3">
              <div class="flex-1">
                <textarea
                  id="channel-message-input"
                  name="message[content]"
                  value={@message_input}
                  phx-change="typing_start"
                  phx-target={@myself}
                  placeholder={"Message ##{@channel.name}"}
                  class="w-full resize-none rounded-md border border-slack-border p-3 focus:border-slack-primary focus:ring-1 focus:ring-slack-primary"
                  rows="1"
                  phx-hook="AutoResize"
                />
              </div>
              <button
                type="submit"
                class="bg-slack-primary hover:bg-slack-primary-hover text-white p-3 rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
                disabled={String.trim(@message_input) == ""}
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </button>
            </form>
          </div>
        </div>

        <!-- Thread Panel (if open) -->
        <%= if @thread_message_id do %>
          <div class="w-96 border-l border-slack-border bg-slack-bg-light">
            <.live_component
              module={SlackCloneWeb.ThreadLive}
              id={"thread-#{@thread_message_id}"}
              message_id={@thread_message_id}
              current_user={@current_user}
            />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper components
  
  defp typing_indicator(assigns) do
    names = assigns.typing_users |> Map.values() |> Enum.map(& &1.name)
    typing_text = case length(names) do
      1 -> "#{Enum.at(names, 0)} is typing..."
      2 -> "#{Enum.at(names, 0)} and #{Enum.at(names, 1)} are typing..."
      n when n > 2 -> "#{Enum.at(names, 0)} and #{n - 1} others are typing..."
      _ -> ""
    end
    
    assigns = assign(assigns, :typing_text, typing_text)

    ~H"""
    <div class="flex items-center space-x-2 text-sm text-slack-text-secondary">
      <div class="flex space-x-1">
        <div class="w-1 h-1 bg-slack-text-secondary rounded-full animate-bounce"></div>
        <div class="w-1 h-1 bg-slack-text-secondary rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
        <div class="w-1 h-1 bg-slack-text-secondary rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
      </div>
      <span><%= @typing_text %></span>
    </div>
    """
  end

  # Private helper functions
  
  defp load_channel_data(socket, channel_id) do
    # Load channel info and recent messages
    channel = load_channel(channel_id)
    messages = load_recent_messages(channel_id)
    channel_users = Presence.list_channel_users(channel_id)
    
    socket
    |> assign(:channel, channel)
    |> assign(:messages, messages)
    |> assign(:channel_users, channel_users)
    |> assign(:loading, false)
  end

  defp start_typing(socket) do
    PubSub.broadcast_typing_start(socket.assigns.channel_id, socket.assigns.current_user)
  end

  defp stop_typing(socket) do
    PubSub.broadcast_typing_stop(socket.assigns.channel_id, socket.assigns.current_user)
  end

  defp schedule_typing_stop(socket) do
    timer = Process.send_after(self(), :stop_typing_indicator, 3000)
    assign(socket, :typing_timer, timer)
  end

  defp cancel_typing_timer(socket) do
    if socket.assigns.typing_timer do
      Process.cancel_timer(socket.assigns.typing_timer)
    end
    assign(socket, :typing_timer, nil)
  end

  # Mock functions - replace with actual implementations
  defp load_channel(channel_id) do
    %{
      id: channel_id,
      name: "general",
      description: "General discussion",
      created_at: DateTime.utc_now()
    }
  end

  defp load_recent_messages(_channel_id) do
    # Mock messages
    []
  end

  defp send_message(_channel_id, _content, _user), do: {:error, :not_implemented}
  defp delete_message(_message_id, _user), do: {:error, :not_implemented}
  defp edit_message(_message_id, _content, _user), do: {:error, :not_implemented}
  defp add_reaction(_message_id, _emoji, _user), do: {:error, :not_implemented}
  defp mark_message_as_read(_message_id, _user_id), do: :ok
end