defmodule SlackCloneWeb.ChannelItemComponent do
  @moduledoc """
  LiveView component for displaying individual channel items in the sidebar.
  Shows channel name, unread count, activity indicators, and handles selection.
  """
  use SlackCloneWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-between px-3 py-1 rounded hover:bg-slack-bg-hover cursor-pointer transition-colors",
      if(@channel.id == @current_channel_id, do: "bg-slack-primary-light text-slack-primary", else: "text-slack-text-primary hover:text-slack-text-primary")
    ]}>
      <!-- Channel Info -->
      <div class="flex items-center space-x-2 flex-1 min-w-0">
        <!-- Channel Type Icon -->
        <div class="flex-shrink-0">
          <%= if @channel.type == "private" do %>
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          <% else %>
            <span class="text-sm font-medium">#</span>
          <% end %>
        </div>
        
        <!-- Channel Name -->
        <span class={[
          "text-sm truncate",
          if(@unread_count > 0, do: "font-semibold", else: "font-normal")
        ]}>
          <%= @channel.name %>
        </span>
      </div>

      <!-- Channel Indicators -->
      <div class="flex items-center space-x-1 flex-shrink-0">
        <!-- Unread Count -->
        <%= if @unread_count > 0 do %>
          <span class="bg-slack-danger text-white text-xs rounded-full px-2 py-0.5 min-w-[20px] text-center">
            <%= if @unread_count > 99, do: "99+", else: @unread_count %>
          </span>
        <% end %>

        <!-- Activity Indicator -->
        <%= if @channel.has_activity do %>
          <div class="w-2 h-2 bg-slack-primary rounded-full animate-pulse"></div>
        <% end %>

        <!-- Muted Indicator -->
        <%= if @channel.muted do %>
          <svg class="w-3 h-3 text-slack-text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
          </svg>
        <% end %>
      </div>

      <!-- Hover Actions -->
      <div class="opacity-0 group-hover:opacity-100 transition-opacity ml-1">
        <div class="flex space-x-1">
          <!-- Options Button -->
          <button
            phx-click="show_channel_options"
            phx-value-channel_id={@channel.id}
            class="p-0.5 rounded hover:bg-slack-bg-light text-slack-text-secondary hover:text-slack-text-primary"
            title="More options"
          >
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("show_channel_options", %{"channel_id" => channel_id}, socket) do
    send(self(), {:show_channel_options, channel_id})
    {:noreply, socket}
  end
end