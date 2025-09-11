defmodule SlackCloneWeb.PerformanceDashboardLive do
  @moduledoc """
  Real-time performance monitoring dashboard with interactive charts,
  metrics visualization, and alert management for the Slack clone.
  """
  use SlackCloneWeb, :live_view
  
  alias SlackClone.Performance.Monitor
  
  @refresh_interval 5000  # 5 seconds
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to performance updates
      Phoenix.PubSub.subscribe(SlackClone.PubSub, "admin:alerts")
      Phoenix.PubSub.subscribe(SlackClone.PubSub, "admin:metrics")
      
      # Schedule periodic updates
      :timer.send_interval(@refresh_interval, :refresh_dashboard)
      
      # Initial data load
      send(self(), :refresh_dashboard)
    end
    
    socket =
      socket
      |> assign(:dashboard_data, %{})
      |> assign(:selected_metric, "response_times")
      |> assign(:time_range, "1h")
      |> assign(:auto_refresh, true)
      |> assign(:alerts, [])
      |> assign(:system_health, 0)
      |> assign(:loading, true)
    
    {:ok, socket}
  end
  
  @impl true
  def handle_event("toggle_auto_refresh", _params, socket) do
    socket = assign(socket, :auto_refresh, not socket.assigns.auto_refresh)
    {:noreply, socket}
  end
  
  def handle_event("change_metric", %{"metric" => metric}, socket) do
    socket = 
      socket
      |> assign(:selected_metric, metric)
      |> assign(:loading, true)
    
    send(self(), :refresh_dashboard)
    {:noreply, socket}
  end
  
  def handle_event("change_time_range", %{"range" => range}, socket) do
    socket = 
      socket
      |> assign(:time_range, range)
      |> assign(:loading, true)
    
    send(self(), :refresh_dashboard)
    {:noreply, socket}
  end
  
  def handle_event("acknowledge_alert", %{"alert_id" => alert_id}, socket) do
    # In a real implementation, you'd acknowledge the alert in the monitor
    alerts = Enum.reject(socket.assigns.alerts, &(&1.id == alert_id))
    socket = assign(socket, :alerts, alerts)
    
    {:noreply, put_flash(socket, :info, "Alert acknowledged")}
  end
  
  def handle_event("refresh_now", _params, socket) do
    send(self(), :refresh_dashboard)
    {:noreply, assign(socket, :loading, true)}
  end
  
  @impl true
  def handle_info(:refresh_dashboard, socket) do
    if socket.assigns.auto_refresh or socket.assigns.loading do
      dashboard_data = Monitor.get_dashboard_data()
      alerts = Monitor.get_active_alerts()
      
      socket =
        socket
        |> assign(:dashboard_data, dashboard_data)
        |> assign(:alerts, alerts)
        |> assign(:system_health, dashboard_data.system_health || 0)
        |> assign(:loading, false)
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  def handle_info({:critical_alert, alert}, socket) do
    alerts = [alert | socket.assigns.alerts]
    socket = 
      socket
      |> assign(:alerts, alerts)
      |> put_flash(:error, "Critical Alert: #{alert.message}")
    
    {:noreply, socket}
  end
  
  def handle_info(_message, socket) do
    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="performance-dashboard min-h-screen bg-gray-50">
      <!-- Dashboard Header -->
      <div class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-4 py-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Performance Dashboard</h1>
              <p class="text-sm text-gray-500">Real-time monitoring and alerts</p>
            </div>
            
            <div class="flex items-center space-x-4">
              <!-- Auto-refresh toggle -->
              <label class="flex items-center">
                <input
                  type="checkbox"
                  checked={@auto_refresh}
                  phx-click="toggle_auto_refresh"
                  class="sr-only"
                />
                <div class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors #{if @auto_refresh, do: "bg-blue-600", else: "bg-gray-200"}"}>
                  <span class={"inline-block h-4 w-4 transform rounded-full bg-white transition-transform #{if @auto_refresh, do: "translate-x-6", else: "translate-x-1"}"}>
                  </span>
                </div>
                <span class="ml-2 text-sm text-gray-700">Auto-refresh</span>
              </label>
              
              <!-- Refresh button -->
              <button
                phx-click="refresh_now"
                class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <%= if @loading do %>
                  <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-500" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                <% end %>
                Refresh
              </button>
              
              <!-- Time range selector -->
              <select
                phx-change="change_time_range"
                class="rounded-md border-gray-300 text-sm focus:border-blue-500 focus:ring-blue-500"
              >
                <option value="15m" selected={@time_range == "15m"}>15 minutes</option>
                <option value="1h" selected={@time_range == "1h"}>1 hour</option>
                <option value="6h" selected={@time_range == "6h"}>6 hours</option>
                <option value="24h" selected={@time_range == "24h"}>24 hours</option>
              </select>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Alerts Section -->
      <%= if length(@alerts) > 0 do %>
        <div class="bg-red-50 border-l-4 border-red-400 p-4 mb-6">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3 flex-1">
              <h3 class="text-sm font-medium text-red-800">
                Active Alerts (<%= length(@alerts) %>)
              </h3>
              <div class="mt-2 text-sm text-red-700">
                <%= for alert <- @alerts do %>
                  <div class="flex items-center justify-between py-1">
                    <span><%= alert.message %></span>
                    <button
                      phx-click="acknowledge_alert"
                      phx-value-alert_id={alert.id}
                      class="ml-2 text-xs text-red-600 hover:text-red-800"
                    >
                      Acknowledge
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      
      <!-- Key Metrics Cards -->
      <div class="max-w-7xl mx-auto px-4 py-6">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <%= render_metric_card("System Health", @system_health, "%", get_health_color(@system_health)) %>
          <%= render_metric_card("Active Connections", get_active_connections(@dashboard_data), "", "text-blue-600") %>
          <%= render_metric_card("Messages/sec", get_message_throughput(@dashboard_data), "", "text-green-600") %>
          <%= render_metric_card("Avg Response", get_avg_response_time(@dashboard_data), "ms", get_response_time_color(@dashboard_data)) %>
        </div>
        
        <!-- Charts Section -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <!-- Response Times Chart -->
          <div class="bg-white p-6 rounded-lg shadow">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Response Times</h3>
            <div id="response-times-chart" class="h-64" phx-hook="ResponseTimesChart">
              <%= render_placeholder_chart("Response Times") %>
            </div>
          </div>
          
          <!-- System Resources Chart -->
          <div class="bg-white p-6 rounded-lg shadow">
            <h3 class="text-lg font-medium text-gray-900 mb-4">System Resources</h3>
            <div id="system-resources-chart" class="h-64" phx-hook="SystemResourcesChart">
              <%= render_placeholder_chart("System Resources") %>
            </div>
          </div>
          
          <!-- Cache Performance Chart -->
          <div class="bg-white p-6 rounded-lg shadow">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Cache Performance</h3>
            <div id="cache-chart" class="h-64" phx-hook="CacheChart">
              <%= render_placeholder_chart("Cache Hit Ratio") %>
            </div>
          </div>
          
          <!-- Database Performance Chart -->
          <div class="bg-white p-6 rounded-lg shadow">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Database Performance</h3>
            <div id="database-chart" class="h-64" phx-hook="DatabaseChart">
              <%= render_placeholder_chart("Database Metrics") %>
            </div>
          </div>
        </div>
        
        <!-- Bottlenecks Table -->
        <div class="bg-white p-6 rounded-lg shadow mb-8">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Performance Bottlenecks</h3>
          <%= render_bottlenecks_table(@dashboard_data) %>
        </div>
        
        <!-- Real-time Metrics Stream -->
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Live Metrics</h3>
          <%= render_live_metrics(@dashboard_data) %>
        </div>
      </div>
    </div>
    """
  end
  
  # Helper render functions
  
  defp render_metric_card(title, value, unit, color_class) do
    assigns = %{title: title, value: value, unit: unit, color_class: color_class}
    
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class={"w-8 h-8 rounded-md flex items-center justify-center #{@color_class} bg-opacity-10"}>
              <span class={"text-sm font-medium #{@color_class}"}>#</span>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">
                <%= @title %>
              </dt>
              <dd class="text-lg font-medium text-gray-900">
                <%= format_metric_value(@value) %><span class="text-sm text-gray-500"><%= @unit %></span>
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  defp render_placeholder_chart(title) do
    assigns = %{title: title}
    
    ~H"""
    <div class="flex items-center justify-center h-full bg-gray-50 rounded">
      <div class="text-center">
        <div class="animate-pulse">
          <div class="h-32 w-48 bg-gray-200 rounded mb-4"></div>
          <div class="h-4 bg-gray-200 rounded w-32 mx-auto"></div>
        </div>
        <p class="text-sm text-gray-500 mt-2">Loading <%= @title %>...</p>
      </div>
    </div>
    """
  end
  
  defp render_bottlenecks_table(dashboard_data) do
    bottlenecks = Map.get(dashboard_data, :bottlenecks, [])
    
    assigns = %{bottlenecks: bottlenecks}
    
    ~H"""
    <%= if length(@bottlenecks) > 0 do %>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Type
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Description
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Impact
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Action
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for bottleneck <- @bottlenecks do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{get_bottleneck_color(bottleneck.type)}"}>
                    <%= format_bottleneck_type(bottleneck.type) %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= format_bottleneck_description(bottleneck) %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= get_bottleneck_impact(bottleneck) %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-blue-600">
                  <button class="hover:text-blue-800">Investigate</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <div class="text-center py-8">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No Bottlenecks Detected</h3>
        <p class="mt-1 text-sm text-gray-500">System is performing optimally.</p>
      </div>
    <% end %>
    """
  end
  
  defp render_live_metrics(dashboard_data) do
    current_metrics = Map.get(dashboard_data, :current_metrics, %{})
    
    assigns = %{metrics: current_metrics}
    
    ~H"""
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="text-center">
        <div class="text-2xl font-bold text-gray-900">
          <%= get_process_count(@metrics) %>
        </div>
        <div class="text-sm text-gray-500">Active Processes</div>
      </div>
      
      <div class="text-center">
        <div class="text-2xl font-bold text-gray-900">
          <%= get_memory_usage(@metrics) %>MB
        </div>
        <div class="text-sm text-gray-500">Memory Usage</div>
      </div>
      
      <div class="text-center">
        <div class="text-2xl font-bold text-gray-900">
          <%= get_cache_hit_ratio(@metrics) %>%
        </div>
        <div class="text-sm text-gray-500">Cache Hit Ratio</div>
      </div>
      
      <div class="text-center">
        <div class="text-2xl font-bold text-gray-900">
          <%= get_error_count(@metrics) %>
        </div>
        <div class="text-sm text-gray-500">Errors/min</div>
      </div>
    </div>
    """
  end
  
  # Helper functions for data extraction and formatting
  
  defp get_health_color(health) when health >= 80, do: "text-green-600"
  defp get_health_color(health) when health >= 60, do: "text-yellow-600"
  defp get_health_color(_health), do: "text-red-600"
  
  defp get_response_time_color(dashboard_data) do
    avg_time = get_avg_response_time(dashboard_data)
    cond do
      avg_time < 200 -> "text-green-600"
      avg_time < 500 -> "text-yellow-600"
      true -> "text-red-600"
    end
  end
  
  defp get_active_connections(dashboard_data) do
    dashboard_data
    |> get_in([:current_metrics, :active_connections])
    |> format_metric_value()
  end
  
  defp get_message_throughput(dashboard_data) do
    dashboard_data
    |> get_in([:current_metrics, :message_throughput])
    |> format_metric_value()
  end
  
  defp get_avg_response_time(dashboard_data) do
    response_times = get_in(dashboard_data, [:current_metrics, :response_times]) || %{}
    
    if map_size(response_times) > 0 do
      response_times
      |> Map.values()
      |> Enum.map(& &1.avg)
      |> Enum.sum()
      |> div(map_size(response_times))
    else
      0
    end
  end
  
  defp get_process_count(metrics) do
    get_in(metrics, [:system_stats, :process_count]) || 0
  end
  
  defp get_memory_usage(metrics) do
    case get_in(metrics, [:system_stats, :memory, :total]) do
      nil -> 0
      bytes -> round(bytes / (1024 * 1024))
    end
  end
  
  defp get_cache_hit_ratio(metrics) do
    case get_in(metrics, [:cache_stats, :hit_ratio]) do
      nil -> 0
      ratio -> round(ratio * 100)
    end
  end
  
  defp get_error_count(metrics) do
    case get_in(metrics, [:error_counts]) do
      nil -> 0
      errors when is_map(errors) ->
        errors |> Map.values() |> Enum.sum()
      _ -> 0
    end
  end
  
  defp format_metric_value(nil), do: "0"
  defp format_metric_value(value) when is_number(value), do: :erlang.float_to_binary(value / 1, [{:decimals, 1}])
  defp format_metric_value(value), do: to_string(value)
  
  defp get_bottleneck_color(:response_time), do: "bg-red-100 text-red-800"
  defp get_bottleneck_color(:cpu), do: "bg-yellow-100 text-yellow-800"
  defp get_bottleneck_color(:memory), do: "bg-orange-100 text-orange-800"
  defp get_bottleneck_color(:db_queue), do: "bg-purple-100 text-purple-800"
  defp get_bottleneck_color(_), do: "bg-gray-100 text-gray-800"
  
  defp format_bottleneck_type(:response_time), do: "Response Time"
  defp format_bottleneck_type(:cpu), do: "CPU"
  defp format_bottleneck_type(:memory), do: "Memory"
  defp format_bottleneck_type(:db_queue), do: "Database Queue"
  defp format_bottleneck_type(type), do: type |> to_string() |> String.capitalize()
  
  defp format_bottleneck_description(%{type: :response_time, operation: op, avg_time: time}) do
    "#{op}: #{time}ms average"
  end
  
  defp format_bottleneck_description(%{type: :cpu, usage: usage}) do
    "CPU usage at #{usage}%"
  end
  
  defp format_bottleneck_description(%{type: :memory, usage_gb: usage}) do
    "Memory usage: #{:erlang.float_to_binary(usage, [{:decimals, 1}])}GB"
  end
  
  defp format_bottleneck_description(%{type: :db_queue, length: length}) do
    "Database queue length: #{length}"
  end
  
  defp format_bottleneck_description(_), do: "Unknown bottleneck"
  
  defp get_bottleneck_impact(%{type: :response_time}), do: "High"
  defp get_bottleneck_impact(%{type: :cpu}), do: "Medium"
  defp get_bottleneck_impact(%{type: :memory}), do: "Medium"
  defp get_bottleneck_impact(%{type: :db_queue}), do: "High"
  defp get_bottleneck_impact(_), do: "Low"
end