defmodule SlackCloneWeb.OptimizedChannelLive do
  @moduledoc """
  High-performance LiveView for channel messaging with virtual scrolling,
  optimized diffs, lazy loading, and intelligent state management.
  """
  use SlackCloneWeb, :live_view
  
  alias SlackClone.Performance.{CacheManager, PubSubOptimizer}
  alias SlackCloneWeb.Presence
  
  # Performance configuration
  @messages_per_page 30
  @virtual_scroll_buffer 10
  @presence_update_interval 5000
  @typing_debounce 1000
  
  @impl true
  def mount(%{"channel_id" => channel_id}, _session, socket) do
    if connected?(socket) do
      # Optimized subscriptions
      PubSubOptimizer.subscribe_to_channel(channel_id, include_presence: true)
      
      # Schedule periodic cleanup
      :timer.send_interval(@presence_update_interval, :cleanup_presence)
      :timer.send_interval(@typing_debounce * 3, :cleanup_typing)
    end
    
    socket =
      socket
      |> assign(:channel_id, channel_id)
      |> assign(:messages, [])
      |> assign(:message_ids, MapSet.new())  # For deduplication
      |> assign(:virtual_start, 0)
      |> assign(:virtual_end, @messages_per_page)
      |> assign(:total_messages, 0)
      |> assign(:typing_users, %{})
      |> assign(:typing_timers, %{})
      |> assign(:presence_users, %{})
      |> assign(:message_input, "")
      |> assign(:loading_messages, false)
      |> assign(:has_more_messages, true)
      |> assign(:scroll_position, 0)
      |> assign(:channel_info, nil)
      |> assign(:optimized_render, true)
      |> load_initial_data()
    
    {:ok, socket, temporary_assigns: [messages: []]}
  end
  
  @impl true
  def handle_event("load_more_messages", %{"offset" => offset_str}, socket) do
    offset = String.to_integer(offset_str)
    
    if not socket.assigns.loading_messages do
      socket =
        socket
        |> assign(:loading_messages, true)
        |> load_messages_page(offset)
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    if String.trim(content) != "" do
      # Optimistic update - add message immediately to UI
      temp_message = create_optimistic_message(content, socket.assigns.current_user)
      
      socket =
        socket
        |> add_message_to_state(temp_message, optimistic: true)
        |> assign(:message_input, "")
        |> stop_typing_indicator()
      
      # Send to backend asynchronously
      Task.start(fn ->
        send_message_async(socket.assigns.channel_id, content, socket.assigns.current_user)
      end)
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("typing_input", %{"value" => content}, socket) do
    # Debounced typing indicator
    user_id = socket.assigns.current_user.id
    
    socket =
      socket
      |> assign(:message_input, content)
      |> debounce_typing_indicator(user_id)
    
    {:noreply, socket}
  end
  
  def handle_event("scroll_update", %{"scrollTop" => scroll_top, "clientHeight" => client_height, "scrollHeight" => scroll_height}, socket) do
    # Update virtual scroll position
    scroll_percentage = scroll_top / (scroll_height - client_height)
    
    socket =
      socket
      |> assign(:scroll_position, scroll_percentage)
      |> update_virtual_window(scroll_top, client_height)
    
    {:noreply, socket}
  end
  
  def handle_event("message_action", %{"action" => action, "message_id" => message_id} = params, socket) do
    handle_message_action(action, message_id, params, socket)
  end
  
  # Optimized real-time event handlers
  
  @impl true
  def handle_info({:batched_messages, messages}, socket) do
    # Process batched messages efficiently
    socket = 
      messages
      |> Enum.reduce(socket, fn message, acc_socket ->
        add_message_to_state(acc_socket, message, optimistic: false)
      end)
    
    {:noreply, socket}
  end
  
  def handle_info({:new_message, message}, socket) do
    socket = add_message_to_state(socket, message, optimistic: false)
    {:noreply, socket}
  end
  
  def handle_info({:message_updated, message}, socket) do
    socket = update_message_in_state(socket, message)
    {:noreply, socket}
  end
  
  def handle_info({:message_deleted, %{id: message_id}}, socket) do
    socket = remove_message_from_state(socket, message_id)
    {:noreply, socket}
  end
  
  def handle_info({:typing_start, %{user_id: user_id, user_name: user_name}}, socket) do
    if user_id != socket.assigns.current_user.id do
      socket = add_typing_user(socket, user_id, user_name)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  def handle_info({:typing_stop, %{user_id: user_id}}, socket) do
    socket = remove_typing_user(socket, user_id)
    {:noreply, socket}
  end
  
  def handle_info({:presence_update, %{user_id: user_id, data: presence_data}}, socket) do
    socket = update_presence_user(socket, user_id, presence_data)
    {:noreply, socket}
  end
  
  def handle_info(:cleanup_presence, socket) do
    socket = cleanup_stale_presence(socket)
    {:noreply, socket}
  end
  
  def handle_info(:cleanup_typing, socket) do
    socket = cleanup_stale_typing(socket)
    {:noreply, socket}
  end
  
  def handle_info({:stop_typing, user_id}, socket) do
    PubSubOptimizer.broadcast_typing_stop(socket.assigns.channel_id, %{id: user_id})
    socket = cancel_typing_timer(socket, user_id)
    {:noreply, socket}
  end
  
  def handle_info(_message, socket) do
    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full relative" id="channel-container" phx-hook="VirtualScroll">
      <!-- Channel Header (cached render) -->
      <%= render_channel_header(assigns) %>
      
      <!-- Virtual Scrolled Messages Area -->
      <div 
        id="messages-viewport"
        class="flex-1 overflow-y-auto"
        phx-hook="MessageViewport"
        data-virtual-start={@virtual_start}
        data-virtual-end={@virtual_end}
        data-total-messages={@total_messages}
        phx-update="stream"
      >
        <!-- Loading indicator for pagination -->
        <%= if @loading_messages do %>
          <div class="text-center py-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-slack-primary mx-auto"></div>
          </div>
        <% end %>
        
        <!-- Virtual spacer top -->
        <div 
          id="spacer-top" 
          style={"height: #{@virtual_start * 80}px"}
          class="bg-transparent"
        ></div>
        
        <!-- Rendered messages (only visible ones) -->
        <div id="messages-container" phx-update="stream" phx-viewport-top="load_more_messages">
          <%= for {message_id, message} <- @streams.messages do %>
            <div 
              id={message_id}
              class="message-item px-4 py-2 hover:bg-gray-50"
              data-message-id={message.id}
            >
              <%= render_optimized_message(message, assigns) %>
            </div>
          <% end %>
        </div>
        
        <!-- Virtual spacer bottom -->
        <div 
          id="spacer-bottom" 
          style={"height: #{(@total_messages - @virtual_end) * 80}px"}
          class="bg-transparent"
        ></div>
      </div>
      
      <!-- Optimized Typing Indicators -->
      <%= render_typing_indicators(assigns) %>
      
      <!-- Message Input with debounced updates -->
      <%= render_message_input(assigns) %>
      
      <!-- Presence sidebar (conditionally rendered) -->
      <%= if length(@presence_users) > 0 do %>
        <%= render_presence_sidebar(assigns) %>
      <% end %>
    </div>
    """
  end
  
  # Optimized render functions (cached where possible)
  
  defp render_channel_header(assigns) do
    # This function result can be cached since channel info changes infrequently
    ~H"""
    <div class="border-b border-gray-200 p-4 bg-white">
      <%= if @channel_info do %>
        <h2 class="text-lg font-semibold text-gray-900">
          # <%= @channel_info.name %>
        </h2>
        <%= if @channel_info.description do %>
          <p class="text-sm text-gray-500 mt-1"><%= @channel_info.description %></p>
        <% end %>
        <div class="flex items-center mt-2 text-xs text-gray-400">
          <span><%= @channel_info.member_count %> members</span>
        </div>
      <% else %>
        <div class="animate-pulse">
          <div class="h-6 bg-gray-300 rounded w-48 mb-2"></div>
          <div class="h-4 bg-gray-300 rounded w-32"></div>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp render_optimized_message(message, assigns) do
    # Optimized message rendering with minimal DOM updates
    ~H"""
    <div class="flex space-x-3 group">
      <img 
        src={message.user.avatar_url || "/images/default_avatar.png"}
        alt={message.user.name}
        class="w-8 h-8 rounded-sm flex-shrink-0"
        loading="lazy"
      />
      <div class="flex-1 min-w-0">
        <div class="flex items-center space-x-2">
          <span class="font-medium text-sm text-gray-900"><%= message.user.name %></span>
          <time class="text-xs text-gray-500" datetime={message.inserted_at}>
            <%= format_timestamp(message.inserted_at) %>
          </time>
          <%= if message.is_edited do %>
            <span class="text-xs text-gray-400">(edited)</span>
          <% end %>
        </div>
        <div class="mt-1">
          <p class="text-sm text-gray-900 whitespace-pre-wrap"><%= message.content %></p>
          
          <!-- Reactions (only render if present) -->
          <%= if message.reactions && length(message.reactions) > 0 do %>
            <div class="flex flex-wrap gap-1 mt-2">
              <%= for reaction <- message.reactions do %>
                <button class="inline-flex items-center px-2 py-1 rounded-full text-xs bg-blue-100 text-blue-800 hover:bg-blue-200">
                  <%= reaction.emoji %> <%= reaction.count %>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
        
        <!-- Message actions (only show on hover for performance) -->
        <div class="opacity-0 group-hover:opacity-100 transition-opacity">
          <%= render_message_actions(message, assigns) %>
        </div>
      </div>
    </div>
    """
  end
  
  defp render_typing_indicators(assigns) do
    if map_size(assigns.typing_users) > 0 do
      ~H"""
      <div class="px-4 py-2 border-t border-gray-200 bg-gray-50">
        <%= render_typing_animation(assigns) %>
      </div>
      """
    else
      ~H""
    end
  end
  
  defp render_typing_animation(assigns) do
    typing_names = 
      assigns.typing_users
      |> Map.values()
      |> Enum.map(& &1.name)
    
    text = case length(typing_names) do
      1 -> "#{Enum.at(typing_names, 0)} is typing..."
      2 -> "#{Enum.at(typing_names, 0)} and #{Enum.at(typing_names, 1)} are typing..."
      n when n > 2 -> "#{Enum.at(typing_names, 0)} and #{n - 1} others are typing..."
    end
    
    assigns = assign(assigns, :typing_text, text)
    
    ~H"""
    <div class="flex items-center space-x-2">
      <div class="flex space-x-1">
        <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
        <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
        <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
      </div>
      <span class="text-sm text-gray-600"><%= @typing_text %></span>
    </div>
    """
  end
  
  defp render_message_input(assigns) do
    ~H"""
    <div class="border-t border-gray-200 p-4 bg-white">
      <form phx-submit="send_message" class="flex space-x-2">
        <div class="flex-1">
          <input
            type="text"
            name="message[content]"
            value={@message_input}
            phx-change="typing_input"
            placeholder={"Message ##{@channel_info && @channel_info.name}"}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            autocomplete="off"
            phx-debounce={@typing_debounce}
          />
        </div>
        <button
          type="submit"
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
          disabled={String.trim(@message_input) == ""}
        >
          Send
        </button>
      </form>
    </div>
    """
  end
  
  defp render_presence_sidebar(assigns) do
    ~H"""
    <div class="w-64 border-l border-gray-200 bg-gray-50 p-4">
      <h3 class="text-sm font-medium text-gray-900 mb-3">Online Now</h3>
      <div class="space-y-2">
        <%= for {_user_id, user} <- @presence_users do %>
          <div class="flex items-center space-x-2">
            <div class="w-2 h-2 bg-green-400 rounded-full"></div>
            <img src={user.avatar_url} alt={user.name} class="w-6 h-6 rounded-sm" />
            <span class="text-sm text-gray-900"><%= user.name %></span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  defp render_message_actions(message, assigns) do
    ~H"""
    <div class="flex items-center space-x-2 mt-1">
      <button 
        class="p-1 text-gray-400 hover:text-gray-600 rounded"
        phx-click="message_action"
        phx-value-action="react"
        phx-value-message-id={message.id}
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1.01M15 10h1.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </button>
      
      <%= if message.user_id == assigns.current_user.id do %>
        <button 
          class="p-1 text-gray-400 hover:text-gray-600 rounded"
          phx-click="message_action"
          phx-value-action="edit"
          phx-value-message-id={message.id}
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        
        <button 
          class="p-1 text-red-400 hover:text-red-600 rounded"
          phx-click="message_action"
          phx-value-action="delete"
          phx-value-message-id={message.id}
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      <% end %>
    </div>
    """
  end
  
  # Private helper functions
  
  defp load_initial_data(socket) do
    channel_id = socket.assigns.channel_id
    
    # Load cached channel info
    channel_info = CacheManager.cache_channel_info(channel_id)
    
    # Load initial messages
    messages = CacheManager.cache_channel_messages(channel_id, @messages_per_page, 0)
    
    socket
    |> assign(:channel_info, channel_info)
    |> stream(:messages, messages, dom_id: &("message-#{&1.id}"))
    |> assign(:total_messages, length(messages))
    |> assign(:has_more_messages, length(messages) >= @messages_per_page)
  end
  
  defp load_messages_page(socket, offset) do
    channel_id = socket.assigns.channel_id
    messages = CacheManager.cache_channel_messages(channel_id, @messages_per_page, offset)
    
    socket
    |> stream(:messages, messages, at: 0, dom_id: &("message-#{&1.id}"))
    |> assign(:loading_messages, false)
    |> assign(:has_more_messages, length(messages) >= @messages_per_page)
  end
  
  defp add_message_to_state(socket, message, opts \\ []) do
    optimistic = Keyword.get(opts, :optimistic, false)
    
    # Deduplicate messages
    if MapSet.member?(socket.assigns.message_ids, message.id) do
      socket
    else
      socket
      |> stream_insert(:messages, message, at: -1, dom_id: "message-#{message.id}")
      |> assign(:message_ids, MapSet.put(socket.assigns.message_ids, message.id))
      |> assign(:total_messages, socket.assigns.total_messages + 1)
    end
  end
  
  defp update_message_in_state(socket, message) do
    stream_insert(socket, :messages, message, dom_id: "message-#{message.id}")
  end
  
  defp remove_message_from_state(socket, message_id) do
    socket
    |> stream_delete(:messages, %{id: message_id})
    |> assign(:message_ids, MapSet.delete(socket.assigns.message_ids, message_id))
    |> assign(:total_messages, max(0, socket.assigns.total_messages - 1))
  end
  
  defp create_optimistic_message(content, user) do
    %{
      id: "temp-#{System.unique_integer([:positive])}",
      content: content,
      content_type: "text",
      user: %{
        id: user.id,
        name: user.name,
        avatar_url: user.avatar_url
      },
      reactions: [],
      is_edited: false,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      optimistic: true
    }
  end
  
  defp send_message_async(channel_id, content, user) do
    # This would be implemented with your actual message creation logic
    # For now, just simulate network delay
    Process.sleep(100)
    
    message = %{
      id: Ecto.UUID.generate(),
      content: content,
      channel_id: channel_id,
      user: user,
      inserted_at: DateTime.utc_now()
    }
    
    PubSubOptimizer.broadcast_message(channel_id, message)
  end
  
  defp add_typing_user(socket, user_id, user_name) do
    typing_users = Map.put(socket.assigns.typing_users, user_id, %{
      name: user_name,
      started_at: System.system_time(:millisecond)
    })
    
    assign(socket, :typing_users, typing_users)
  end
  
  defp remove_typing_user(socket, user_id) do
    typing_users = Map.delete(socket.assigns.typing_users, user_id)
    assign(socket, :typing_users, typing_users)
  end
  
  defp update_presence_user(socket, user_id, presence_data) do
    presence_users = Map.put(socket.assigns.presence_users, user_id, presence_data)
    assign(socket, :presence_users, presence_users)
  end
  
  defp debounce_typing_indicator(socket, user_id) do
    # Cancel existing timer
    socket = cancel_typing_timer(socket, user_id)
    
    # Send typing start
    PubSubOptimizer.broadcast_typing_start(socket.assigns.channel_id, socket.assigns.current_user)
    
    # Set new timer
    timer = Process.send_after(self(), {:stop_typing, user_id}, @typing_debounce)
    typing_timers = Map.put(socket.assigns.typing_timers, user_id, timer)
    
    assign(socket, :typing_timers, typing_timers)
  end
  
  defp cancel_typing_timer(socket, user_id) do
    case Map.get(socket.assigns.typing_timers, user_id) do
      nil -> socket
      timer ->
        Process.cancel_timer(timer)
        typing_timers = Map.delete(socket.assigns.typing_timers, user_id)
        assign(socket, :typing_timers, typing_timers)
    end
  end
  
  defp stop_typing_indicator(socket) do
    user_id = socket.assigns.current_user.id
    PubSubOptimizer.broadcast_typing_stop(socket.assigns.channel_id, %{id: user_id})
    cancel_typing_timer(socket, user_id)
  end
  
  defp cleanup_stale_presence(socket) do
    current_time = System.system_time(:millisecond)
    stale_threshold = @presence_update_interval * 3
    
    presence_users =
      socket.assigns.presence_users
      |> Enum.filter(fn {_user_id, data} ->
        case data do
          %{last_seen: last_seen} ->
            current_time - last_seen < stale_threshold
          _ ->
            true
        end
      end)
      |> Map.new()
    
    assign(socket, :presence_users, presence_users)
  end
  
  defp cleanup_stale_typing(socket) do
    current_time = System.system_time(:millisecond)
    stale_threshold = @typing_debounce * 2
    
    typing_users =
      socket.assigns.typing_users
      |> Enum.filter(fn {_user_id, data} ->
        current_time - data.started_at < stale_threshold
      end)
      |> Map.new()
    
    assign(socket, :typing_users, typing_users)
  end
  
  defp update_virtual_window(socket, scroll_top, client_height) do
    # Calculate which messages should be visible
    message_height = 80  # Estimated height per message
    visible_start = max(0, div(scroll_top, message_height) - @virtual_scroll_buffer)
    visible_end = min(
      socket.assigns.total_messages,
      visible_start + div(client_height, message_height) + (@virtual_scroll_buffer * 2)
    )
    
    socket
    |> assign(:virtual_start, visible_start)
    |> assign(:virtual_end, visible_end)
  end
  
  defp handle_message_action("react", message_id, params, socket) do
    # Handle reaction logic
    {:noreply, socket}
  end
  
  defp handle_message_action("edit", message_id, params, socket) do
    # Handle edit logic
    {:noreply, socket}
  end
  
  defp handle_message_action("delete", message_id, params, socket) do
    # Handle delete logic
    {:noreply, socket}
  end
  
  defp handle_message_action(_, _, _, socket) do
    {:noreply, socket}
  end
  
  defp format_timestamp(datetime) do
    # Format timestamp for display
    Timex.format!(datetime, "{h12}:{m} {AM}")
  end
end