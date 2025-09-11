defmodule SlackCloneWeb.ThreadLive do
  @moduledoc """
  LiveView component for message threads with real-time updates.
  Handles thread replies, nested conversations, and thread-specific events.
  """
  use SlackCloneWeb, :live_component

  alias SlackClone.PubSub

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:thread_replies, [])
      |> assign(:reply_input, "")
      |> assign(:loading, true)
      |> assign(:parent_message, nil)

    {:ok, socket}
  end

  @impl true
  def update(%{message_id: message_id} = assigns, socket) do
    if connected?(socket) do
      # Subscribe to thread events
      PubSub.subscribe(PubSub.message_thread_topic(message_id))
    end

    socket =
      socket
      |> assign(assigns)
      |> load_thread_data(message_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("send_reply", %{"reply" => %{"content" => content}}, socket) do
    if String.trim(content) != "" do
      case send_thread_reply(socket.assigns.message_id, content, socket.assigns.current_user) do
        {:ok, _reply} ->
          socket =
            socket
            |> assign(:reply_input, "")

          {:noreply, socket}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to send reply")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_thread", _params, socket) do
    send(self(), {:close_thread})
    {:noreply, socket}
  end

  def handle_event("edit_reply", %{"reply_id" => reply_id, "content" => content}, socket) do
    case edit_thread_reply(reply_id, content, socket.assigns.current_user) do
      {:ok, _reply} ->
        {:noreply, socket}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to edit reply")}
    end
  end

  def handle_event("delete_reply", %{"reply_id" => reply_id}, socket) do
    case delete_thread_reply(reply_id, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, socket}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete reply")}
    end
  end

  def handle_event("add_reply_reaction", %{"reply_id" => reply_id, "emoji" => emoji}, socket) do
    case add_reply_reaction(reply_id, emoji, socket.assigns.current_user) do
      {:ok, _reaction} ->
        {:noreply, socket}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add reaction")}
    end
  end

  # Handle real-time events
  @impl true
  def handle_info({:thread_reply, reply}, socket) do
    thread_replies = [reply | socket.assigns.thread_replies]
    {:noreply, assign(socket, :thread_replies, thread_replies)}
  end

  def handle_info({:thread_reply_updated, reply}, socket) do
    thread_replies =
      Enum.map(socket.assigns.thread_replies, fn r ->
        if r.id == reply.id, do: reply, else: r
      end)
    
    {:noreply, assign(socket, :thread_replies, thread_replies)}
  end

  def handle_info({:thread_reply_deleted, %{id: reply_id}}, socket) do
    thread_replies = Enum.reject(socket.assigns.thread_replies, &(&1.id == reply_id))
    {:noreply, assign(socket, :thread_replies, thread_replies)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Thread Header -->
      <div class="border-b border-slack-border p-4 bg-white">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-semibold text-slack-text-primary">Thread</h3>
          <button
            phx-click="close_thread"
            phx-target={@myself}
            class="p-1 rounded hover:bg-slack-bg text-slack-text-secondary hover:text-slack-text-primary"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        
        <p class="text-sm text-slack-text-secondary mt-1">
          <%= length(@thread_replies) %> replies
        </p>
      </div>

      <!-- Thread Content -->
      <div class="flex-1 flex flex-col">
        <!-- Parent Message -->
        <%= if @parent_message do %>
          <div class="border-b border-slack-border-light p-4 bg-slack-bg-light">
            <div class="flex space-x-3">
              <img 
                src={@parent_message.user.avatar_url} 
                alt={@parent_message.user.name}
                class="w-8 h-8 rounded flex-shrink-0"
              />
              <div class="flex-1">
                <div class="flex items-baseline space-x-2 mb-1">
                  <span class="font-semibold text-slack-text-primary text-sm">
                    <%= @parent_message.user.name %>
                  </span>
                  <time class="text-xs text-slack-text-secondary">
                    <%= format_time(@parent_message.inserted_at) %>
                  </time>
                </div>
                <div class="text-slack-text-primary text-sm">
                  <%= @parent_message.content %>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Thread Replies -->
        <div class="flex-1 overflow-y-auto p-4 space-y-4">
          <%= if @loading do %>
            <div class="text-center py-8">
              <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-slack-primary mx-auto"></div>
              <p class="text-slack-text-secondary text-sm mt-2">Loading replies...</p>
            </div>
          <% else %>
            <%= if length(@thread_replies) == 0 do %>
              <div class="text-center py-8">
                <p class="text-slack-text-secondary text-sm">No replies yet</p>
                <p class="text-slack-text-secondary text-xs mt-1">Be the first to reply!</p>
              </div>
            <% else %>
              <%= for reply <- Enum.reverse(@thread_replies) do %>
                <.thread_reply 
                  reply={reply}
                  current_user={@current_user}
                  target={@myself}
                />
              <% end %>
            <% end %>
          <% end %>
        </div>

        <!-- Reply Input -->
        <div class="border-t border-slack-border p-4 bg-white">
          <form phx-submit="send_reply" phx-target={@myself} class="flex items-end space-x-3">
            <div class="flex-1">
              <textarea
                id="thread-reply-textarea"
                name="reply[content]"
                value={@reply_input}
                placeholder="Reply to thread..."
                class="w-full resize-none rounded-md border border-slack-border p-3 focus:border-slack-primary focus:ring-1 focus:ring-slack-primary"
                rows="2"
                phx-hook="AutoResize"
              />
            </div>
            <button
              type="submit"
              class="bg-slack-primary hover:bg-slack-primary-hover text-white p-3 rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={String.trim(@reply_input) == ""}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # Thread reply component
  defp thread_reply(assigns) do
    ~H"""
    <div class="group flex space-x-3 hover:bg-slack-bg-hover p-2 rounded">
      <img 
        src={@reply.user.avatar_url} 
        alt={@reply.user.name}
        class="w-7 h-7 rounded flex-shrink-0"
      />
      
      <div class="flex-1 min-w-0">
        <div class="flex items-baseline space-x-2 mb-1">
          <span class="font-semibold text-slack-text-primary text-sm">
            <%= @reply.user.name %>
          </span>
          <time class="text-xs text-slack-text-secondary">
            <%= format_time(@reply.inserted_at) %>
          </time>
          <%= if @reply.edited_at do %>
            <span class="text-xs text-slack-text-secondary">(edited)</span>
          <% end %>
        </div>

        <div class="text-slack-text-primary text-sm">
          <%= @reply.content %>
        </div>

        <!-- Reply Reactions -->
        <%= if @reply.reactions && length(@reply.reactions) > 0 do %>
          <div class="flex flex-wrap gap-1 mt-2">
            <%= for {emoji, users} <- group_reactions(@reply.reactions) do %>
              <button
                phx-click="add_reply_reaction"
                phx-value-reply_id={@reply.id}
                phx-value-emoji={emoji}
                phx-target={@target}
                class={[
                  "flex items-center space-x-1 px-2 py-1 rounded-full text-xs border transition-colors",
                  if user_reacted?(@reply.reactions, @current_user.id, emoji) do
                    "bg-slack-primary-light border-slack-primary text-slack-primary"
                  else
                    "border-slack-border hover:border-slack-border-dark"
                  end
                ]}
              >
                <span><%= emoji %></span>
                <span><%= length(users) %></span>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Reply Actions -->
      <div class="opacity-0 group-hover:opacity-100 transition-opacity flex items-start space-x-1 mt-1">
        <button
          phx-click="add_reply_reaction"
          phx-value-reply_id={@reply.id}
          phx-value-emoji="👍"
          phx-target={@target}
          class="p-1 rounded hover:bg-slack-bg text-slack-text-secondary hover:text-slack-text-primary"
          title="Add reaction"
        >
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5" />
          </svg>
        </button>

        <%= if @reply.user_id == @current_user.id do %>
          <button
            phx-click="edit_reply"
            phx-value-reply_id={@reply.id}
            phx-target={@target}
            class="p-1 rounded hover:bg-slack-bg text-slack-text-secondary hover:text-slack-text-primary"
            title="Edit reply"
          >
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
            </svg>
          </button>

          <button
            phx-click="delete_reply"
            phx-value-reply_id={@reply.id}
            phx-target={@target}
            phx-data-confirm="Are you sure you want to delete this reply?"
            class="p-1 rounded hover:bg-red-50 text-slack-text-secondary hover:text-red-600"
            title="Delete reply"
          >
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # Private helper functions
  
  defp load_thread_data(socket, message_id) do
    # Load parent message and thread replies
    parent_message = load_parent_message(message_id)
    thread_replies = load_thread_replies(message_id)
    
    socket
    |> assign(:parent_message, parent_message)
    |> assign(:thread_replies, thread_replies)
    |> assign(:loading, false)
  end

  defp format_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "just now"
      diff when diff < 3600 -> "#{div(diff, 60)}m ago"
      diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
      _diff -> Calendar.strftime(datetime, "%m/%d %I:%M %p")
    end
  end

  defp group_reactions(reactions) do
    reactions
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, reactions} -> 
        {emoji, Enum.map(reactions, & &1.user_id)} 
       end)
  end

  defp user_reacted?(reactions, user_id, emoji) do
    Enum.any?(reactions, fn reaction ->
      reaction.user_id == user_id && reaction.emoji == emoji
    end)
  end

  # Mock functions - replace with actual implementations
  defp load_parent_message(_message_id) do
    %{
      id: "msg_1",
      content: "This is the parent message that started the thread",
      user: %{id: "user_1", name: "John Doe", avatar_url: "/images/default-avatar.png"},
      inserted_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
    }
  end

  defp load_thread_replies(_message_id) do
    []
  end

  defp send_thread_reply(_message_id, _content, _user), do: {:error, :not_implemented}
  defp edit_thread_reply(_reply_id, _content, _user), do: {:error, :not_implemented}
  defp delete_thread_reply(_reply_id, _user), do: {:error, :not_implemented}
  defp add_reply_reaction(_reply_id, _emoji, _user), do: {:error, :not_implemented}
end