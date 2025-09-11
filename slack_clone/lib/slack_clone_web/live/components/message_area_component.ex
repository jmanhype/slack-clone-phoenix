defmodule SlackCloneWeb.MessageAreaComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col bg-slack-bg-primary h-full">
      <!-- Header -->
      <div class="flex items-center justify-between px-4 py-3 border-b border-slack-border bg-white">
        <!-- Channel/DM Info -->
        <div class="flex items-center space-x-2 min-w-0">
          <!-- Channel/DM Icon and Name -->
          <div class="flex items-center space-x-2">
            <%= if @channel_type == "channel" do %>
              <%= if @channel.is_private do %>
                <.icon name="hero-lock-closed" class="w-5 h-5 text-slack-text-secondary flex-shrink-0" />
              <% else %>
                <span class="text-xl font-bold text-slack-text-secondary">#</span>
              <% end %>
              <h1 class="text-lg font-bold text-slack-text-primary truncate">{@channel.name}</h1>
            <% else %>
              <!-- DM Header -->
              <div class="relative flex-shrink-0">
                <img 
                  src={@dm_user.avatar_url || "/images/default-avatar.png"} 
                  alt={@dm_user.name}
                  class="w-6 h-6 rounded object-cover"
                />
                <!-- Presence indicator -->
                <div class={[
                  "absolute -bottom-0.5 -right-0.5 w-3 h-3 border-2 border-white rounded-full",
                  case @dm_user.presence do
                    "active" -> "presence-active"
                    "away" -> "presence-away"
                    _ -> "presence-offline"
                  end
                ]}></div>
              </div>
              <h1 class="text-lg font-bold text-slack-text-primary truncate">{@dm_user.display_name || @dm_user.name}</h1>
              <%= if @dm_user.presence == "active" do %>
                <span class="text-sm text-slack-green">Active</span>
              <% else %>
                <span class="text-sm text-slack-text-muted">Away</span>
              <% end %>
            <% end %>
          </div>
          
          <!-- Channel description or member count -->
          <%= if @channel_type == "channel" and @channel.description do %>
            <span class="text-sm text-slack-text-muted truncate">| {@channel.description}</span>
          <% end %>
        </div>
        
        <!-- Header Actions -->
        <div class="flex items-center space-x-3">
          <!-- Member count (for channels) -->
          <%= if @channel_type == "channel" do %>
            <div class="flex items-center space-x-1 text-slack-text-muted hover:text-slack-text-primary cursor-pointer">
              <.icon name="hero-user-group" class="w-4 h-4" />
              <span class="text-sm">{@channel.member_count}</span>
            </div>
          <% end %>
          
          <!-- Search in channel -->
          <button class="p-2 hover:bg-gray-100 rounded transition-colors" title="Search in channel">
            <.icon name="hero-magnifying-glass" class="w-5 h-5 text-slack-text-muted" />
          </button>
          
          <!-- Channel info -->
          <button class="p-2 hover:bg-gray-100 rounded transition-colors" title="Show channel details" phx-click="toggle_sidebar">
            <.icon name="hero-information-circle" class="w-5 h-5 text-slack-text-muted" />
          </button>
          
          <!-- More actions -->
          <div class="relative" x-data="{ open: false }">
            <button 
              @click="open = !open"
              class="p-2 hover:bg-gray-100 rounded transition-colors" 
              title="More actions"
            >
              <.icon name="hero-ellipsis-vertical" class="w-5 h-5 text-slack-text-muted" />
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
              class="absolute right-0 mt-2 w-56 bg-white border border-slack-border rounded-lg shadow-slack-lg z-50"
            >
              <div class="py-1">
                <button class="w-full text-left px-4 py-2 text-sm text-slack-text-primary hover:bg-gray-50 flex items-center">
                  <.icon name="hero-bell" class="w-4 h-4 mr-3" />
                  Mute notifications
                </button>
                <button class="w-full text-left px-4 py-2 text-sm text-slack-text-primary hover:bg-gray-50 flex items-center">
                  <.icon name="hero-star" class="w-4 h-4 mr-3" />
                  Add to favorites
                </button>
                <div class="border-t border-slack-border my-1"></div>
                <button class="w-full text-left px-4 py-2 text-sm text-slack-red hover:bg-gray-50 flex items-center">
                  <.icon name="hero-trash" class="w-4 h-4 mr-3" />
                  Leave channel
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Messages Container -->
      <div class="flex-1 overflow-y-auto slack-scrollbar" id="messages-container">
        <!-- Channel/DM intro -->
        <%= if @show_intro do %>
          <div class="p-6 max-w-2xl">
            <%= if @channel_type == "channel" do %>
              <div class="flex items-start space-x-3 mb-4">
                <div class="w-16 h-16 bg-slack-light-purple rounded-lg flex items-center justify-center">
                  <%= if @channel.is_private do %>
                    <.icon name="hero-lock-closed" class="w-8 h-8 text-slack-purple" />
                  <% else %>
                    <span class="text-2xl font-bold text-slack-purple">#</span>
                  <% end %>
                </div>
                <div>
                  <h2 class="text-xl font-bold text-slack-text-primary mb-1">Welcome to #{@channel.name}!</h2>
                  <%= if @channel.description do %>
                    <p class="text-slack-text-secondary mb-2">{@channel.description}</p>
                  <% end %>
                  <p class="text-sm text-slack-text-muted">
                    This channel was created on {Calendar.strftime(@channel.created_at, "%B %d, %Y")}.
                  </p>
                </div>
              </div>
              
              <!-- Quick actions -->
              <div class="flex space-x-2 text-sm">
                <button class="px-3 py-1 bg-slack-bg-tertiary rounded hover:bg-gray-200 transition-colors">
                  View channel details
                </button>
                <button class="px-3 py-1 bg-slack-bg-tertiary rounded hover:bg-gray-200 transition-colors">
                  Add description
                </button>
                <button class="px-3 py-1 bg-slack-bg-tertiary rounded hover:bg-gray-200 transition-colors">
                  Add people
                </button>
              </div>
            <% else %>
              <!-- DM intro -->
              <div class="flex items-start space-x-3 mb-4">
                <img 
                  src={@dm_user.avatar_url || "/images/default-avatar.png"} 
                  alt={@dm_user.name}
                  class="w-16 h-16 rounded-lg object-cover"
                />
                <div>
                  <h2 class="text-xl font-bold text-slack-text-primary mb-1">{@dm_user.display_name || @dm_user.name}</h2>
                  <%= if @dm_user.title do %>
                    <p class="text-slack-text-secondary mb-1">{@dm_user.title}</p>
                  <% end %>
                  <p class="text-sm text-slack-text-muted">
                    This is the start of your conversation with {@dm_user.display_name || @dm_user.name}.
                  </p>
                </div>
              </div>
            <% end %>
          </div>
          
          <div class="border-t border-slack-border"></div>
        <% end %>
        
        <!-- Messages List -->
        <div class="px-4" id="messages-list" phx-update="stream" phx-hook="ScrollToBottom">
          <%= for {message_id, message} <- @streams.messages do %>
            <.live_component 
              module={SlackCloneWeb.MessageComponent} 
              id={message_id}
              message={message}
              current_user={@current_user}
              show_avatar={message.show_avatar}
              compact={@compact_mode}
            />
          <% end %>
        </div>
        
        <!-- Typing indicators -->
        <%= if length(@typing_users) > 0 do %>
          <div class="px-4 py-2">
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
                  <% length(@typing_users) == 2 -> %>
                    {Enum.at(@typing_users, 0).name} and {Enum.at(@typing_users, 1).name} are typing...
                  <% length(@typing_users) > 2 -> %>
                    Several people are typing...
                <% end %>
              </span>
            </div>
          </div>
        <% end %>
      </div>
      
      <!-- Message Input -->
      <.live_component 
        module={SlackCloneWeb.MessageInputComponent} 
        id="message-input"
        channel_id={@channel_id}
        placeholder={if @channel_type == "channel", do: "Message ##{@channel.name}", else: "Message #{@dm_user.display_name || @dm_user.name}"}
      />
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show_intro, fn -> true end)
     |> assign_new(:compact_mode, fn -> false end)
     |> assign_new(:typing_users, fn -> [] end)}
  end
end