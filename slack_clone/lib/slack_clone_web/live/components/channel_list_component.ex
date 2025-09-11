defmodule SlackCloneWeb.ChannelListComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-slack-channels bg-slack-bg-channel text-slack-text-on-dark flex flex-col h-full mobile-hidden">
      <!-- Workspace Header -->
      <div class="p-4 border-b border-slack-border-dark">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-2 cursor-pointer hover:bg-slack-bg-hover rounded px-2 py-1 -mx-2 -my-1 transition-colors">
            <h2 class="text-lg font-bold text-white truncate">{@workspace.name}</h2>
            <.icon name="hero-chevron-down" class="w-4 h-4 text-slack-text-on-dark-muted flex-shrink-0" />
          </div>
          
          <div class="flex items-center space-x-2">
            <!-- New message button -->
            <button class="w-8 h-8 bg-white text-slack-purple rounded-lg flex items-center justify-center hover:bg-gray-100 transition-colors" title="New message">
              <.icon name="hero-pencil-square" class="w-4 h-4" />
            </button>
          </div>
        </div>
        
        <!-- User info -->
        <div class="flex items-center mt-2 space-x-2">
          <div class="w-3 h-3 bg-slack-green rounded-full"></div>
          <span class="text-sm text-slack-text-on-dark-muted">{@current_user.name}</span>
        </div>
      </div>
      
      <!-- Search -->
      <div class="p-4 border-b border-slack-border-dark">
        <div class="relative">
          <input 
            type="text" 
            placeholder="Search..."
            class="w-full bg-slack-bg-sidebar border border-slack-border-dark rounded px-3 py-2 text-sm text-white placeholder-slack-text-on-dark-muted focus:outline-none focus:border-slack-blue slack-focus"
            phx-keydown="search"
            phx-key="Enter"
          />
          <.icon name="hero-magnifying-glass" class="absolute right-3 top-2.5 w-4 h-4 text-slack-text-on-dark-muted" />
        </div>
      </div>
      
      <!-- Channel List -->
      <div class="flex-1 overflow-y-auto slack-scrollbar">
        <!-- Threads -->
        <div class="p-2">
          <div class="channel-item flex items-center px-3 py-1 rounded hover:bg-slack-bg-hover cursor-pointer">
            <.icon name="hero-chat-bubble-left-right" class="w-4 h-4 mr-3 text-slack-text-on-dark-muted" />
            <span class="text-sm text-slack-text-on-dark-muted">Threads</span>
            <%= if @unread_threads > 0 do %>
              <span class="ml-auto text-xs bg-slack-red text-white rounded-full px-2 py-0.5 min-w-[20px] text-center">{@unread_threads}</span>
            <% end %>
          </div>
        </div>
        
        <!-- Channels Section -->
        <div class="px-2 pb-2">
          <div 
            class="flex items-center px-3 py-1 rounded hover:bg-slack-bg-hover cursor-pointer"
            phx-click="toggle_section"
            phx-value-section="channels"
          >
            <.icon 
              name={if @sections.channels.expanded, do: "hero-chevron-down", else: "hero-chevron-right"} 
              class="w-3 h-3 mr-2 text-slack-text-on-dark-muted"
            />
            <span class="text-sm text-slack-text-on-dark-muted font-medium">Channels</span>
            
            <!-- Add channel button -->
            <button class="ml-auto opacity-0 group-hover:opacity-100 hover:bg-slack-bg-active rounded p-1 transition-all" title="Add channel">
              <.icon name="hero-plus" class="w-3 h-3 text-slack-text-on-dark-muted" />
            </button>
          </div>
          
          <%= if @sections.channels.expanded do %>
            <div class="ml-2 space-y-1">
              <%= for channel <- @channels do %>
                <div 
                  class={[
                    "channel-item flex items-center px-3 py-1 rounded cursor-pointer group",
                    if(channel.active, do: "active bg-slack-blue text-white", else: "hover:bg-slack-bg-hover text-slack-text-on-dark-muted")
                  ]}
                  phx-click="select_channel"
                  phx-value-id={channel.id}
                >
                  <!-- Channel icon -->
                  <div class="mr-2 flex-shrink-0">
                    <%= if channel.is_private do %>
                      <.icon name="hero-lock-closed" class="w-4 h-4" />
                    <% else %>
                      <span class="text-slack-text-on-dark-muted">#</span>
                    <% end %>
                  </div>
                  
                  <span class="text-sm truncate flex-1">{channel.name}</span>
                  
                  <!-- Unread badge -->
                  <%= if channel.unread_count > 0 do %>
                    <span class="ml-2 text-xs bg-slack-red text-white rounded-full px-2 py-0.5 min-w-[20px] text-center flex-shrink-0">
                      {channel.unread_count}
                    </span>
                  <% end %>
                  
                  <!-- Mention badge -->
                  <%= if channel.mention_count > 0 do %>
                    <span class="ml-1 w-2 h-2 bg-slack-red rounded-full flex-shrink-0"></span>
                  <% end %>
                </div>
              <% end %>
              
              <!-- Add channels item -->
              <div class="channel-item flex items-center px-3 py-1 rounded hover:bg-slack-bg-hover cursor-pointer text-slack-text-on-dark-muted">
                <.icon name="hero-plus" class="w-4 h-4 mr-2" />
                <span class="text-sm">Add channels</span>
              </div>
            </div>
          <% end %>
        </div>
        
        <!-- Direct Messages Section -->
        <div class="px-2 pb-2">
          <div 
            class="flex items-center px-3 py-1 rounded hover:bg-slack-bg-hover cursor-pointer"
            phx-click="toggle_section"
            phx-value-section="direct_messages"
          >
            <.icon 
              name={if @sections.direct_messages.expanded, do: "hero-chevron-down", else: "hero-chevron-right"} 
              class="w-3 h-3 mr-2 text-slack-text-on-dark-muted"
            />
            <span class="text-sm text-slack-text-on-dark-muted font-medium">Direct messages</span>
            
            <!-- New DM button -->
            <button class="ml-auto opacity-0 group-hover:opacity-100 hover:bg-slack-bg-active rounded p-1 transition-all" title="New message">
              <.icon name="hero-plus" class="w-3 h-3 text-slack-text-on-dark-muted" />
            </button>
          </div>
          
          <%= if @sections.direct_messages.expanded do %>
            <div class="ml-2 space-y-1">
              <%= for dm <- @direct_messages do %>
                <div 
                  class={[
                    "channel-item flex items-center px-3 py-1 rounded cursor-pointer group",
                    if(dm.active, do: "active bg-slack-blue text-white", else: "hover:bg-slack-bg-hover text-slack-text-on-dark-muted")
                  ]}
                  phx-click="select_dm"
                  phx-value-id={dm.id}
                >
                  <!-- User avatar -->
                  <div class="relative mr-2 flex-shrink-0">
                    <img 
                      src={dm.user.avatar_url || "/images/default-avatar.png"}
                      alt={dm.user.name}
                      class="w-5 h-5 rounded object-cover"
                    />
                    <!-- Presence indicator -->
                    <div class={[
                      "absolute -bottom-0.5 -right-0.5 w-3 h-3 border-2 border-slack-bg-channel rounded-full",
                      case dm.user.presence do
                        "active" -> "presence-active"
                        "away" -> "presence-away"
                        _ -> "presence-offline"
                      end
                    ]}></div>
                  </div>
                  
                  <span class="text-sm truncate flex-1">{dm.user.display_name || dm.user.name}</span>
                  
                  <!-- Unread indicator -->
                  <%= if dm.unread do %>
                    <div class="w-2 h-2 bg-slack-red rounded-full flex-shrink-0"></div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
        <!-- Apps Section -->
        <div class="px-2 pb-2">
          <div 
            class="flex items-center px-3 py-1 rounded hover:bg-slack-bg-hover cursor-pointer"
            phx-click="toggle_section"
            phx-value-section="apps"
          >
            <.icon 
              name={if @sections.apps.expanded, do: "hero-chevron-down", else: "hero-chevron-right"} 
              class="w-3 h-3 mr-2 text-slack-text-on-dark-muted"
            />
            <span class="text-sm text-slack-text-on-dark-muted font-medium">Apps</span>
            
            <!-- Add apps button -->
            <button class="ml-auto opacity-0 group-hover:opacity-100 hover:bg-slack-bg-active rounded p-1 transition-all" title="Add apps">
              <.icon name="hero-plus" class="w-3 h-3 text-slack-text-on-dark-muted" />
            </button>
          </div>
          
          <%= if @sections.apps.expanded do %>
            <div class="ml-2 space-y-1">
              <%= for app <- @apps do %>
                <div class="channel-item flex items-center px-3 py-1 rounded hover:bg-slack-bg-hover cursor-pointer text-slack-text-on-dark-muted">
                  <img 
                    src={app.icon_url}
                    alt={app.name}
                    class="w-4 h-4 mr-2 rounded flex-shrink-0"
                  />
                  <span class="text-sm truncate flex-1">{app.name}</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:sections, fn -> 
       %{
         channels: %{expanded: true},
         direct_messages: %{expanded: true},
         apps: %{expanded: false}
       }
     end)}
  end
end