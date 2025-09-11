defmodule SlackCloneWeb.MessageLive do
  @moduledoc """
  LiveView component for individual messages with real-time updates,
  reactions, and threading support.
  """
  use SlackCloneWeb, :live_component

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:editing, false)
      |> assign(:edit_content, "")
      |> assign(:show_reactions, false)
      |> assign(:thread_replies_count, 0)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_message_metadata()

    {:ok, socket}
  end

  @impl true
  def handle_event("start_edit", _params, socket) do
    socket =
      socket
      |> assign(:editing, true)
      |> assign(:edit_content, socket.assigns.message.content)

    {:noreply, socket}
  end

  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(:editing, false)
      |> assign(:edit_content, "")

    {:noreply, socket}
  end

  def handle_event("save_edit", %{"content" => content}, socket) do
    send(self(), {:edit_message, socket.assigns.message.id, content})
    
    socket =
      socket
      |> assign(:editing, false)
      |> assign(:edit_content, "")

    {:noreply, socket}
  end

  def handle_event("delete_message", _params, socket) do
    send(self(), {:delete_message, socket.assigns.message.id})
    {:noreply, socket}
  end

  def handle_event("add_reaction", %{"emoji" => emoji}, socket) do
    send(self(), {:add_reaction, socket.assigns.message.id, emoji})
    {:noreply, socket}
  end

  def handle_event("remove_reaction", %{"reaction_id" => reaction_id}, socket) do
    send(self(), {:remove_reaction, reaction_id})
    {:noreply, socket}
  end

  def handle_event("open_thread", _params, socket) do
    send(self(), {:open_thread, socket.assigns.message.id})
    {:noreply, socket}
  end

  def handle_event("toggle_reactions", _params, socket) do
    {:noreply, assign(socket, :show_reactions, !socket.assigns.show_reactions)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div 
      class="group hover:bg-slack-bg-hover p-2 rounded transition-colors"
      id={"message-#{@message.id}"}
    >
      <div class="flex space-x-3">
        <!-- Avatar -->
        <img 
          src={@message.user.avatar_url} 
          alt={@message.user.name}
          class="w-9 h-9 rounded flex-shrink-0"
        />
        
        <!-- Message Content -->
        <div class="flex-1 min-w-0">
          <!-- Message Header -->
          <div class="flex items-baseline space-x-2 mb-1">
            <span class="font-semibold text-slack-text-primary text-sm">
              <%= @message.user.name %>
            </span>
            <time class="text-xs text-slack-text-secondary">
              <%= format_time(@message.inserted_at) %>
            </time>
            <%= if @message.edited_at do %>
              <span class="text-xs text-slack-text-secondary">(edited)</span>
            <% end %>
          </div>

          <!-- Message Body -->
          <div class="text-slack-text-primary">
            <%= if @editing do %>
              <form phx-submit="save_edit" phx-target={@myself} class="space-y-2">
                <textarea
                  id={"edit-message-#{@message.id}"}
                  name="content"
                  class="w-full p-2 border border-slack-border rounded resize-none focus:border-slack-primary focus:ring-1 focus:ring-slack-primary"
                  rows="3"
                  value={@edit_content}
                  phx-hook="AutoResize"
                ><%= @edit_content %></textarea>
                <div class="flex space-x-2">
                  <button 
                    type="submit"
                    class="bg-slack-primary hover:bg-slack-primary-hover text-white px-3 py-1 rounded text-sm"
                  >
                    Save
                  </button>
                  <button 
                    type="button"
                    phx-click="cancel_edit"
                    phx-target={@myself}
                    class="border border-slack-border hover:bg-slack-bg px-3 py-1 rounded text-sm"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            <% else %>
              <div class="prose prose-sm max-w-none">
                <%= render_message_content(@message.content) %>
              </div>

              <!-- Message Attachments -->
              <%= if @message.attachments && length(@message.attachments) > 0 do %>
                <div class="mt-2 space-y-2">
                  <%= for attachment <- @message.attachments do %>
                    <.message_attachment attachment={attachment} />
                  <% end %>
                </div>
              <% end %>

              <!-- Reactions -->
              <%= if @message.reactions && length(@message.reactions) > 0 do %>
                <div class="flex flex-wrap gap-1 mt-2">
                  <%= for {emoji, users} <- group_reactions(@message.reactions) do %>
                    <button
                      phx-click={if user_reacted?(@message.reactions, @current_user.id, emoji), do: "remove_reaction", else: "add_reaction"}
                      phx-value-emoji={emoji}
                      phx-target={@myself}
                      class={[
                        "flex items-center space-x-1 px-2 py-1 rounded-full text-xs border transition-colors",
                        if user_reacted?(@message.reactions, @current_user.id, emoji) do
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
                  
                  <!-- Add Reaction Button -->
                  <button
                    phx-click="toggle_reactions"
                    phx-target={@myself}
                    class="w-6 h-6 rounded-full border border-slack-border hover:border-slack-border-dark flex items-center justify-center text-slack-text-secondary hover:text-slack-text-primary transition-colors"
                    title="Add reaction"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                    </svg>
                  </button>
                </div>

                <!-- Reaction Picker -->
                <%= if @show_reactions do %>
                  <div class="mt-2 p-2 border border-slack-border rounded-lg bg-white shadow-sm">
                    <div class="flex flex-wrap gap-2">
                      <%= for emoji <- common_emojis() do %>
                        <button
                          phx-click="add_reaction"
                          phx-value-emoji={emoji}
                          phx-target={@myself}
                          class="hover:bg-slack-bg p-1 rounded text-lg"
                        >
                          <%= emoji %>
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>

              <!-- Thread Info -->
              <%= if @thread_replies_count > 0 do %>
                <button
                  phx-click="open_thread"
                  phx-target={@myself}
                  class="flex items-center space-x-2 mt-2 text-xs text-slack-primary hover:text-slack-primary-hover"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                  </svg>
                  <span><%= @thread_replies_count %> replies</span>
                  <span class="text-slack-text-secondary">Last reply <%= format_time(@message.last_thread_reply_at) %></span>
                </button>
              <% end %>

              <!-- Read Receipts -->
              <%= if @message.read_receipts && length(@message.read_receipts) > 0 do %>
                <div class="flex items-center space-x-1 mt-1">
                  <svg class="w-3 h-3 text-slack-text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                  <span class="text-xs text-slack-text-secondary">
                    Read by <%= format_read_receipts(@message.read_receipts) %>
                  </span>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <!-- Message Actions (shown on hover) -->
        <div class="opacity-0 group-hover:opacity-100 transition-opacity flex items-center space-x-1">
          <button
            phx-click="add_reaction"
            phx-value-emoji="👍"
            phx-target={@myself}
            class="p-1 rounded hover:bg-slack-bg text-slack-text-secondary hover:text-slack-text-primary"
            title="Add reaction"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5" />
            </svg>
          </button>
          
          <button
            phx-click="open_thread"
            phx-target={@myself}
            class="p-1 rounded hover:bg-slack-bg text-slack-text-secondary hover:text-slack-text-primary"
            title="Reply in thread"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </button>

          <%= if @can_edit do %>
            <button
              phx-click="start_edit"
              phx-target={@myself}
              class="p-1 rounded hover:bg-slack-bg text-slack-text-secondary hover:text-slack-text-primary"
              title="Edit message"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </button>
          <% end %>

          <%= if @can_delete do %>
            <button
              phx-click="delete_message"
              phx-target={@myself}
              phx-data-confirm="Are you sure you want to delete this message?"
              class="p-1 rounded hover:bg-red-50 text-slack-text-secondary hover:text-red-600"
              title="Delete message"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper components and functions
  
  defp message_attachment(assigns) do
    ~H"""
    <div class="border border-slack-border rounded p-3 max-w-sm">
      <%= if @attachment.type == "image" do %>
        <img 
          src={@attachment.url} 
          alt={@attachment.name}
          class="max-w-full h-auto rounded cursor-pointer"
          phx-click="show_image_modal"
          phx-value-url={@attachment.url}
        />
      <% else %>
        <div class="flex items-center space-x-3">
          <div class="flex-shrink-0">
            <svg class="w-8 h-8 text-slack-text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-slack-text-primary truncate">
              <%= @attachment.name %>
            </p>
            <p class="text-xs text-slack-text-secondary">
              <%= format_file_size(@attachment.size) %>
            </p>
          </div>
          <a
            href={@attachment.url}
            download
            class="text-slack-primary hover:text-slack-primary-hover"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </a>
        </div>
      <% end %>
    </div>
    """
  end

  # Private helper functions
  
  defp load_message_metadata(socket) do
    # Load additional metadata like thread replies count
    thread_replies_count = count_thread_replies(socket.assigns.message.id)
    
    assign(socket, :thread_replies_count, thread_replies_count)
  end

  defp render_message_content(content) do
    content
    |> String.replace(~r/@(\w+)/, "<span class=\"text-slack-primary font-medium\">@\\1</span>")
    |> String.replace(~r/#(\w+)/, "<span class=\"text-slack-primary font-medium\">#\\1</span>")
    |> String.replace(~r/\*\*(.*?)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/\*(.*?)\*/, "<em>\\1</em>")
    |> String.replace(~r/`(.*?)`/, "<code class=\"bg-slack-code px-1 py-0.5 rounded text-sm\">\\1</code>")
    |> Phoenix.HTML.raw()
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

  defp common_emojis do
    ["👍", "👎", "😊", "😢", "😍", "😮", "😡", "🎉", "❤️", "👏"]
  end

  defp format_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "just now"
      diff when diff < 3600 -> "#{div(diff, 60)}m ago"
      diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
      _diff -> Calendar.strftime(datetime, "%m/%d %I:%M %p")
    end
  end

  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1_048_576, do: "#{Float.round(size / 1024, 1)} KB"
  defp format_file_size(size), do: "#{Float.round(size / 1_048_576, 1)} MB"

  defp format_read_receipts(user_ids) when length(user_ids) <= 3 do
    # Mock user names - replace with actual user loading
    Enum.join(user_ids, ", ")
  end

  defp format_read_receipts(user_ids) do
    "#{length(user_ids)} people"
  end

  # Mock functions - replace with actual implementations
  defp count_thread_replies(_message_id), do: 0
end