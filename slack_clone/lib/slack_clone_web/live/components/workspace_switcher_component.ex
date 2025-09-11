defmodule SlackCloneWeb.WorkspaceSwitcherComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-16 bg-slack-bg-sidebar flex flex-col items-center py-3 space-y-2 mobile-hidden">
      <!-- Current Workspace -->
      <div class="relative group">
        <div class="w-10 h-10 bg-white rounded-lg flex items-center justify-center text-slack-purple font-bold text-lg hover:rounded-xl transition-all duration-200 cursor-pointer shadow-lg">
          {@workspace.initial || "W"}
        </div>
        <!-- Active indicator -->
        <div class="absolute left-0 top-2 w-1 h-6 bg-white rounded-r-md opacity-100"></div>
        
        <!-- Tooltip -->
        <div class="absolute left-16 top-1/2 -translate-y-1/2 bg-black text-white px-2 py-1 text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-50">
          {@workspace.name}
        </div>
      </div>
      
      <!-- Workspace List -->
      <div class="space-y-2">
        <%= for workspace <- @workspaces do %>
          <div class="relative group">
            <div 
              class={[
                "w-10 h-10 rounded-lg flex items-center justify-center text-white font-bold text-lg cursor-pointer transition-all duration-200",
                if(workspace.active, do: "bg-white text-slack-purple shadow-lg", else: "bg-slack-text-muted hover:bg-white hover:text-slack-purple hover:rounded-xl")
              ]}
              phx-click="switch_workspace"
              phx-value-id={workspace.id}
            >
              {workspace.initial}
            </div>
            
            <!-- Active indicator -->
            <%= if workspace.active do %>
              <div class="absolute left-0 top-2 w-1 h-6 bg-white rounded-r-md"></div>
            <% end %>
            
            <!-- Tooltip -->
            <div class="absolute left-16 top-1/2 -translate-y-1/2 bg-black text-white px-2 py-1 text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-50">
              {workspace.name}
            </div>
          </div>
        <% end %>
      </div>
      
      <!-- Add Workspace Button -->
      <div class="pt-2 border-t border-slack-border-dark">
        <div class="relative group">
          <div class="w-10 h-10 bg-transparent border-2 border-slack-text-muted rounded-lg flex items-center justify-center text-slack-text-muted hover:border-white hover:text-white cursor-pointer transition-all duration-200">
            <.icon name="hero-plus" class="w-5 h-5" />
          </div>
          
          <!-- Tooltip -->
          <div class="absolute left-16 top-1/2 -translate-y-1/2 bg-black text-white px-2 py-1 text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-50">
            Add workspace
          </div>
        </div>
      </div>
      
      <!-- User Menu -->
      <div class="mt-auto relative group">
        <div class="w-10 h-10 rounded-lg overflow-hidden cursor-pointer hover:rounded-xl transition-all duration-200">
          <img 
            src={@current_user.avatar_url || "/images/default-avatar.png"} 
            alt={@current_user.name}
            class="w-full h-full object-cover"
          />
          
          <!-- Presence indicator -->
          <div class="absolute bottom-0 right-0 w-3 h-3 bg-slack-green border-2 border-slack-bg-sidebar rounded-full"></div>
        </div>
        
        <!-- Tooltip -->
        <div class="absolute left-16 top-1/2 -translate-y-1/2 bg-black text-white px-2 py-1 text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-50">
          {@current_user.name}
        </div>
      </div>
    </div>
    """
  end
  
  @impl true
  def update(%{workspace: workspace, workspaces: workspaces, current_user: current_user} = _assigns, socket) do
    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:workspaces, workspaces)
     |> assign(:current_user, current_user)}
  end
end