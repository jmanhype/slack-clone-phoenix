defmodule SlackCloneWeb.MobileLayoutComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <!-- Mobile Layout Container -->
    <div class="md:hidden h-full flex flex-col bg-slack-bg-primary">
      <!-- Mobile Header -->
      <div class="flex items-center justify-between p-4 border-b border-slack-border bg-white">
        <!-- Left side -->
        <div class="flex items-center space-x-3">
          <%= if @show_back_button do %>
            <button 
              phx-click="mobile_navigate"
              phx-value-target="back"
              class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
            >
              <.icon name="hero-chevron-left" class="w-6 h-6 text-slack-text-primary" />
            </button>
          <% else %>
            <!-- Workspace switcher button -->
            <button 
              phx-click="mobile_navigate"
              phx-value-target="workspace_menu"
              class="flex items-center space-x-2 p-1 hover:bg-slack-bg-secondary rounded transition-colors"
            >
              <div class="w-8 h-8 bg-slack-purple rounded-lg flex items-center justify-center">
                <span class="text-white text-sm font-bold">{@workspace.initial || "W"}</span>
              </div>
              <.icon name="hero-chevron-down" class="w-4 h-4 text-slack-text-muted" />
            </button>
          <% end %>
          
          <!-- Page title -->
          <div class="min-w-0 flex-1">
            <%= case @mobile_view do %>
              <% "channels" -> %>
                <h1 class="text-lg font-bold text-slack-text-primary truncate">{@workspace.name}</h1>
              <% "channel" -> %>
                <div class="flex items-center space-x-2">
                  <%= if @channel.is_private do %>
                    <.icon name="hero-lock-closed" class="w-4 h-4 text-slack-text-secondary flex-shrink-0" />
                  <% else %>
                    <span class="text-lg font-bold text-slack-text-secondary">#</span>
                  <% end %>
                  <h1 class="text-lg font-bold text-slack-text-primary truncate">{@channel.name}</h1>
                </div>
              <% "dm" -> %>
                <div class="flex items-center space-x-2">
                  <img 
                    src={@dm_user.avatar_url || "/images/default-avatar.png"} 
                    alt={@dm_user.name}
                    class="w-6 h-6 rounded object-cover"
                  />
                  <h1 class="text-lg font-bold text-slack-text-primary truncate">
                    {@dm_user.display_name || @dm_user.name}
                  </h1>
                </div>
              <% "thread" -> %>
                <h1 class="text-lg font-bold text-slack-text-primary">Thread</h1>
            <% end %>
          </div>
        </div>
        
        <!-- Right side actions -->
        <div class="flex items-center space-x-2">
          <%= case @mobile_view do %>
            <% "channels" -> %>
              <!-- Search and new message -->
              <button 
                phx-click="mobile_navigate"
                phx-value-target="search"
                class="p-2 hover:bg-slack-bg-secondary rounded transition-colors"
              >
                <.icon name="hero-magnifying-glass" class="w-5 h-5 text-slack-text-muted" />
              </button>
              <button 
                phx-click="mobile_navigate"
                phx-value-target="new_message"
                class="p-2 hover:bg-slack-bg-secondary rounded transition-colors"
              >
                <.icon name="hero-pencil-square" class="w-5 h-5 text-slack-text-muted" />
              </button>
            
            <% view when view in ["channel", "dm"] -> %>
              <!-- Call and info buttons -->
              <%= if @mobile_view == "dm" do %>
                <button 
                  phx-click="start_call"
                  class="p-2 hover:bg-slack-bg-secondary rounded transition-colors"
                >
                  <.icon name="hero-phone" class="w-5 h-5 text-slack-text-muted" />
                </button>
              <% end %>
              
              <button 
                phx-click="mobile_navigate"
                phx-value-target="channel_info"
                class="p-2 hover:bg-slack-bg-secondary rounded transition-colors"
              >
                <.icon name="hero-information-circle" class="w-5 h-5 text-slack-text-muted" />
              </button>
            
            <% "thread" -> %>
              <!-- Thread actions -->
              <button 
                phx-click="mobile_navigate"
                phx-value-target="thread_info"
                class="p-2 hover:bg-slack-bg-secondary rounded transition-colors"
              >
                <.icon name="hero-ellipsis-vertical" class="w-5 h-5 text-slack-text-muted" />
              </button>
          <% end %>
        </div>
      </div>
      
      <!-- Mobile Content Area -->
      <div class="flex-1 overflow-hidden">
        <%= case @mobile_view do %>
          <% "channels" -> %>
            <.mobile_channel_list {assigns} />
          <% "channel" -> %>
            <.mobile_channel_view {assigns} />
          <% "dm" -> %>
            <.mobile_dm_view {assigns} />
          <% "thread" -> %>
            <.mobile_thread_view {assigns} />
          <% "search" -> %>
            <.mobile_search_view {assigns} />
          <% "channel_info" -> %>
            <.mobile_info_view {assigns} />
        <% end %>
      </div>
    </div>
    """
  end
  
  # Mobile Channel List
  defp mobile_channel_list(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto">
      <!-- Quick Actions -->
      <div class="p-4 border-b border-slack-border bg-white">
        <div class="grid grid-cols-2 gap-3">
          <button class="flex items-center space-x-3 p-3 bg-slack-bg-secondary rounded-lg">
            <.icon name="hero-chat-bubble-left-right" class="w-5 h-5 text-slack-text-muted" />
            <div class="text-left">
              <div class="text-sm font-medium text-slack-text-primary">Threads</div>
              <%= if @unread_threads > 0 do %>
                <div class="text-xs text-slack-red">{@unread_threads} unread</div>
              <% end %>
            </div>
          </button>
          
          <button class="flex items-center space-x-3 p-3 bg-slack-bg-secondary rounded-lg">
            <.icon name="hero-at-symbol" class="w-5 h-5 text-slack-text-muted" />
            <div class="text-left">
              <div class="text-sm font-medium text-slack-text-primary">Mentions</div>
              <%= if @unread_mentions > 0 do %>
                <div class="text-xs text-slack-red">{@unread_mentions} unread</div>
              <% end %>
            </div>
          </button>
        </div>
      </div>
      
      <!-- Recent Conversations -->
      <div class="p-4">
        <h3 class="text-sm font-medium text-slack-text-muted mb-3 uppercase tracking-wide">Recent</h3>
        <div class="space-y-2">
          <%= for item <- @recent_conversations do %>
            <button 
              class="w-full flex items-center space-x-3 p-3 hover:bg-slack-bg-secondary rounded-lg text-left"
              phx-click="mobile_navigate"
              phx-value-target={if item.type == "channel", do: "channel", else: "dm"}
              phx-value-id={item.id}
            >
              <%= if item.type == "channel" do %>
                <div class="w-10 h-10 bg-slack-light-purple rounded-lg flex items-center justify-center">
                  <%= if item.is_private do %>
                    <.icon name="hero-lock-closed" class="w-5 h-5 text-slack-purple" />
                  <% else %>
                    <span class="text-lg font-bold text-slack-purple">#</span>
                  <% end %>
                </div>
              <% else %>
                <img 
                  src={item.user.avatar_url || "/images/default-avatar.png"}
                  alt={item.user.name}
                  class="w-10 h-10 rounded-lg object-cover"
                />
              <% end %>
              
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between">
                  <span class="font-medium text-slack-text-primary truncate">
                    <%= if item.type == "channel" do %>
                      #{item.name}
                    <% else %>
                      {item.user.display_name || item.user.name}
                    <% end %>
                  </span>
                  <%= if item.last_message_at do %>
                    <span class="text-xs text-slack-text-muted ml-2">
                      {format_mobile_time(item.last_message_at)}
                    </span>
                  <% end %>
                </div>
                
                <%= if item.last_message do %>
                  <p class="text-sm text-slack-text-muted truncate mt-1">
                    {item.last_message}
                  </p>
                <% end %>
                
                <%= if item.unread_count > 0 do %>
                  <div class="flex items-center justify-between mt-1">
                    <span></span>
                    <span class="text-xs bg-slack-red text-white rounded-full px-2 py-0.5 min-w-[20px] text-center">
                      {item.unread_count}
                    </span>
                  </div>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>
      </div>
      
      <!-- All Channels -->
      <div class="p-4 border-t border-slack-border">
        <h3 class="text-sm font-medium text-slack-text-muted mb-3 uppercase tracking-wide">Channels</h3>
        <div class="space-y-1">
          <%= for channel <- @channels do %>
            <button 
              class="w-full flex items-center justify-between p-2 hover:bg-slack-bg-secondary rounded text-left"
              phx-click="mobile_navigate"
              phx-value-target="channel"
              phx-value-id={channel.id}
            >
              <div class="flex items-center space-x-3 min-w-0 flex-1">
                <%= if channel.is_private do %>
                  <.icon name="hero-lock-closed" class="w-4 h-4 text-slack-text-muted flex-shrink-0" />
                <% else %>
                  <span class="text-slack-text-muted flex-shrink-0">#</span>
                <% end %>
                <span class="text-sm truncate">{channel.name}</span>
              </div>
              
              <%= if channel.unread_count > 0 do %>
                <span class="text-xs bg-slack-red text-white rounded-full px-2 py-0.5 min-w-[16px] text-center ml-2">
                  {channel.unread_count}
                </span>
              <% end %>
            </button>
          <% end %>
        </div>
      </div>
      
      <!-- Direct Messages -->
      <div class="p-4 border-t border-slack-border">
        <h3 class="text-sm font-medium text-slack-text-muted mb-3 uppercase tracking-wide">Direct Messages</h3>
        <div class="space-y-1">
          <%= for dm <- @direct_messages do %>
            <button 
              class="w-full flex items-center justify-between p-2 hover:bg-slack-bg-secondary rounded text-left"
              phx-click="mobile_navigate"
              phx-value-target="dm"
              phx-value-id={dm.id}
            >
              <div class="flex items-center space-x-3 min-w-0 flex-1">
                <div class="relative">
                  <img 
                    src={dm.user.avatar_url || "/images/default-avatar.png"}
                    alt={dm.user.name}
                    class="w-6 h-6 rounded object-cover"
                  />
                  <div class={[
                    "absolute -bottom-0.5 -right-0.5 w-3 h-3 border-2 border-white rounded-full",
                    case dm.user.presence do
                      "active" -> "presence-active"
                      "away" -> "presence-away" 
                      _ -> "presence-offline"
                    end
                  ]}></div>
                </div>
                <span class="text-sm truncate">{dm.user.display_name || dm.user.name}</span>
              </div>
              
              <%= if dm.unread do %>
                <div class="w-2 h-2 bg-slack-red rounded-full ml-2"></div>
              <% end %>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  # Mobile Channel/DM View
  defp mobile_channel_view(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Messages -->
      <div class="flex-1 overflow-y-auto px-4" id="mobile-messages">
        <%= if @show_intro do %>
          <div class="py-6">
            <div class="flex items-start space-x-3 mb-4">
              <div class="w-12 h-12 bg-slack-light-purple rounded-lg flex items-center justify-center">
                <%= if @channel.is_private do %>
                  <.icon name="hero-lock-closed" class="w-6 h-6 text-slack-purple" />
                <% else %>
                  <span class="text-xl font-bold text-slack-purple">#</span>
                <% end %>
              </div>
              <div>
                <h2 class="text-lg font-bold text-slack-text-primary">
                  Welcome to #{@channel.name}!
                </h2>
                <%= if @channel.description do %>
                  <p class="text-sm text-slack-text-secondary mt-1">{@channel.description}</p>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
        
        <!-- Message List -->
        <div class="space-y-4" id="mobile-messages-list">
          <%= for {message_id, message} <- @streams.messages do %>
            <.mobile_message message={message} current_user={@current_user} />
          <% end %>
        </div>
        
        <!-- Typing indicators -->
        <%= if length(@typing_users) > 0 do %>
          <div class="py-2">
            <div class="flex items-center space-x-2 text-slack-text-muted">
              <div class="flex space-x-1">
                <div class="typing-dot"></div>
                <div class="typing-dot"></div>
                <div class="typing-dot"></div>
              </div>
              <span class="text-sm">
                <%= cond do %>
                  <% length(@typing_users) == 1 -> %>
                    {hd(@typing_users).name} is typing...
                  <% length(@typing_users) > 1 -> %>
                    Several people are typing...
                <% end %>
              </span>
            </div>
          </div>
        <% end %>
      </div>
      
      <!-- Mobile Message Input -->
      <div class="border-t border-slack-border bg-white p-4">
        <div class="flex items-end space-x-2">
          <!-- Attach button -->
          <button class="p-2 text-slack-text-muted">
            <.icon name="hero-plus" class="w-6 h-6" />
          </button>
          
          <!-- Text input -->
          <div class="flex-1 min-h-[40px] max-h-32 border border-slack-border rounded-lg">
            <textarea 
              placeholder={if @channel, do: "Message ##{@channel.name}", else: "Message #{@dm_user.display_name || @dm_user.name}"}
              class="w-full h-10 px-3 py-2 resize-none border-0 rounded-lg focus:outline-none focus:ring-1 focus:ring-slack-blue"
              rows="1"
            ></textarea>
          </div>
          
          <!-- Send button -->
          <button class="p-2 bg-slack-green text-white rounded-lg">
            <.icon name="hero-paper-airplane" class="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end
  
  defp mobile_dm_view(assigns), do: mobile_channel_view(assigns)
  
  # Mobile Thread View
  defp mobile_thread_view(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Original Message -->
      <div class="border-b border-slack-border p-4 bg-white">
        <.mobile_message message={@thread_message} current_user={@current_user} show_actions={false} />
      </div>
      
      <!-- Thread Replies -->
      <div class="flex-1 overflow-y-auto px-4">
        <div class="space-y-4 py-4">
          <%= for reply <- @thread_replies do %>
            <.mobile_message message={reply} current_user={@current_user} is_reply={true} />
          <% end %>
        </div>
      </div>
      
      <!-- Thread Input -->
      <div class="border-t border-slack-border bg-white p-4">
        <div class="flex items-end space-x-2">
          <div class="flex-1 min-h-[40px] max-h-32 border border-slack-border rounded-lg">
            <textarea 
              placeholder="Reply to thread..."
              class="w-full h-10 px-3 py-2 resize-none border-0 rounded-lg focus:outline-none focus:ring-1 focus:ring-slack-blue"
              rows="1"
            ></textarea>
          </div>
          <button class="p-2 bg-slack-green text-white rounded-lg">
            <.icon name="hero-paper-airplane" class="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end
  
  # Mobile Search View
  defp mobile_search_view(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <div class="p-4 border-b border-slack-border">
        <input 
          type="text" 
          placeholder="Search messages and files..."
          class="w-full px-3 py-2 border border-slack-border rounded-lg focus:outline-none focus:ring-1 focus:ring-slack-blue"
        />
      </div>
      
      <div class="flex-1 overflow-y-auto">
        <div class="p-4 text-center">
          <div class="w-16 h-16 bg-slack-bg-tertiary rounded-lg flex items-center justify-center mx-auto mb-3">
            <.icon name="hero-magnifying-glass" class="w-8 h-8 text-slack-text-muted" />
          </div>
          <p class="text-slack-text-muted">Start typing to search</p>
        </div>
      </div>
    </div>
    """
  end
  
  # Mobile Info View
  defp mobile_info_view(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto">
      <div class="p-4 space-y-6">
        <!-- Basic Info -->
        <div class="text-center">
          <%= if @channel do %>
            <div class="w-16 h-16 bg-slack-light-purple rounded-lg flex items-center justify-center mx-auto mb-3">
              <%= if @channel.is_private do %>
                <.icon name="hero-lock-closed" class="w-8 h-8 text-slack-purple" />
              <% else %>
                <span class="text-2xl font-bold text-slack-purple">#</span>
              <% end %>
            </div>
            <h2 class="text-xl font-bold text-slack-text-primary">#{@channel.name}</h2>
            <%= if @channel.description do %>
              <p class="text-slack-text-secondary mt-2">{@channel.description}</p>
            <% end %>
            <p class="text-sm text-slack-text-muted mt-1">{@channel.member_count} members</p>
          <% else %>
            <img 
              src={@dm_user.avatar_url || "/images/default-avatar.png"}
              alt={@dm_user.name}
              class="w-16 h-16 rounded-lg object-cover mx-auto mb-3"
            />
            <h2 class="text-xl font-bold text-slack-text-primary">
              {@dm_user.display_name || @dm_user.name}
            </h2>
            <%= if @dm_user.title do %>
              <p class="text-slack-text-secondary mt-1">{@dm_user.title}</p>
            <% end %>
          <% end %>
        </div>
        
        <!-- Actions -->
        <div class="space-y-2">
          <button class="w-full p-3 bg-slack-bg-secondary rounded-lg text-left">
            <div class="flex items-center space-x-3">
              <.icon name="hero-bell" class="w-5 h-5 text-slack-text-muted" />
              <span class="text-sm font-medium">Notification settings</span>
            </div>
          </button>
          
          <button class="w-full p-3 bg-slack-bg-secondary rounded-lg text-left">
            <div class="flex items-center space-x-3">
              <.icon name="hero-star" class="w-5 h-5 text-slack-text-muted" />
              <span class="text-sm font-medium">
                <%= if (@channel && @channel.starred) || (@dm_user && @dm_user.starred) do %>
                  Remove from favorites
                <% else %>
                  Add to favorites
                <% end %>
              </span>
            </div>
          </button>
          
          <%= if @channel do %>
            <button class="w-full p-3 bg-slack-bg-secondary rounded-lg text-left">
              <div class="flex items-center space-x-3">
                <.icon name="hero-user-group" class="w-5 h-5 text-slack-text-muted" />
                <span class="text-sm font-medium">View members</span>
              </div>
            </button>
          <% else %>
            <button class="w-full p-3 bg-slack-bg-secondary rounded-lg text-left">
              <div class="flex items-center space-x-3">
                <.icon name="hero-video-camera" class="w-5 h-5 text-slack-text-muted" />
                <span class="text-sm font-medium">Start a call</span>
              </div>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  # Mobile Message Component
  defp mobile_message(assigns) do
    assigns = assign_new(assigns, :show_actions, fn -> true end)
    assigns = assign_new(assigns, :is_reply, fn -> false end)
    
    ~H"""
    <div class={["flex space-x-3", if(@is_reply, do: "ml-6", else: "")]}>
      <img 
        src={@message.user.avatar_url || "/images/default-avatar.png"}
        alt={@message.user.name}
        class={if @is_reply, do: "w-6 h-6 rounded", else: "w-8 h-8 rounded"}
      />
      
      <div class="flex-1 min-w-0">
        <div class="flex items-baseline space-x-2 mb-1">
          <span class="font-bold text-slack-text-primary text-sm">
            {@message.user.display_name || @message.user.name}
          </span>
          <span class="text-xs text-slack-text-muted">
            {format_mobile_time(@message.inserted_at)}
          </span>
        </div>
        
        <div class="text-slack-text-primary text-sm leading-relaxed">
          {@message.content}
        </div>
        
        <%= if @message.reactions && length(@message.reactions) > 0 do %>
          <div class="flex flex-wrap gap-1 mt-2">
            <%= for reaction <- @message.reactions do %>
              <button class="reaction-button inline-flex items-center space-x-1 px-2 py-1 rounded-full text-xs">
                <span>{reaction.emoji}</span>
                <span class="font-medium">{reaction.count}</span>
              </button>
            <% end %>
          </div>
        <% end %>
        
        <%= if @message.thread_replies && @message.thread_replies > 0 && @show_actions do %>
          <button 
            class="mt-2 text-xs text-slack-blue"
            phx-click="mobile_navigate"
            phx-value-target="thread"
            phx-value-id={@message.id}
          >
            {if @message.thread_replies == 1, do: "1 reply", else: "#{@message.thread_replies} replies"}
          </button>
        <% end %>
      </div>
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:mobile_view, fn -> "channels" end)
     |> assign_new(:show_back_button, fn -> false end)}
  end
  
  # Helper functions
  defp format_mobile_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)
    
    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m"
      diff < 86400 -> "#{div(diff, 3600)}h"
      diff < 604800 -> Calendar.strftime(datetime, "%a")
      true -> Calendar.strftime(datetime, "%m/%d")
    end
  end
end