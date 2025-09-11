defmodule SlackCloneWeb.PresenceLive do
  @moduledoc """
  LiveView component for displaying online users with real-time presence updates.
  Shows user status, activity indicators, and handles presence diffs efficiently.
  """
  use SlackCloneWeb, :live_component

  alias SlackClone.PubSub
  alias SlackCloneWeb.Presence

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:show_all_users, false)
      |> assign(:user_filter, "")

    {:ok, socket}
  end

  @impl true
  def update(%{online_users: online_users} = assigns, socket) do
    # Process online users for display
    processed_users = 
      online_users
      |> Map.values()
      |> sort_users_by_status()
      |> add_activity_indicators()

    socket =
      socket
      |> assign(assigns)
      |> assign(:processed_users, processed_users)
      |> assign(:total_online, map_size(online_users))

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_show_all", _params, socket) do
    {:noreply, assign(socket, :show_all_users, !socket.assigns.show_all_users)}
  end

  def handle_event("filter_users", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :user_filter, filter)}
  end

  def handle_event("start_dm", %{"user_id" => user_id}, socket) do
    # Send message to parent to handle DM creation
    send(self(), {:start_direct_message, user_id})
    {:noreply, socket}
  end

  def handle_event("view_profile", %{"user_id" => user_id}, socket) do
    # Send message to parent to show user profile
    send(self(), {:view_user_profile, user_id})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    filtered_users = filter_users(assigns.processed_users, assigns.user_filter)
    display_users = 
      if assigns.show_all_users do
        filtered_users
      else
        Enum.take(filtered_users, 10)
      end

    assigns = assign(assigns, :display_users, display_users)

    ~H"""
    <div class="p-4">
      <!-- Header -->
      <div class="flex items-center justify-between mb-3">
        <h3 class="text-sm font-semibold text-slack-text-primary">
          Online — <%= @total_online %>
        </h3>
        <%= if @total_online > 10 do %>
          <button
            phx-click="toggle_show_all"
            phx-target={@myself}
            class="text-xs text-slack-text-secondary hover:text-slack-text-primary"
          >
            <%= if @show_all_users, do: "Show less", else: "Show all" %>
          </button>
        <% end %>
      </div>

      <!-- Search Filter (shown when many users) -->
      <%= if @total_online > 5 do %>
        <div class="mb-3">
          <input
            type="text"
            placeholder="Find members..."
            value={@user_filter}
            phx-change="filter_users"
            phx-target={@myself}
            class="w-full text-xs px-2 py-1 border border-slack-border rounded focus:border-slack-primary focus:ring-1 focus:ring-slack-primary"
          />
        </div>
      <% end %>

      <!-- User List -->
      <div class="space-y-1 max-h-64 overflow-y-auto">
        <%= for user <- @display_users do %>
          <.user_item 
            user={user} 
            current_user_id={@current_user && @current_user.id}
            target={@myself}
          />
        <% end %>

        <!-- Show more indicator -->
        <%= if !@show_all_users && length(@processed_users) > 10 do %>
          <button
            phx-click="toggle_show_all"
            phx-target={@myself}
            class="w-full text-xs text-slack-text-secondary hover:text-slack-text-primary py-2 text-center"
          >
            +<%= length(@processed_users) - 10 %> more
          </button>
        <% end %>

        <!-- Empty state -->
        <%= if @total_online == 0 do %>
          <div class="text-center py-4">
            <p class="text-xs text-slack-text-secondary">No one else is online</p>
          </div>
        <% end %>
      </div>

      <!-- Activity Summary -->
      <div class="mt-3 pt-3 border-t border-slack-border">
        <div class="text-xs text-slack-text-secondary space-y-1">
          <div class="flex justify-between">
            <span>Active:</span>
            <span><%= count_by_status(@processed_users, "online") %></span>
          </div>
          <div class="flex justify-between">
            <span>Away:</span>
            <span><%= count_by_status(@processed_users, "away") %></span>
          </div>
          <%= if count_by_status(@processed_users, "busy") > 0 do %>
            <div class="flex justify-between">
              <span>Busy:</span>
              <span><%= count_by_status(@processed_users, "busy") %></span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # User item component
  defp user_item(assigns) do
    ~H"""
    <div class="group flex items-center space-x-2 p-1 rounded hover:bg-slack-bg-hover cursor-pointer">
      <!-- Avatar with status indicator -->
      <div class="relative">
        <img 
          src={@user.avatar_url || "/images/default-avatar.png"} 
          alt={@user.name}
          class="w-6 h-6 rounded flex-shrink-0"
        />
        <div class={[
          "absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-white",
          status_color(@user.status)
        ]}>
        </div>
        <%= if @user.activity_indicator do %>
          <div class="absolute -top-0.5 -right-0.5 w-2 h-2 bg-slack-primary rounded-full animate-pulse"></div>
        <% end %>
      </div>

      <!-- User Info -->
      <div class="flex-1 min-w-0 text-xs">
        <div class="flex items-center space-x-1">
          <span class={[
            "font-medium truncate",
            if(@user.user_id == @current_user_id, do: "text-slack-primary", else: "text-slack-text-primary")
          ]}>
            <%= if @user.user_id == @current_user_id do %>
              <%= @user.name %> (you)
            <% else %>
              <%= @user.name %>
            <% end %>
          </span>
          <%= if @user.status == "busy" do %>
            <span class="text-red-500" title="Do not disturb">🚫</span>
          <% end %>
        </div>
        
        <%= if @user.custom_status do %>
          <div class="text-slack-text-secondary truncate">
            <%= @user.custom_status %>
          </div>
        <% end %>
        
        <%= if @user.typing_in_channel do %>
          <div class="text-slack-primary text-xs">
            typing in #<%= @user.typing_in_channel %>...
          </div>
        <% end %>
      </div>

      <!-- Actions (shown on hover) -->
      <%= if @user.user_id != @current_user_id do %>
        <div class="opacity-0 group-hover:opacity-100 transition-opacity flex space-x-1">
          <button
            phx-click="start_dm"
            phx-value-user_id={@user.user_id}
            phx-target={@target}
            class="p-1 rounded hover:bg-slack-bg text-slack-text-secondary hover:text-slack-text-primary"
            title="Send direct message"
          >
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </button>
          
          <button
            phx-click="view_profile"
            phx-value-user_id={@user.user_id}
            phx-target={@target}
            class="p-1 rounded hover:bg-slack-bg text-slack-text-secondary hover:text-slack-text-primary"
            title="View profile"
          >
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Private helper functions

  defp sort_users_by_status(users) do
    # Sort by status priority, then by name
    Enum.sort_by(users, fn user ->
      status_priority = case user.status do
        "online" -> 0
        "away" -> 1
        "busy" -> 2
        _ -> 3
      end
      {status_priority, String.downcase(user.name)}
    end)
  end

  defp add_activity_indicators(users) do
    # Add activity indicators based on recent activity
    Enum.map(users, fn user ->
      activity_indicator = 
        cond do
          recently_active?(user) -> true
          user.status == "typing" -> true
          true -> false
        end
      
      Map.put(user, :activity_indicator, activity_indicator)
    end)
  end

  defp recently_active?(user) do
    # Check if user was active in the last 5 minutes
    case user.last_seen_at do
      nil -> false
      last_seen -> 
        DateTime.diff(DateTime.utc_now(), last_seen, :minute) < 5
    end
  end

  defp filter_users(users, "") do
    users
  end

  defp filter_users(users, filter) do
    filter_lower = String.downcase(filter)
    
    Enum.filter(users, fn user ->
      String.contains?(String.downcase(user.name), filter_lower) ||
      (user.custom_status && String.contains?(String.downcase(user.custom_status), filter_lower))
    end)
  end

  defp status_color("online"), do: "bg-green-400"
  defp status_color("away"), do: "bg-yellow-400"
  defp status_color("busy"), do: "bg-red-400"
  defp status_color(_), do: "bg-gray-300"

  defp count_by_status(users, status) do
    Enum.count(users, &(&1.status == status))
  end
end