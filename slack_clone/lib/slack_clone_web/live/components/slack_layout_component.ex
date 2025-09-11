defmodule SlackCloneWeb.SlackLayoutComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <!-- Main Slack Layout Container -->
    <div 
      class="h-screen w-screen overflow-hidden bg-slack-bg-primary font-slack"
      phx-hook="KeyboardShortcuts"
      id="slack-layout"
    >
      <!-- Desktop Layout -->
      <div class="hidden md:flex h-full">
        <!-- Workspace Switcher (Far Left) -->
        <%= if @show_workspace_switcher do %>
          <.live_component 
            module={SlackCloneWeb.WorkspaceSwitcherComponent}
            id="workspace-switcher"
            workspace={@current_workspace}
            workspaces={@workspaces}
            current_user={@current_user}
          />
        <% end %>
        
        <!-- Channel List Sidebar -->
        <%= if @show_channel_list do %>
          <.live_component 
            module={SlackCloneWeb.ChannelListComponent}
            id="channel-list"
            workspace={@current_workspace}
            channels={@channels}
            direct_messages={@direct_messages}
            apps={@apps}
            current_user={@current_user}
            sections={@sidebar_sections}
            unread_threads={@unread_threads}
          />
        <% end %>
        
        <!-- Main Content Area -->
        <div class="flex-1 flex flex-col min-w-0">
          <%= case @main_view do %>
            <% "loading" -> %>
              <.live_component 
                module={SlackCloneWeb.LoadingSkeletonComponent}
                id="main-loading"
                type="message_list"
              />
            
            <% "channel" -> %>
              <.live_component 
                module={SlackCloneWeb.MessageAreaComponent}
                id="message-area"
                channel={@current_channel}
                channel_id={@current_channel.id}
                channel_type="channel"
                current_user={@current_user}
                streams={@streams}
                compact_mode={@compact_mode}
                typing_users={@typing_users}
              />
            
            <% "dm" -> %>
              <.live_component 
                module={SlackCloneWeb.MessageAreaComponent}
                id="message-area-dm"
                dm_user={@current_dm_user}
                channel_id={@current_dm.id}
                channel_type="dm"
                current_user={@current_user}
                streams={@streams}
                compact_mode={@compact_mode}
                typing_users={@typing_users}
              />
            
            <% "home" -> %>
              <.home_view {assigns} />
            
            <% "search" -> %>
              <%= render_search_view(assigns) %>
            
            <% "threads" -> %>
              <%= render_threads_view(assigns) %>
            
            <% _ -> %>
              <.welcome_view {assigns} />
          <% end %>
        </div>
        
        <!-- Right Sidebar -->
        <%= if @show_right_sidebar do %>
          <.live_component 
            module={SlackCloneWeb.RightSidebarComponent}
            id="right-sidebar"
            show={@show_right_sidebar}
            mode={@right_sidebar_mode}
            channel={@current_channel}
            channel_id={@current_channel && @current_channel.id}
            channel_type={if @current_channel, do: "channel", else: "dm"}
            dm_user={@current_dm_user}
            current_user={@current_user}
            thread_message={@thread_message}
            thread_replies={@thread_replies}
          />
        <% end %>
      </div>
      
      <!-- Mobile Layout -->
      <.live_component 
        module={SlackCloneWeb.MobileLayoutComponent}
        id="mobile-layout"
        mobile_view={@mobile_view}
        workspace={@current_workspace}
        workspaces={@workspaces}
        channels={@channels}
        direct_messages={@direct_messages}
        current_user={@current_user}
        current_channel={@current_channel}
        current_dm_user={@current_dm_user}
        streams={@streams}
        recent_conversations={@recent_conversations}
        unread_threads={@unread_threads}
        unread_mentions={@unread_mentions}
        thread_message={@thread_message}
        thread_replies={@thread_replies}
        typing_users={@typing_users}
      />
      
      <!-- Global Modals and Overlays -->
      <%= if @show_search_modal do %>
        <.search_modal {assigns} />
      <% end %>
      
      <%= if @show_quick_switcher do %>
        <.quick_switcher_modal {assigns} />
      <% end %>
      
      <%= if @show_shortcuts_modal do %>
        <.keyboard_shortcuts_modal {assigns} />
      <% end %>
      
      <%= if @show_emoji_picker_global do %>
        <%= render_global_emoji_picker(assigns) %>
      <% end %>
      
      <!-- Notifications Toast -->
      <%= if @notifications && length(@notifications) > 0 do %>
        <div class="fixed top-4 right-4 space-y-2 z-50">
          <%= for notification <- @notifications do %>
            <div class={[
              "max-w-sm bg-white border border-slack-border rounded-lg shadow-slack-lg p-4 slack-slide-right",
              case notification.type do
                "success" -> "border-l-4 border-l-slack-green"
                "error" -> "border-l-4 border-l-slack-red"
                "warning" -> "border-l-4 border-l-slack-yellow"
                _ -> ""
              end
            ]}>
              <div class="flex items-start space-x-3">
                <div class="flex-1">
                  <h4 class="text-sm font-medium text-slack-text-primary">
                    {notification.title}
                  </h4>
                  <%= if notification.message do %>
                    <p class="text-sm text-slack-text-secondary mt-1">
                      {notification.message}
                    </p>
                  <% end %>
                </div>
                <button 
                  phx-click="dismiss_notification"
                  phx-value-id={notification.id}
                  class="text-slack-text-muted hover:text-slack-text-primary"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
      
      <!-- Connection Status -->
      <%= if @connection_status != "connected" do %>
        <div class="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-50">
          <div class={[
            "px-4 py-2 rounded-full text-sm font-medium shadow-slack",
            case @connection_status do
              "connecting" -> "bg-slack-yellow text-slack-text-primary"
              "disconnected" -> "bg-slack-red text-white"
              _ -> "bg-slack-bg-tertiary text-slack-text-muted"
            end
          ]}>
            <%= case @connection_status do %>
              <% "connecting" -> %>
                <div class="flex items-center space-x-2">
                  <div class="animate-spin w-4 h-4 border-2 border-slack-text-primary border-t-transparent rounded-full"></div>
                  <span>Connecting...</span>
                </div>
              <% "disconnected" -> %>
                <div class="flex items-center space-x-2">
                  <.icon name="hero-wifi" class="w-4 h-4" />
                  <span>Disconnected</span>
                </div>
              <% _ -> %>
                <span>Unknown connection status</span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Helper functions for missing views
  defp render_search_view(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto p-6">
      <h2 class="text-xl font-bold text-slack-text-primary mb-4">Search Results</h2>
      <p class="text-slack-text-secondary">Search functionality coming soon...</p>
    </div>
    """
  end

  defp render_threads_view(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto p-6">
      <h2 class="text-xl font-bold text-slack-text-primary mb-4">All Threads</h2>
      <p class="text-slack-text-secondary">Your threaded conversations will appear here...</p>
    </div>
    """
  end

  defp render_global_emoji_picker(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
      <div class="bg-white rounded-lg shadow-xl p-4">
        <h3 class="text-lg font-semibold mb-2">Emoji Picker</h3>
        <p class="text-sm text-slack-text-secondary">Select an emoji...</p>
      </div>
    </div>
    """
  end

  # Home View
  defp home_view(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto">
      <!-- Header -->
      <div class="p-6 border-b border-slack-border">
        <h1 class="text-2xl font-bold text-slack-text-primary">Good morning, {@current_user.display_name || @current_user.name}! 👋</h1>
        <p class="text-slack-text-secondary mt-1">Here's what's happening at {@current_workspace.name}</p>
      </div>
      
      <!-- Quick Stats -->
      <div class="p-6 grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-white border border-slack-border rounded-lg p-4">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-slack-blue rounded-lg flex items-center justify-center">
              <.icon name="hero-chat-bubble-left" class="w-5 h-5 text-white" />
            </div>
            <div>
              <p class="text-2xl font-bold text-slack-text-primary">{@unread_messages || 0}</p>
              <p class="text-sm text-slack-text-muted">Unread messages</p>
            </div>
          </div>
        </div>
        
        <div class="bg-white border border-slack-border rounded-lg p-4">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-slack-green rounded-lg flex items-center justify-center">
              <.icon name="hero-at-symbol" class="w-5 h-5 text-white" />
            </div>
            <div>
              <p class="text-2xl font-bold text-slack-text-primary">{@unread_mentions || 0}</p>
              <p class="text-sm text-slack-text-muted">Mentions</p>
            </div>
          </div>
        </div>
        
        <div class="bg-white border border-slack-border rounded-lg p-4">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-slack-purple rounded-lg flex items-center justify-center">
              <.icon name="hero-chat-bubble-left-right" class="w-5 h-5 text-white" />
            </div>
            <div>
              <p class="text-2xl font-bold text-slack-text-primary">{@unread_threads || 0}</p>
              <p class="text-sm text-slack-text-muted">Thread replies</p>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Recent Activity -->
      <div class="p-6">
        <h2 class="text-lg font-bold text-slack-text-primary mb-4">Recent activity</h2>
        
        <%= if @recent_activity && length(@recent_activity) > 0 do %>
          <div class="space-y-4">
            <%= for activity <- @recent_activity do %>
              <div class="flex items-start space-x-3 p-4 bg-white border border-slack-border rounded-lg hover:bg-slack-bg-secondary cursor-pointer">
                <img 
                  src={activity.user.avatar_url || "/images/default-avatar.png"}
                  alt={activity.user.name}
                  class="w-8 h-8 rounded object-cover"
                />
                <div class="flex-1 min-w-0">
                  <p class="text-sm text-slack-text-primary">
                    <span class="font-medium">{activity.user.display_name || activity.user.name}</span>
                    {activity.action_text}
                    <span class="font-medium">#{activity.channel_name}</span>
                  </p>
                  <p class="text-xs text-slack-text-muted mt-1">
                    {format_timestamp(activity.timestamp)}
                  </p>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-8">
            <div class="w-16 h-16 bg-slack-bg-tertiary rounded-lg flex items-center justify-center mx-auto mb-3">
              <.icon name="hero-clock" class="w-8 h-8 text-slack-text-muted" />
            </div>
            <p class="text-slack-text-muted">No recent activity</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Welcome View
  defp welcome_view(assigns) do
    ~H"""
    <div class="flex-1 flex items-center justify-center">
      <div class="text-center max-w-md">
        <div class="w-20 h-20 bg-slack-purple rounded-2xl flex items-center justify-center mx-auto mb-6">
          <span class="text-3xl font-bold text-white">{@current_workspace.initial || "W"}</span>
        </div>
        
        <h1 class="text-2xl font-bold text-slack-text-primary mb-2">
          Welcome to {@current_workspace.name}!
        </h1>
        
        <p class="text-slack-text-secondary mb-6">
          Get started by selecting a channel from the sidebar, or create a new one.
        </p>
        
        <div class="space-y-3">
          <button 
            phx-click="create_channel"
            class="w-full px-4 py-3 bg-slack-green text-white rounded-lg hover:bg-green-600 transition-colors font-medium"
          >
            Create your first channel
          </button>
          
          <button 
            phx-click="invite_people"
            class="w-full px-4 py-3 border border-slack-border text-slack-text-primary rounded-lg hover:bg-slack-bg-secondary transition-colors font-medium"
          >
            Invite people to join
          </button>
        </div>
        
        <div class="mt-6 pt-6 border-t border-slack-border">
          <p class="text-xs text-slack-text-muted mb-2">Quick tip:</p>
          <p class="text-sm text-slack-text-secondary">
            Press <kbd class="px-1.5 py-0.5 bg-slack-bg-tertiary rounded text-xs">⌘K</kbd> to quickly search and navigate
          </p>
        </div>
      </div>
    </div>
    """
  end
  
  # Search Modal
  defp search_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center pt-20 z-50" phx-click="close_search">
      <div class="bg-white rounded-lg shadow-slack-lg w-full max-w-2xl mx-4" phx-click={JS.stop_propagation()}>
        <!-- Search Header -->
        <div class="p-4 border-b border-slack-border">
          <div class="relative">
            <input 
              type="text" 
              placeholder="Search messages, files, and more..."
              class="w-full pl-4 pr-10 py-3 border border-slack-border rounded-lg focus:outline-none focus:border-slack-blue focus:ring-1 focus:ring-slack-blue"
              phx-keyup="search_query"
              phx-key="Escape"
              phx-click="close_search"
              autofocus
            />
            <.icon name="hero-magnifying-glass" class="absolute right-3 top-3 w-5 h-5 text-slack-text-muted" />
          </div>
        </div>
        
        <!-- Search Results -->
        <div class="max-h-96 overflow-y-auto">
          <%= if @search_results && length(@search_results) > 0 do %>
            <div class="p-2">
              <%= for result <- @search_results do %>
                <button class="w-full text-left p-3 hover:bg-slack-bg-secondary rounded transition-colors">
                  <div class="flex items-start space-x-3">
                    <img 
                      src={result.user.avatar_url || "/images/default-avatar.png"}
                      alt={result.user.name}
                      class="w-6 h-6 rounded object-cover flex-shrink-0"
                    />
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center space-x-2 text-sm">
                        <span class="font-medium">{result.user.display_name || result.user.name}</span>
                        <span class="text-slack-text-muted">in #{result.channel_name}</span>
                        <span class="text-slack-text-muted">{format_timestamp(result.timestamp)}</span>
                      </div>
                      <p class="text-sm text-slack-text-primary mt-1 line-clamp-2">
                        {result.content}
                      </p>
                    </div>
                  </div>
                </button>
              <% end %>
            </div>
          <% else %>
            <div class="p-8 text-center text-slack-text-muted">
              <%= if @search_query && String.trim(@search_query) != "" do %>
                <p>No results found for "{@search_query}"</p>
              <% else %>
                <p>Start typing to search messages, files, and channels</p>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  # Quick Switcher Modal  
  defp quick_switcher_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center pt-20 z-50" phx-click="close_quick_switcher">
      <div class="bg-white rounded-lg shadow-slack-lg w-full max-w-lg mx-4" phx-click={JS.stop_propagation()}>
        <!-- Quick Switcher Header -->
        <div class="p-4 border-b border-slack-border">
          <input 
            type="text" 
            placeholder="Jump to a channel or person..."
            class="w-full px-3 py-2 border border-slack-border rounded-lg focus:outline-none focus:border-slack-blue focus:ring-1 focus:ring-slack-blue"
            phx-keyup="quick_switch_query"
            phx-key="Escape"
            phx-click="close_quick_switcher"
            autofocus
          />
        </div>
        
        <!-- Quick Switch Results -->
        <div class="max-h-80 overflow-y-auto">
          <div class="p-2">
            <%= for item <- @quick_switch_results || [] do %>
              <button 
                class="w-full text-left p-3 hover:bg-slack-bg-secondary rounded transition-colors flex items-center space-x-3"
                phx-click="quick_switch_to"
                phx-value-type={item.type}
                phx-value-id={item.id}
              >
                <%= case item.type do %>
                  <% "channel" -> %>
                    <%= if item.is_private do %>
                      <.icon name="hero-lock-closed" class="w-5 h-5 text-slack-text-muted flex-shrink-0" />
                    <% else %>
                      <span class="text-slack-text-muted flex-shrink-0">#</span>
                    <% end %>
                  <% "dm" -> %>
                    <img 
                      src={item.user.avatar_url || "/images/default-avatar.png"}
                      alt={item.user.name}
                      class="w-5 h-5 rounded object-cover flex-shrink-0"
                    />
                <% end %>
                
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-slack-text-primary truncate">
                    <%= if item.type == "channel" do %>
                      {item.name}
                    <% else %>
                      {item.user.display_name || item.user.name}
                    <% end %>
                  </p>
                  <%= if item.description do %>
                    <p class="text-sm text-slack-text-muted truncate">{item.description}</p>
                  <% end %>
                </div>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  # Keyboard Shortcuts Modal
  defp keyboard_shortcuts_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" phx-click="close_shortcuts">
      <div class="bg-white rounded-lg shadow-slack-lg w-full max-w-3xl mx-4 max-h-[80vh] overflow-y-auto" phx-click={JS.stop_propagation()}>
        <!-- Header -->
        <div class="p-6 border-b border-slack-border">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-bold text-slack-text-primary">Keyboard shortcuts</h2>
            <button phx-click="close_shortcuts" class="text-slack-text-muted hover:text-slack-text-primary">
              <.icon name="hero-x-mark" class="w-6 h-6" />
            </button>
          </div>
        </div>
        
        <!-- Shortcuts List -->
        <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-8">
          <div>
            <h3 class="font-medium text-slack-text-primary mb-4">Navigation</h3>
            <div class="space-y-3">
              <.shortcut_item shortcut="⌘K" description="Quick switcher" />
              <.shortcut_item shortcut="⌘⇧K" description="Browse channels" />
              <.shortcut_item shortcut="⌘[" description="Back" />
              <.shortcut_item shortcut="⌘]" description="Forward" />
              <.shortcut_item shortcut="⌥↑" description="Previous channel" />
              <.shortcut_item shortcut="⌥↓" description="Next channel" />
              <.shortcut_item shortcut="F6" description="Focus message input" />
            </div>
          </div>
          
          <div>
            <h3 class="font-medium text-slack-text-primary mb-4">Messages</h3>
            <div class="space-y-3">
              <.shortcut_item shortcut="⌘⏎" description="Send message" />
              <.shortcut_item shortcut="⇧⏎" description="New line" />
              <.shortcut_item shortcut="T" description="Reply in thread" />
              <.shortcut_item shortcut="R" description="Reply to message" />
              <.shortcut_item shortcut="E" description="Edit last message" />
              <.shortcut_item shortcut="A" description="Add reaction" />
              <.shortcut_item shortcut="⌘Z" description="Undo" />
            </div>
          </div>
          
          <div>
            <h3 class="font-medium text-slack-text-primary mb-4">Formatting</h3>
            <div class="space-y-3">
              <.shortcut_item shortcut="⌘B" description="Bold text" />
              <.shortcut_item shortcut="⌘I" description="Italic text" />
              <.shortcut_item shortcut="⌘⇧X" description="Strike through" />
              <.shortcut_item shortcut="⌘⇧C" description="Code snippet" />
              <.shortcut_item shortcut="⌘⇧>" description="Quote" />
            </div>
          </div>
          
          <div>
            <h3 class="font-medium text-slack-text-primary mb-4">Other</h3>
            <div class="space-y-3">
              <.shortcut_item shortcut="⌘⇧D" description="Toggle dark mode" />
              <.shortcut_item shortcut="⌘⇧M" description="Mentions & reactions" />
              <.shortcut_item shortcut="⌘⇧A" description="All unreads" />
              <.shortcut_item shortcut="⇧⎋" description="Mark all as read" />
              <.shortcut_item shortcut="⌘/" description="Show shortcuts" />
              <.shortcut_item shortcut="⎋" description="Close/cancel" />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  defp shortcut_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <span class="text-sm text-slack-text-secondary">{@description}</span>
      <kbd class="px-2 py-1 bg-slack-bg-tertiary rounded text-xs font-mono">{@shortcut}</kbd>
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show_workspace_switcher, fn -> true end)
     |> assign_new(:show_channel_list, fn -> true end)
     |> assign_new(:show_right_sidebar, fn -> false end)
     |> assign_new(:right_sidebar_mode, fn -> "details" end)
     |> assign_new(:main_view, fn -> "welcome" end)
     |> assign_new(:mobile_view, fn -> "channels" end)
     |> assign_new(:compact_mode, fn -> false end)
     |> assign_new(:connection_status, fn -> "connected" end)
     |> assign_new(:notifications, fn -> [] end)
     |> assign_new(:typing_users, fn -> [] end)
     |> assign_new(:show_search_modal, fn -> false end)
     |> assign_new(:show_quick_switcher, fn -> false end)
     |> assign_new(:show_shortcuts_modal, fn -> false end)
     |> assign_new(:show_emoji_picker_global, fn -> false end)}
  end
  
  # Helper functions
  defp format_timestamp(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)
    
    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> Calendar.strftime(datetime, "%a at %I:%M %p")
      true -> Calendar.strftime(datetime, "%b %d at %I:%M %p")
    end
  end
end