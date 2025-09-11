defmodule SlackCloneWeb.MessageInputComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="border-t border-slack-border bg-white">
      <!-- Formatting Toolbar (shown when focused) -->
      <div class={[
        "px-4 py-2 border-b border-slack-border transition-all duration-200",
        if(@show_toolbar, do: "opacity-100 max-h-12", else: "opacity-0 max-h-0 overflow-hidden")
      ]}>
        <div class="flex items-center space-x-1">
          <!-- Text formatting -->
          <button class="p-2 hover:bg-slack-bg-secondary rounded text-slack-text-muted hover:text-slack-text-primary transition-colors" title="Bold (⌘B)">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M6 4v12h4.5c2.5 0 4.5-1.8 4.5-4.2 0-1.5-.8-2.8-2-3.4.9-.6 1.5-1.7 1.5-2.9C14.5 3.1 12.4 4 10 4H6zm2.5 4.5h1.5c.8 0 1.5-.7 1.5-1.5s-.7-1.5-1.5-1.5H8.5v3zm0 6h2c1.1 0 2-.9 2-2s-.9-2-2-2h-2v4z"/>
            </svg>
          </button>
          
          <button class="p-2 hover:bg-slack-bg-secondary rounded text-slack-text-muted hover:text-slack-text-primary transition-colors" title="Italic (⌘I)">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M8.5 4h3l-.5 2h-1l-2 8h1l-.5 2h-3l.5-2h1l2-8h-1l.5-2z"/>
            </svg>
          </button>
          
          <button class="p-2 hover:bg-slack-bg-secondary rounded text-slack-text-muted hover:text-slack-text-primary transition-colors" title="Strikethrough (⌘⇧X)">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M3 9h14v2H3V9zm4-4h6v2H7V5zm0 8h6v2H7v-2z"/>
            </svg>
          </button>
          
          <div class="w-px h-6 bg-slack-border mx-2"></div>
          
          <!-- Lists -->
          <button class="p-2 hover:bg-slack-bg-secondary rounded text-slack-text-muted hover:text-slack-text-primary transition-colors" title="Bullet list">
            <.icon name="hero-list-bullet" class="w-4 h-4" />
          </button>
          
          <button class="p-2 hover:bg-slack-bg-secondary rounded text-slack-text-muted hover:text-slack-text-primary transition-colors" title="Numbered list">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M3 4h1v3H3V4zm0 6h1v3H3v-3zm0 6h1v3H3v-3zm4-12h10v2H7V4zm0 6h10v2H7v-2zm0 6h10v2H7v-2z"/>
            </svg>
          </button>
          
          <div class="w-px h-6 bg-slack-border mx-2"></div>
          
          <!-- Code and quote -->
          <button class="p-2 hover:bg-slack-bg-secondary rounded text-slack-text-muted hover:text-slack-text-primary transition-colors" title="Code block (⌘⇧C)">
            <.icon name="hero-code-bracket" class="w-4 h-4" />
          </button>
          
          <button class="p-2 hover:bg-slack-bg-secondary rounded text-slack-text-muted hover:text-slack-text-primary transition-colors" title="Quote (⌘⇧>)">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M3 6h14v2H3V6zm0 4h14v2H3v-2zm0 4h14v2H3v-2z" opacity="0.3"/>
              <path d="M3 6h1v8H3V6z"/>
            </svg>
          </button>
          
          <div class="w-px h-6 bg-slack-border mx-2"></div>
          
          <!-- Link -->
          <button class="p-2 hover:bg-slack-bg-secondary rounded text-slack-text-muted hover:text-slack-text-primary transition-colors" title="Link (⌘K)">
            <.icon name="hero-link" class="w-4 h-4" />
          </button>
        </div>
      </div>
      
      <!-- Message Input Area -->
      <div class="p-4">
        <div class="border border-slack-border rounded-lg focus-within:border-slack-blue focus-within:ring-1 focus-within:ring-slack-blue transition-all duration-200">
          <!-- Text Input -->
          <div class="p-3">
            <div 
              contenteditable="true"
              class="min-h-[20px] max-h-48 overflow-y-auto outline-none text-slack-base text-slack-text-primary placeholder:text-slack-text-muted resize-none"
              placeholder={@placeholder}
              phx-hook="MessageInput"
              phx-keydown="typing"
              phx-key="Enter"
              phx-target={@myself}
              id={"message-input-#{@id}"}
            >
            </div>
            
            <!-- Mentions/Commands Dropdown -->
            <%= if @show_suggestions do %>
              <div class="absolute bottom-full left-0 right-0 bg-white border border-slack-border rounded-t-lg shadow-slack-lg mb-1 max-h-60 overflow-y-auto z-50">
                <div class="p-2">
                  <div class="text-xs font-medium text-slack-text-muted mb-2 uppercase tracking-wide">
                    {if @suggestion_type == "mention", do: "People", else: "Commands"}
                  </div>
                  
                  <%= for suggestion <- @suggestions do %>
                    <div class="flex items-center space-x-3 p-2 hover:bg-slack-bg-secondary rounded cursor-pointer">
                      <%= case @suggestion_type do %>
                        <% "mention" -> %>
                          <img 
                            src={suggestion.avatar_url || "/images/default-avatar.png"}
                            alt={suggestion.name}
                            class="w-6 h-6 rounded object-cover"
                          />
                          <div>
                            <div class="text-sm font-medium text-slack-text-primary">
                              {suggestion.display_name || suggestion.name}
                            </div>
                            <%= if suggestion.title do %>
                              <div class="text-xs text-slack-text-muted">{suggestion.title}</div>
                            <% end %>
                          </div>
                        
                        <% "command" -> %>
                          <div class="w-6 h-6 bg-slack-purple rounded flex items-center justify-center">
                            <span class="text-white text-xs font-bold">/</span>
                          </div>
                          <div>
                            <div class="text-sm font-medium text-slack-text-primary">
                              /{suggestion.name}
                            </div>
                            <div class="text-xs text-slack-text-muted">{suggestion.description}</div>
                          </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
          
          <!-- Bottom Toolbar -->
          <div class="flex items-center justify-between px-3 pb-3">
            <!-- Left side actions -->
            <div class="flex items-center space-x-2">
              <!-- Attach file -->
              <label class="cursor-pointer p-1 hover:bg-slack-bg-secondary rounded transition-colors">
                <input type="file" class="hidden" multiple phx-target={@myself} />
                <.icon name="hero-paper-clip" class="w-5 h-5 text-slack-text-muted" />
              </label>
              
              <!-- Format button -->
              <button 
                class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
                phx-click="toggle_toolbar"
                phx-target={@myself}
                title="Formatting"
              >
                <svg class="w-5 h-5 text-slack-text-muted" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M6 4v12h4.5c2.5 0 4.5-1.8 4.5-4.2 0-1.5-.8-2.8-2-3.4.9-.6 1.5-1.7 1.5-2.9C14.5 3.1 12.4 4 10 4H6z"/>
                </svg>
              </button>
              
              <!-- Emoji picker -->
              <button 
                class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
                phx-click="toggle_emoji_picker"
                phx-target={@myself}
                title="Emoji"
              >
                <.icon name="hero-face-smile" class="w-5 h-5 text-slack-text-muted" />
              </button>
              
              <!-- Mention -->
              <button 
                class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
                phx-click="insert_mention"
                phx-target={@myself}
                title="Mention someone"
              >
                <span class="text-slack-text-muted font-bold">@</span>
              </button>
              
              <!-- Slash commands -->
              <button 
                class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
                phx-click="show_commands"
                phx-target={@myself}
                title="Slash commands"
              >
                <span class="text-slack-text-muted font-bold">/</span>
              </button>
            </div>
            
            <!-- Right side - Send controls -->
            <div class="flex items-center space-x-3">
              <!-- Schedule message -->
              <div class="relative" x-data="{ open: false }">
                <button 
                  @click="open = !open"
                  class="p-1 hover:bg-slack-bg-secondary rounded transition-colors"
                  title="Schedule message"
                >
                  <.icon name="hero-clock" class="w-5 h-5 text-slack-text-muted" />
                </button>
                
                <!-- Schedule dropdown -->
                <div 
                  x-show="open" 
                  @click.away="open = false"
                  x-transition:enter="transition ease-out duration-100"
                  x-transition:enter-start="transform opacity-0 scale-95"
                  x-transition:enter-end="transform opacity-100 scale-100"
                  class="absolute bottom-full right-0 mb-2 w-64 bg-white border border-slack-border rounded-lg shadow-slack-lg z-50"
                >
                  <div class="p-4">
                    <h3 class="text-sm font-medium text-slack-text-primary mb-3">Schedule message</h3>
                    <div class="space-y-2">
                      <button class="w-full text-left px-3 py-2 text-sm hover:bg-slack-bg-secondary rounded">
                        9:00 AM tomorrow
                      </button>
                      <button class="w-full text-left px-3 py-2 text-sm hover:bg-slack-bg-secondary rounded">
                        Monday at 9:00 AM
                      </button>
                      <button class="w-full text-left px-3 py-2 text-sm hover:bg-slack-bg-secondary rounded">
                        Custom time...
                      </button>
                    </div>
                  </div>
                </div>
              </div>
              
              <!-- Send button -->
              <button 
                class={[
                  "p-2 rounded-lg transition-all duration-200 font-medium text-sm",
                  if(String.trim(@message) != "", 
                    do: "bg-slack-green text-white hover:bg-green-600", 
                    else: "bg-slack-bg-tertiary text-slack-text-muted cursor-not-allowed"
                  )
                ]}
                phx-click="send_message"
                phx-target={@myself}
                disabled={String.trim(@message) == ""}
              >
                <.icon name="hero-paper-airplane" class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
        
        <!-- Helper text -->
        <div class="flex items-center justify-between mt-2 text-xs text-slack-text-muted">
          <div class="flex items-center space-x-4">
            <span><strong>⏎</strong> to send</span>
            <span><strong>⇧⏎</strong> for new line</span>
          </div>
          
          <div class="flex items-center space-x-2">
            <%= if @is_thread do %>
              <span>Also send to #channel</span>
              <input type="checkbox" class="rounded" />
            <% end %>
            
            <!-- Character/word count -->
            <%= if String.length(@message) > 100 do %>
              <span class={[
                if(String.length(@message) > 4000, do: "text-slack-red", else: "text-slack-text-muted")
              ]}>
                {String.length(@message)}/4000
              </span>
            <% end %>
          </div>
        </div>
      </div>
      
      <!-- Emoji Picker (shown when toggled) -->
      <%= if @show_emoji_picker do %>
        <div class="absolute bottom-full right-4 mb-2 w-80 h-96 bg-white border border-slack-border rounded-lg shadow-slack-lg z-50">
          <.live_component 
            module={SlackCloneWeb.EmojiPickerComponent} 
            id="emoji-picker"
            target={@myself}
          />
        </div>
      <% end %>
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:message, fn -> "" end)
     |> assign_new(:show_toolbar, fn -> false end)
     |> assign_new(:show_emoji_picker, fn -> false end)
     |> assign_new(:show_suggestions, fn -> false end)
     |> assign_new(:suggestions, fn -> [] end)
     |> assign_new(:suggestion_type, fn -> nil end)
     |> assign_new(:is_thread, fn -> false end)}
  end
  
  @impl true
  def handle_event("toggle_toolbar", _, socket) do
    {:noreply, assign(socket, :show_toolbar, !socket.assigns.show_toolbar)}
  end
  
  @impl true
  def handle_event("toggle_emoji_picker", _, socket) do
    {:noreply, assign(socket, :show_emoji_picker, !socket.assigns.show_emoji_picker)}
  end
  
  @impl true
  def handle_event("send_message", _, socket) do
    message = String.trim(socket.assigns.message)
    
    if message != "" do
      # Send message event to parent
      send(self(), {:send_message, message, socket.assigns.channel_id})
      {:noreply, assign(socket, :message, "")}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("typing", %{"key" => "Enter", "shiftKey" => false}, socket) do
    handle_event("send_message", %{}, socket)
  end
  
  @impl true
  def handle_event("typing", _, socket) do
    # Send typing indicator to parent
    send(self(), :typing)
    {:noreply, socket}
  end
end