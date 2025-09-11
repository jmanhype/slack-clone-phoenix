defmodule SlackCloneWeb.MessageComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "message-container group py-2 hover:bg-slack-bg-secondary transition-colors duration-150",
      if(@compact, do: "compact", else: "")
    ]}>
      <div class="flex space-x-3">
        <!-- Avatar Column -->
        <div class="w-10 flex-shrink-0">
          <%= if @show_avatar do %>
            <img 
              src={@message.user.avatar_url || "/images/default-avatar.png"} 
              alt={@message.user.name}
              class="w-10 h-10 rounded object-cover avatar"
            />
          <% else %>
            <!-- Timestamp placeholder for threaded messages -->
            <div class="message-timestamp text-xs text-slack-text-muted text-right pt-0.5 hover:underline cursor-pointer">
              {format_time(@message.inserted_at)}
            </div>
          <% end %>
        </div>
        
        <!-- Message Content Column -->
        <div class="flex-1 min-w-0">
          <%= if @show_avatar do %>
            <!-- Header with name and timestamp -->
            <div class="flex items-baseline space-x-2 mb-1">
              <button class="font-bold text-slack-text-primary hover:underline text-sm">
                {@message.user.display_name || @message.user.name}
              </button>
              
              <%= if @message.user.is_bot do %>
                <span class="text-xs bg-slack-border text-slack-text-muted px-1.5 py-0.5 rounded font-medium">
                  BOT
                </span>
              <% end %>
              
              <span class="message-timestamp text-xs text-slack-text-muted hover:underline cursor-pointer">
                {format_timestamp(@message.inserted_at)}
              </span>
              
              <%= if @message.edited_at do %>
                <span class="text-xs text-slack-text-muted">(edited)</span>
              <% end %>
            </div>
          <% end %>
          
          <!-- Message Content -->
          <div class="slack-text-base text-slack-text-primary leading-relaxed">
            <!-- Text content with formatting -->
            <div class="message-content" phx-no-format>
              {raw(format_message_content(@message.content))}
            </div>
            
            <!-- Attachments -->
            <%= if @message.attachments do %>
              <div class="mt-2 space-y-2">
                <%= for attachment <- @message.attachments do %>
                  <%= case attachment.type do %>
                    <% "image" -> %>
                      <div class="border border-slack-border rounded-lg overflow-hidden max-w-md">
                        <img 
                          src={attachment.url} 
                          alt={attachment.filename}
                          class="w-full h-auto cursor-pointer hover:opacity-90 transition-opacity"
                          phx-click="open_image"
                          phx-value-url={attachment.url}
                        />
                        <div class="p-2 bg-slack-bg-secondary">
                          <div class="text-xs text-slack-text-muted">{attachment.filename}</div>
                        </div>
                      </div>
                    
                    <% "file" -> %>
                      <div class="flex items-center space-x-3 p-3 border border-slack-border rounded-lg max-w-md hover:bg-slack-bg-secondary cursor-pointer">
                        <div class="w-10 h-10 bg-slack-bg-tertiary rounded flex items-center justify-center">
                          <.icon name="hero-document" class="w-5 h-5 text-slack-text-muted" />
                        </div>
                        <div class="flex-1 min-w-0">
                          <div class="text-sm font-medium text-slack-blue hover:underline">
                            {attachment.filename}
                          </div>
                          <div class="text-xs text-slack-text-muted">
                            {format_file_size(attachment.size)}
                          </div>
                        </div>
                        <.icon name="hero-arrow-down-tray" class="w-4 h-4 text-slack-text-muted" />
                      </div>
                    
                    <% "link" -> %>
                      <div class="border border-slack-border rounded-lg max-w-md overflow-hidden hover:border-slack-blue cursor-pointer">
                        <%= if attachment.preview_image do %>
                          <img src={attachment.preview_image} alt="" class="w-full h-32 object-cover" />
                        <% end %>
                        <div class="p-3">
                          <div class="text-sm font-medium text-slack-blue hover:underline">
                            {attachment.title || attachment.url}
                          </div>
                          <%= if attachment.description do %>
                            <div class="text-sm text-slack-text-muted mt-1 line-clamp-2">
                              {attachment.description}
                            </div>
                          <% end %>
                          <div class="text-xs text-slack-text-muted mt-1">
                            {URI.parse(attachment.url).host}
                          </div>
                        </div>
                      </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
          </div>
          
          <!-- Reactions -->
          <%= if @message.reactions && length(@message.reactions) > 0 do %>
            <div class="flex flex-wrap gap-1 mt-2">
              <%= for reaction <- @message.reactions do %>
                <button 
                  class={[
                    "reaction-button inline-flex items-center space-x-1 px-2 py-1 rounded-full text-xs transition-all duration-150",
                    if(reaction.reacted_by_current_user, do: "reacted", else: "")
                  ]}
                  phx-click="toggle_reaction"
                  phx-value-message-id={@message.id}
                  phx-value-emoji={reaction.emoji}
                >
                  <span>{reaction.emoji}</span>
                  <span class="font-medium">{reaction.count}</span>
                </button>
              <% end %>
              
              <!-- Add reaction button -->
              <button 
                class="reaction-button inline-flex items-center px-2 py-1 rounded-full text-xs transition-all duration-150 opacity-0 group-hover:opacity-100"
                phx-click="show_reaction_picker"
                phx-value-message-id={@message.id}
              >
                <.icon name="hero-face-smile" class="w-3 h-3" />
              </button>
            </div>
          <% else %>
            <!-- Show add reaction button on hover -->
            <div class="opacity-0 group-hover:opacity-100 transition-opacity duration-150 mt-1">
              <button 
                class="reaction-button inline-flex items-center px-2 py-1 rounded-full text-xs transition-all duration-150"
                phx-click="show_reaction_picker"
                phx-value-message-id={@message.id}
              >
                <.icon name="hero-face-smile" class="w-3 h-3" />
              </button>
            </div>
          <% end %>
          
          <!-- Thread reply indicator -->
          <%= if @message.thread_replies && @message.thread_replies > 0 do %>
            <div class="thread-indicator mt-2">
              <button 
                class="flex items-center space-x-2 text-xs text-slack-blue hover:underline"
                phx-click="open_thread"
                phx-value-message-id={@message.id}
              >
                <div class="flex -space-x-1">
                  <%= for {user, index} <- Enum.with_index(@message.thread_participants) |> Enum.take(3) do %>
                    <img 
                      src={user.avatar_url || "/images/default-avatar.png"} 
                      alt={user.name}
                      class="w-5 h-5 rounded border-2 border-white object-cover"
                      style={"z-index: #{10 - index}"}
                    />
                  <% end %>
                </div>
                <span>
                  {if @message.thread_replies == 1, do: "1 reply", else: "#{@message.thread_replies} replies"}
                </span>
                <span class="text-slack-text-muted">Last reply {format_time(@message.thread_last_reply_at)}</span>
              </button>
            </div>
          <% end %>
        </div>
        
        <!-- Action buttons (show on hover) -->
        <div class="opacity-0 group-hover:opacity-100 transition-opacity duration-150 flex items-start space-x-1 pt-0.5">
          <!-- Quick reaction buttons -->
          <div class="flex items-center space-x-1 bg-white border border-slack-border rounded-lg shadow-sm p-1">
            <!-- Add reaction -->
            <button 
              class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
              title="Add reaction"
              phx-click="show_reaction_picker"
              phx-value-message-id={@message.id}
            >
              <.icon name="hero-face-smile" class="w-4 h-4 text-slack-text-muted" />
            </button>
            
            <!-- Reply in thread -->
            <button 
              class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
              title="Reply in thread"
              phx-click="reply_in_thread"
              phx-value-message-id={@message.id}
            >
              <.icon name="hero-chat-bubble-left" class="w-4 h-4 text-slack-text-muted" />
            </button>
            
            <!-- Share message -->
            <button 
              class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
              title="Share message"
              phx-click="share_message"
              phx-value-message-id={@message.id}
            >
              <.icon name="hero-share" class="w-4 h-4 text-slack-text-muted" />
            </button>
            
            <!-- More actions -->
            <div class="relative" x-data="{ open: false }">
              <button 
                @click="open = !open"
                class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
                title="More actions"
              >
                <.icon name="hero-ellipsis-horizontal" class="w-4 h-4 text-slack-text-muted" />
              </button>
              
              <!-- Dropdown menu -->
              <div 
                x-show="open" 
                @click.away="open = false"
                x-transition:enter="transition ease-out duration-100"
                x-transition:enter-start="transform opacity-0 scale-95"
                x-transition:enter-end="transform opacity-100 scale-100"
                x-transition:leave="transition ease-in duration-75"
                x-transition:leave-start="transform opacity-100 scale-100"
                x-transition:leave-end="transform opacity-0 scale-95"
                class="absolute right-0 mt-2 w-48 bg-white border border-slack-border rounded-lg shadow-slack-lg z-50"
              >
                <div class="py-1">
                  <%= if @message.user.id == @current_user.id do %>
                    <button class="w-full text-left px-4 py-2 text-sm text-slack-text-primary hover:bg-gray-50 flex items-center">
                      <.icon name="hero-pencil" class="w-4 h-4 mr-3" />
                      Edit message
                    </button>
                  <% end %>
                  
                  <button class="w-full text-left px-4 py-2 text-sm text-slack-text-primary hover:bg-gray-50 flex items-center">
                    <.icon name="hero-clipboard-document" class="w-4 h-4 mr-3" />
                    Copy message
                  </button>
                  
                  <button class="w-full text-left px-4 py-2 text-sm text-slack-text-primary hover:bg-gray-50 flex items-center">
                    <.icon name="hero-link" class="w-4 h-4 mr-3" />
                    Copy link
                  </button>
                  
                  <button class="w-full text-left px-4 py-2 text-sm text-slack-text-primary hover:bg-gray-50 flex items-center">
                    <.icon name="hero-bookmark" class="w-4 h-4 mr-3" />
                    Save message
                  </button>
                  
                  <div class="border-t border-slack-border my-1"></div>
                  
                  <%= if @message.user.id == @current_user.id do %>
                    <button class="w-full text-left px-4 py-2 text-sm text-slack-red hover:bg-gray-50 flex items-center">
                      <.icon name="hero-trash" class="w-4 h-4 mr-3" />
                      Delete message
                    </button>
                  <% else %>
                    <button class="w-full text-left px-4 py-2 text-sm text-slack-red hover:bg-gray-50 flex items-center">
                      <.icon name="hero-flag" class="w-4 h-4 mr-3" />
                      Report message
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
  
  # Helper functions
  defp format_timestamp(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)
    
    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m"
      diff < 86400 -> "#{div(diff, 3600)}h"
      true -> Calendar.strftime(datetime, "%m/%d/%y")
    end
  end
  
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M")
  end
  
  defp format_message_content(content) do
    # Basic markdown-like formatting
    content
    |> String.replace(~r/\*\*(.*?)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/\*(.*?)\*/, "<em>\\1</em>")
    |> String.replace(~r/`(.*?)`/, "<code>\\1</code>")
    |> String.replace(~r/@(\w+)/, "<span class='text-slack-blue font-medium'>@\\1</span>")
    |> String.replace(~r/#(\w+)/, "<span class='text-slack-blue font-medium'>#\\1</span>")
    |> String.replace("\n", "<br>")
  end
  
  defp format_file_size(size) when is_integer(size) do
    cond do
      size >= 1_000_000 -> "#{Float.round(size / 1_000_000, 1)} MB"
      size >= 1_000 -> "#{Float.round(size / 1_000, 1)} KB"
      true -> "#{size} B"
    end
  end
  
  defp format_file_size(_), do: "Unknown size"
end