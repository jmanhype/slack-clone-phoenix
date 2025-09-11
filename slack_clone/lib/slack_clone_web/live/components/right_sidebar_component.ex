defmodule SlackCloneWeb.RightSidebarComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "w-slack-thread bg-slack-bg-primary border-l border-slack-border flex flex-col h-full transition-transform duration-200",
      if(@show, do: "translate-x-0", else: "translate-x-full"),
      "mobile-hidden"
    ]}>
      <%= case @mode do %>
        <% "thread" -> %>
          <.thread_view {assigns} />
        <% "details" -> %>
          <.details_view {assigns} />
        <% "canvas" -> %>
          <.canvas_view {assigns} />
        <% _ -> %>
          <.details_view {assigns} />
      <% end %>
    </div>
    """
  end
  
  # Thread View
  defp thread_view(assigns) do
    ~H"""
    <!-- Thread Header -->
    <div class="flex items-center justify-between p-4 border-b border-slack-border">
      <h2 class="text-lg font-bold text-slack-text-primary">Thread</h2>
      <button 
        phx-click="close_sidebar" 
        class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
      >
        <.icon name="hero-x-mark" class="w-5 h-5 text-slack-text-muted" />
      </button>
    </div>
    
    <!-- Original Message -->
    <div class="border-b border-slack-border p-4">
      <div class="flex space-x-3">
        <img 
          src={@thread_message.user.avatar_url || "/images/default-avatar.png"} 
          alt={@thread_message.user.name}
          class="w-10 h-10 rounded object-cover"
        />
        <div class="flex-1 min-w-0">
          <div class="flex items-baseline space-x-2 mb-1">
            <span class="font-bold text-slack-text-primary text-sm">
              {@thread_message.user.display_name || @thread_message.user.name}
            </span>
            <span class="text-xs text-slack-text-muted">
              {format_timestamp(@thread_message.inserted_at)}
            </span>
          </div>
          
          <div class="slack-text-base text-slack-text-primary leading-relaxed">
            {raw(format_message_content(@thread_message.content))}
          </div>
          
          <!-- Original message reactions -->
          <%= if @thread_message.reactions && length(@thread_message.reactions) > 0 do %>
            <div class="flex flex-wrap gap-1 mt-2">
              <%= for reaction <- @thread_message.reactions do %>
                <button class={[
                  "reaction-button inline-flex items-center space-x-1 px-2 py-1 rounded-full text-xs transition-all duration-150",
                  if(reaction.reacted_by_current_user, do: "reacted", else: "")
                ]}>
                  <span>{reaction.emoji}</span>
                  <span class="font-medium">{reaction.count}</span>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    
    <!-- Thread Replies -->
    <div class="flex-1 overflow-y-auto slack-scrollbar">
      <div class="p-4 space-y-4">
        <%= if length(@thread_replies) > 0 do %>
          <%= for reply <- @thread_replies do %>
            <div class="flex space-x-3">
              <img 
                src={reply.user.avatar_url || "/images/default-avatar.png"} 
                alt={reply.user.name}
                class="w-8 h-8 rounded object-cover"
              />
              <div class="flex-1 min-w-0">
                <div class="flex items-baseline space-x-2 mb-1">
                  <span class="font-bold text-slack-text-primary text-sm">
                    {reply.user.display_name || reply.user.name}
                  </span>
                  <span class="text-xs text-slack-text-muted">
                    {format_timestamp(reply.inserted_at)}
                  </span>
                </div>
                
                <div class="slack-text-sm text-slack-text-primary leading-relaxed">
                  {raw(format_message_content(reply.content))}
                </div>
                
                <!-- Reply reactions -->
                <%= if reply.reactions && length(reply.reactions) > 0 do %>
                  <div class="flex flex-wrap gap-1 mt-2">
                    <%= for reaction <- reply.reactions do %>
                      <button class={[
                        "reaction-button inline-flex items-center space-x-1 px-2 py-1 rounded-full text-xs transition-all duration-150",
                        if(reaction.reacted_by_current_user, do: "reacted", else: "")
                      ]}>
                        <span>{reaction.emoji}</span>
                        <span class="font-medium">{reaction.count}</span>
                      </button>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        <% else %>
          <div class="text-center py-8">
            <div class="w-16 h-16 bg-slack-bg-tertiary rounded-lg flex items-center justify-center mx-auto mb-3">
              <.icon name="hero-chat-bubble-left" class="w-8 h-8 text-slack-text-muted" />
            </div>
            <p class="text-slack-text-muted text-sm">No replies yet.</p>
            <p class="text-slack-text-muted text-xs mt-1">Be the first to reply!</p>
          </div>
        <% end %>
      </div>
    </div>
    
    <!-- Thread Reply Input -->
    <div class="border-t border-slack-border">
      <.live_component 
        module={SlackCloneWeb.MessageInputComponent} 
        id="thread-input"
        channel_id={@channel_id}
        thread_id={@thread_message.id}
        is_thread={true}
        placeholder={"Reply to thread..."}
      />
    </div>
    """
  end
  
  # Channel/DM Details View
  defp details_view(assigns) do
    ~H"""
    <!-- Details Header -->
    <div class="flex items-center justify-between p-4 border-b border-slack-border">
      <h2 class="text-lg font-bold text-slack-text-primary">
        <%= if @channel_type == "channel" do %>
          About this channel
        <% else %>
          Profile
        <% end %>
      </h2>
      <button 
        phx-click="close_sidebar" 
        class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
      >
        <.icon name="hero-x-mark" class="w-5 h-5 text-slack-text-muted" />
      </button>
    </div>
    
    <!-- Details Content -->
    <div class="flex-1 overflow-y-auto slack-scrollbar">
      <%= if @channel_type == "channel" do %>
        <!-- Channel Details -->
        <div class="p-4 space-y-6">
          <!-- Channel Info -->
          <div>
            <div class="flex items-center space-x-3 mb-3">
              <div class="w-12 h-12 bg-slack-light-purple rounded-lg flex items-center justify-center">
                <%= if @channel.is_private do %>
                  <.icon name="hero-lock-closed" class="w-6 h-6 text-slack-purple" />
                <% else %>
                  <span class="text-xl font-bold text-slack-purple">#</span>
                <% end %>
              </div>
              <div>
                <h3 class="text-lg font-bold text-slack-text-primary">#{@channel.name}</h3>
                <p class="text-sm text-slack-text-muted">
                  <%= if @channel.is_private, do: "Private channel", else: "Public channel" %> • {@channel.member_count} members
                </p>
              </div>
            </div>
            
            <%= if @channel.description do %>
              <p class="text-slack-text-secondary">{@channel.description}</p>
            <% else %>
              <button class="text-slack-blue hover:underline text-sm">
                Add a description
              </button>
            <% end %>
          </div>
          
          <!-- Channel Settings -->
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <.icon name="hero-bell" class="w-5 h-5 text-slack-text-muted" />
                <div>
                  <p class="text-sm font-medium text-slack-text-primary">Notifications</p>
                  <p class="text-xs text-slack-text-muted">Get notified about new messages</p>
                </div>
              </div>
              <button class="text-slack-blue text-sm hover:underline">
                Edit
              </button>
            </div>
            
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <.icon name="hero-star" class="w-5 h-5 text-slack-text-muted" />
                <div>
                  <p class="text-sm font-medium text-slack-text-primary">
                    <%= if @channel.starred, do: "Starred", else: "Add to favorites" %>
                  </p>
                  <p class="text-xs text-slack-text-muted">Quick access from sidebar</p>
                </div>
              </div>
              <button class="text-slack-blue text-sm hover:underline">
                <%= if @channel.starred, do: "Remove", else: "Add" %>
              </button>
            </div>
          </div>
          
          <!-- Members Section -->
          <div>
            <div class="flex items-center justify-between mb-3">
              <h4 class="text-sm font-medium text-slack-text-primary">
                Members ({@channel.member_count})
              </h4>
              <button class="text-slack-blue text-sm hover:underline">
                Add people
              </button>
            </div>
            
            <div class="space-y-2">
              <%= for member <- Enum.take(@channel.members || [], 10) do %>
                <div class="flex items-center space-x-3">
                  <div class="relative">
                    <img 
                      src={member.avatar_url || "/images/default-avatar.png"}
                      alt={member.name}
                      class="w-8 h-8 rounded object-cover"
                    />
                    <div class={[
                      "absolute -bottom-0.5 -right-0.5 w-3 h-3 border-2 border-white rounded-full",
                      case member.presence do
                        "active" -> "presence-active"
                        "away" -> "presence-away"
                        _ -> "presence-offline"
                      end
                    ]}></div>
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-slack-text-primary truncate">
                      {member.display_name || member.name}
                    </p>
                    <%= if member.title do %>
                      <p class="text-xs text-slack-text-muted truncate">{member.title}</p>
                    <% end %>
                  </div>
                  <%= if member.is_admin do %>
                    <span class="text-xs bg-slack-yellow text-slack-text-primary px-2 py-0.5 rounded">
                      Admin
                    </span>
                  <% end %>
                </div>
              <% end %>
              
              <%= if length(@channel.members || []) > 10 do %>
                <button class="text-slack-blue text-sm hover:underline">
                  Show all {@channel.member_count} members
                </button>
              <% end %>
            </div>
          </div>
          
          <!-- Pinned Messages -->
          <%= if @channel.pinned_messages && length(@channel.pinned_messages) > 0 do %>
            <div>
              <h4 class="text-sm font-medium text-slack-text-primary mb-3">
                Pinned messages ({length(@channel.pinned_messages)})
              </h4>
              
              <div class="space-y-3">
                <%= for pinned <- @channel.pinned_messages do %>
                  <div class="p-3 border border-slack-border rounded-lg hover:bg-slack-bg-secondary cursor-pointer">
                    <div class="flex items-center space-x-2 mb-1">
                      <img 
                        src={pinned.user.avatar_url || "/images/default-avatar.png"}
                        alt={pinned.user.name}
                        class="w-5 h-5 rounded object-cover"
                      />
                      <span class="text-sm font-medium text-slack-text-primary">
                        {pinned.user.display_name || pinned.user.name}
                      </span>
                      <span class="text-xs text-slack-text-muted">
                        {format_timestamp(pinned.inserted_at)}
                      </span>
                    </div>
                    <p class="text-sm text-slack-text-secondary line-clamp-2">
                      {pinned.content}
                    </p>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          
          <!-- Files -->
          <div>
            <div class="flex items-center justify-between mb-3">
              <h4 class="text-sm font-medium text-slack-text-primary">Files</h4>
              <button class="text-slack-blue text-sm hover:underline">
                See all
              </button>
            </div>
            
            <%= if @channel.recent_files && length(@channel.recent_files) > 0 do %>
              <div class="space-y-2">
                <%= for file <- Enum.take(@channel.recent_files, 5) do %>
                  <div class="flex items-center space-x-3 p-2 hover:bg-slack-bg-secondary rounded cursor-pointer">
                    <div class="w-8 h-8 bg-slack-bg-tertiary rounded flex items-center justify-center">
                      <.icon name="hero-document" class="w-4 h-4 text-slack-text-muted" />
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-slack-text-primary truncate">
                        {file.filename}
                      </p>
                      <p class="text-xs text-slack-text-muted">
                        {format_file_size(file.size)} • {format_timestamp(file.uploaded_at)}
                      </p>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-sm text-slack-text-muted">No files shared yet.</p>
            <% end %>
          </div>
        </div>
      <% else %>
        <!-- User Profile Details (for DMs) -->
        <div class="p-4 space-y-6">
          <!-- User Info -->
          <div class="text-center">
            <img 
              src={@dm_user.avatar_url || "/images/default-avatar.png"}
              alt={@dm_user.name}
              class="w-20 h-20 rounded-lg object-cover mx-auto mb-3"
            />
            <h3 class="text-lg font-bold text-slack-text-primary">
              {@dm_user.display_name || @dm_user.name}
            </h3>
            <%= if @dm_user.title do %>
              <p class="text-sm text-slack-text-muted">{@dm_user.title}</p>
            <% end %>
            
            <!-- Presence status -->
            <div class="flex items-center justify-center space-x-2 mt-2">
              <div class={[
                "w-2 h-2 rounded-full",
                case @dm_user.presence do
                  "active" -> "presence-active"
                  "away" -> "presence-away"
                  _ -> "presence-offline"
                end
              ]}></div>
              <span class="text-xs text-slack-text-muted">
                <%= case @dm_user.presence do %>
                  <% "active" -> %>Active
                  <% "away" -> %>Away
                  <% _ -> %>Offline
                <% end %>
              </span>
            </div>
          </div>
          
          <!-- Contact Info -->
          <%= if @dm_user.email or @dm_user.phone do %>
            <div>
              <h4 class="text-sm font-medium text-slack-text-primary mb-3">Contact</h4>
              <div class="space-y-2">
                <%= if @dm_user.email do %>
                  <div class="flex items-center space-x-3">
                    <.icon name="hero-envelope" class="w-4 h-4 text-slack-text-muted" />
                    <span class="text-sm text-slack-text-secondary">{@dm_user.email}</span>
                  </div>
                <% end %>
                <%= if @dm_user.phone do %>
                  <div class="flex items-center space-x-3">
                    <.icon name="hero-phone" class="w-4 h-4 text-slack-text-muted" />
                    <span class="text-sm text-slack-text-secondary">{@dm_user.phone}</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          
          <!-- Quick Actions -->
          <div class="space-y-2">
            <button class="w-full p-3 bg-slack-bg-secondary hover:bg-slack-bg-tertiary rounded-lg transition-colors text-left">
              <div class="flex items-center space-x-3">
                <.icon name="hero-video-camera" class="w-5 h-5 text-slack-text-muted" />
                <span class="text-sm font-medium text-slack-text-primary">Start a call</span>
              </div>
            </button>
            
            <button class="w-full p-3 bg-slack-bg-secondary hover:bg-slack-bg-tertiary rounded-lg transition-colors text-left">
              <div class="flex items-center space-x-3">
                <.icon name="hero-user-plus" class="w-5 h-5 text-slack-text-muted" />
                <span class="text-sm font-medium text-slack-text-primary">View full profile</span>
              </div>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Canvas/Workflow View
  defp canvas_view(assigns) do
    ~H"""
    <!-- Canvas Header -->
    <div class="flex items-center justify-between p-4 border-b border-slack-border">
      <h2 class="text-lg font-bold text-slack-text-primary">Canvas</h2>
      <div class="flex items-center space-x-2">
        <button class="p-1 hover:bg-slack-bg-secondary rounded transition-colors">
          <.icon name="hero-share" class="w-5 h-5 text-slack-text-muted" />
        </button>
        <button 
          phx-click="close_sidebar" 
          class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
        >
          <.icon name="hero-x-mark" class="w-5 h-5 text-slack-text-muted" />
        </button>
      </div>
    </div>
    
    <!-- Canvas Content -->
    <div class="flex-1 p-4">
      <div class="text-center py-12">
        <div class="w-16 h-16 bg-slack-bg-tertiary rounded-lg flex items-center justify-center mx-auto mb-3">
          <.icon name="hero-document-text" class="w-8 h-8 text-slack-text-muted" />
        </div>
        <p class="text-slack-text-muted text-sm">Canvas coming soon!</p>
        <p class="text-slack-text-muted text-xs mt-1">Collaborative documents and workflows.</p>
      </div>
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show, fn -> false end)
     |> assign_new(:mode, fn -> "details" end)}
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
  
  defp format_message_content(content) do
    content
    |> String.replace(~r/\*\*(.*?)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/\*(.*?)\*/, "<em>\\1</em>")
    |> String.replace(~r/`(.*?)`/, "<code>\\1</code>")
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