defmodule SlackCloneWeb.LoadingSkeletonComponent do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <%= case @type do %>
      <% "message_list" -> %>
        <.message_list_skeleton {assigns} />
      <% "channel_list" -> %>
        <.channel_list_skeleton {assigns} />
      <% "thread" -> %>
        <.thread_skeleton {assigns} />
      <% "sidebar" -> %>
        <.sidebar_skeleton {assigns} />
      <% "search" -> %>
        <.search_skeleton {assigns} />
      <% _ -> %>
        <.default_skeleton {assigns} />
    <% end %>
    """
  end
  
  # Message List Skeleton
  defp message_list_skeleton(assigns) do
    ~H"""
    <div class="px-4 space-y-6">
      <%= for _ <- 1..(@count || 8) do %>
        <div class="flex space-x-3 animate-pulse">
          <!-- Avatar skeleton -->
          <div class="w-10 h-10 bg-slate-200 rounded skeleton"></div>
          
          <div class="flex-1 space-y-2">
            <!-- Name and timestamp -->
            <div class="flex items-center space-x-3">
              <div class="h-4 bg-slate-200 rounded skeleton w-24"></div>
              <div class="h-3 bg-slate-200 rounded skeleton w-16"></div>
            </div>
            
            <!-- Message content -->
            <div class="space-y-2">
              <div class="h-4 bg-slate-200 rounded skeleton w-full"></div>
              <div class="h-4 bg-slate-200 rounded skeleton w-3/4"></div>
              <%= if rem(:rand.uniform(), 3) == 0 do %>
                <div class="h-4 bg-slate-200 rounded skeleton w-1/2"></div>
              <% end %>
            </div>
            
            <!-- Reactions skeleton (randomly shown) -->
            <%= if rem(:rand.uniform(), 4) == 0 do %>
              <div class="flex space-x-1 mt-2">
                <div class="h-6 w-12 bg-slate-200 rounded-full skeleton"></div>
                <div class="h-6 w-10 bg-slate-200 rounded-full skeleton"></div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Channel List Skeleton
  defp channel_list_skeleton(assigns) do
    ~H"""
    <div class="space-y-4 p-4">
      <!-- Workspace header skeleton -->
      <div class="animate-pulse">
        <div class="flex items-center space-x-3">
          <div class="h-6 bg-slate-200 rounded skeleton w-32"></div>
          <div class="w-4 h-4 bg-slate-200 rounded skeleton"></div>
        </div>
        <div class="mt-2 flex items-center space-x-2">
          <div class="w-3 h-3 bg-slate-200 rounded-full skeleton"></div>
          <div class="h-3 bg-slate-200 rounded skeleton w-20"></div>
        </div>
      </div>
      
      <!-- Search skeleton -->
      <div class="h-9 bg-slate-200 rounded skeleton animate-pulse"></div>
      
      <!-- Threads skeleton -->
      <div class="animate-pulse">
        <div class="flex items-center justify-between p-2">
          <div class="flex items-center space-x-2">
            <div class="w-4 h-4 bg-slate-200 rounded skeleton"></div>
            <div class="h-4 bg-slate-200 rounded skeleton w-16"></div>
          </div>
        </div>
      </div>
      
      <!-- Channels section skeleton -->
      <div class="space-y-2">
        <div class="flex items-center space-x-2 animate-pulse">
          <div class="w-3 h-3 bg-slate-200 rounded skeleton"></div>
          <div class="h-4 bg-slate-200 rounded skeleton w-20"></div>
        </div>
        
        <!-- Channel items -->
        <%= for _ <- 1..5 do %>
          <div class="flex items-center space-x-2 p-2 animate-pulse">
            <div class="w-4 h-4 bg-slate-200 rounded skeleton"></div>
            <div class="h-4 bg-slate-200 rounded skeleton flex-1"></div>
            <%= if rem(:rand.uniform(), 3) == 0 do %>
              <div class="w-5 h-4 bg-red-200 rounded-full skeleton"></div>
            <% end %>
          </div>
        <% end %>
      </div>
      
      <!-- DMs section skeleton -->
      <div class="space-y-2">
        <div class="flex items-center space-x-2 animate-pulse">
          <div class="w-3 h-3 bg-slate-200 rounded skeleton"></div>
          <div class="h-4 bg-slate-200 rounded skeleton w-28"></div>
        </div>
        
        <!-- DM items -->
        <%= for _ <- 1..6 do %>
          <div class="flex items-center space-x-2 p-2 animate-pulse">
            <div class="w-5 h-5 bg-slate-200 rounded skeleton"></div>
            <div class="h-4 bg-slate-200 rounded skeleton flex-1"></div>
            <%= if rem(:rand.uniform(), 4) == 0 do %>
              <div class="w-2 h-2 bg-red-200 rounded-full skeleton"></div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Thread Skeleton
  defp thread_skeleton(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Thread header skeleton -->
      <div class="flex items-center justify-between p-4 border-b border-slate-200 animate-pulse">
        <div class="h-5 bg-slate-200 rounded skeleton w-16"></div>
        <div class="w-5 h-5 bg-slate-200 rounded skeleton"></div>
      </div>
      
      <!-- Original message skeleton -->
      <div class="border-b border-slate-200 p-4">
        <div class="flex space-x-3 animate-pulse">
          <div class="w-10 h-10 bg-slate-200 rounded skeleton"></div>
          <div class="flex-1 space-y-2">
            <div class="flex items-center space-x-3">
              <div class="h-4 bg-slate-200 rounded skeleton w-24"></div>
              <div class="h-3 bg-slate-200 rounded skeleton w-16"></div>
            </div>
            <div class="space-y-2">
              <div class="h-4 bg-slate-200 rounded skeleton w-full"></div>
              <div class="h-4 bg-slate-200 rounded skeleton w-2/3"></div>
            </div>
            <!-- Reactions -->
            <div class="flex space-x-1">
              <div class="h-6 w-12 bg-slate-200 rounded-full skeleton"></div>
              <div class="h-6 w-10 bg-slate-200 rounded-full skeleton"></div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Thread replies skeleton -->
      <div class="p-4 space-y-4">
        <%= for _ <- 1..3 do %>
          <div class="flex space-x-3 animate-pulse">
            <div class="w-8 h-8 bg-slate-200 rounded skeleton"></div>
            <div class="flex-1 space-y-2">
              <div class="flex items-center space-x-3">
                <div class="h-3 bg-slate-200 rounded skeleton w-20"></div>
                <div class="h-3 bg-slate-200 rounded skeleton w-12"></div>
              </div>
              <div class="space-y-1">
                <div class="h-4 bg-slate-200 rounded skeleton w-full"></div>
                <div class="h-4 bg-slate-200 rounded skeleton w-1/2"></div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Sidebar Skeleton
  defp sidebar_skeleton(assigns) do
    ~H"""
    <div class="space-y-4 p-4">
      <!-- Header skeleton -->
      <div class="flex items-center justify-between animate-pulse">
        <div class="h-5 bg-slate-200 rounded skeleton w-32"></div>
        <div class="w-5 h-5 bg-slate-200 rounded skeleton"></div>
      </div>
      
      <!-- Info section -->
      <div class="space-y-3">
        <div class="flex items-center space-x-3 animate-pulse">
          <div class="w-12 h-12 bg-slate-200 rounded-lg skeleton"></div>
          <div class="space-y-2">
            <div class="h-5 bg-slate-200 rounded skeleton w-28"></div>
            <div class="h-3 bg-slate-200 rounded skeleton w-20"></div>
          </div>
        </div>
        
        <div class="h-4 bg-slate-200 rounded skeleton w-full animate-pulse"></div>
        <div class="h-4 bg-slate-200 rounded skeleton w-3/4 animate-pulse"></div>
      </div>
      
      <!-- Settings skeleton -->
      <div class="space-y-3">
        <%= for _ <- 1..3 do %>
          <div class="flex items-center justify-between animate-pulse">
            <div class="flex items-center space-x-3">
              <div class="w-5 h-5 bg-slate-200 rounded skeleton"></div>
              <div class="space-y-1">
                <div class="h-4 bg-slate-200 rounded skeleton w-24"></div>
                <div class="h-3 bg-slate-200 rounded skeleton w-32"></div>
              </div>
            </div>
            <div class="h-4 bg-slate-200 rounded skeleton w-10"></div>
          </div>
        <% end %>
      </div>
      
      <!-- Members skeleton -->
      <div class="space-y-3">
        <div class="flex items-center justify-between animate-pulse">
          <div class="h-4 bg-slate-200 rounded skeleton w-20"></div>
          <div class="h-4 bg-slate-200 rounded skeleton w-16"></div>
        </div>
        
        <%= for _ <- 1..5 do %>
          <div class="flex items-center space-x-3 animate-pulse">
            <div class="w-8 h-8 bg-slate-200 rounded skeleton"></div>
            <div class="flex-1 space-y-1">
              <div class="h-4 bg-slate-200 rounded skeleton w-full"></div>
              <div class="h-3 bg-slate-200 rounded skeleton w-2/3"></div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Search Skeleton
  defp search_skeleton(assigns) do
    ~H"""
    <div class="space-y-4 p-4">
      <!-- Search input skeleton -->
      <div class="h-10 bg-slate-200 rounded-lg skeleton animate-pulse"></div>
      
      <!-- Filter tabs skeleton -->
      <div class="flex space-x-2">
        <%= for _ <- 1..4 do %>
          <div class="h-8 w-16 bg-slate-200 rounded skeleton animate-pulse"></div>
        <% end %>
      </div>
      
      <!-- Results skeleton -->
      <div class="space-y-4">
        <%= for _ <- 1..6 do %>
          <div class="border border-slate-200 rounded-lg p-4 space-y-3 animate-pulse">
            <!-- Header -->
            <div class="flex items-center space-x-3">
              <div class="w-6 h-6 bg-slate-200 rounded skeleton"></div>
              <div class="h-4 bg-slate-200 rounded skeleton w-24"></div>
              <div class="h-3 bg-slate-200 rounded skeleton w-16"></div>
            </div>
            
            <!-- Content -->
            <div class="space-y-2">
              <div class="h-4 bg-slate-200 rounded skeleton w-full"></div>
              <div class="h-4 bg-slate-200 rounded skeleton w-5/6"></div>
            </div>
            
            <!-- Metadata -->
            <div class="flex items-center space-x-2">
              <div class="h-3 bg-slate-200 rounded skeleton w-20"></div>
              <div class="h-3 bg-slate-200 rounded skeleton w-24"></div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Default Skeleton
  defp default_skeleton(assigns) do
    ~H"""
    <div class="space-y-4 p-4">
      <%= for _ <- 1..(@count || 5) do %>
        <div class="animate-pulse">
          <div class="flex space-x-3">
            <div class="w-10 h-10 bg-slate-200 rounded skeleton"></div>
            <div class="flex-1 space-y-2">
              <div class="h-4 bg-slate-200 rounded skeleton w-1/4"></div>
              <div class="space-y-1">
                <div class="h-4 bg-slate-200 rounded skeleton w-full"></div>
                <div class="h-4 bg-slate-200 rounded skeleton w-3/4"></div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end