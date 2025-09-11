defmodule SlackCloneWeb.ChannelChannel do
  @moduledoc """
  WebSocket channel for real-time communication within specific channels.
  Handles messages, typing indicators, reactions, and thread discussions.
  """
  use SlackCloneWeb, :channel

  alias SlackClone.PubSub
  alias SlackCloneWeb.Presence

  # Typing indicator cleanup interval (3 seconds)
  @typing_timeout 3_000

  @impl true
  def join("channel:" <> channel_id, params, socket) do
    user = socket.assigns.current_user
    
    case authorize_channel_access(channel_id, user) do
      {:ok, channel} ->
        send(self(), :after_join)
        
        socket = 
          socket
          |> assign(:channel_id, channel_id)
          |> assign(:channel, channel)
          |> assign(:typing_timer, nil)

        {:ok, %{channel: channel}, socket}
      
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true  
  def handle_info(:after_join, socket) do
    user = socket.assigns.current_user
    channel_id = socket.assigns.channel_id
    
    # Track presence in channel
    {:ok, _} = Presence.track(socket, user.id, %{
      name: user.name,
      avatar_url: user.avatar_url,
      joined_at: System.system_time(:second)
    })

    # Subscribe to channel events
    PubSub.subscribe_to_channel(channel_id)

    # Load and send recent messages
    messages = load_recent_messages(channel_id, 50)
    push(socket, "messages_loaded", %{messages: messages})

    # Send current presence
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  @impl true
  def handle_in("send_message", %{"content" => content, "thread_id" => thread_id}, socket) when is_binary(thread_id) do
    # Handle thread reply
    handle_thread_reply(socket, content, thread_id)
  end

  def handle_in("send_message", %{"content" => content} = params, socket) do
    user = socket.assigns.current_user
    channel_id = socket.assigns.channel_id

    case create_message(channel_id, user.id, content, extract_message_metadata(params)) do
      {:ok, message} ->
        # Broadcast to channel subscribers
        PubSub.broadcast_new_message(channel_id, message)
        
        # Send acknowledgment
        push(socket, "message_sent", %{
          temp_id: params["temp_id"],
          message: message
        })

        {:noreply, socket}

      {:error, changeset} ->
        push(socket, "message_error", %{
          temp_id: params["temp_id"],
          errors: format_changeset_errors(changeset)
        })
        {:noreply, socket}
    end
  end

  def handle_in("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    user_id = socket.assigns.current_user.id

    case edit_message(message_id, content, user_id) do
      {:ok, message} ->
        # Broadcast update
        PubSub.broadcast_message_updated(socket.assigns.channel_id, message)
        
        push(socket, "message_edited", %{message: message})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "edit_error", %{message_id: message_id, reason: reason})
        {:noreply, socket}
    end
  end

  def handle_in("delete_message", %{"message_id" => message_id}, socket) do
    user_id = socket.assigns.current_user.id

    case delete_message(message_id, user_id) do
      {:ok, _} ->
        # Broadcast deletion
        PubSub.broadcast_message_deleted(socket.assigns.channel_id, message_id)
        
        push(socket, "message_deleted", %{message_id: message_id})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "delete_error", %{message_id: message_id, reason: reason})
        {:noreply, socket}
    end
  end

  def handle_in("typing_start", _params, socket) do
    user = socket.assigns.current_user
    channel_id = socket.assigns.channel_id

    # Cancel previous typing timer
    if socket.assigns.typing_timer do
      Process.cancel_timer(socket.assigns.typing_timer)
    end

    # Broadcast typing start
    PubSub.broadcast_typing_start(channel_id, user)

    # Set timer to automatically stop typing indicator
    timer = Process.send_after(self(), :typing_timeout, @typing_timeout)
    socket = assign(socket, :typing_timer, timer)

    {:noreply, socket}
  end

  def handle_in("typing_stop", _params, socket) do
    handle_typing_stop(socket)
  end

  def handle_in("add_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    user_id = socket.assigns.current_user.id

    case add_reaction_to_message(message_id, emoji, user_id) do
      {:ok, reaction} ->
        # Broadcast reaction
        PubSub.broadcast_reaction_added(socket.assigns.channel_id, message_id, reaction)
        
        push(socket, "reaction_added", %{message_id: message_id, reaction: reaction})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "reaction_error", %{message_id: message_id, reason: reason})
        {:noreply, socket}
    end
  end

  def handle_in("remove_reaction", %{"reaction_id" => reaction_id}, socket) do
    user_id = socket.assigns.current_user.id

    case remove_reaction(reaction_id, user_id) do
      {:ok, reaction} ->
        # Broadcast reaction removal
        PubSub.broadcast_reaction_removed(socket.assigns.channel_id, reaction.message_id, reaction)
        
        push(socket, "reaction_removed", %{reaction: reaction})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "reaction_remove_error", %{reaction_id: reaction_id, reason: reason})
        {:noreply, socket}
    end
  end

  def handle_in("mark_read", %{"message_id" => message_id}, socket) do
    user_id = socket.assigns.current_user.id

    case mark_message_as_read(message_id, user_id) do
      {:ok, _} ->
        # Broadcast read receipt
        PubSub.broadcast_message_read(socket.assigns.channel_id, message_id, user_id)
        {:noreply, socket}

      {:error, _reason} ->
        # Silently ignore read receipt errors
        {:noreply, socket}
    end
  end

  def handle_in("load_older_messages", %{"before_id" => before_id}, socket) do
    channel_id = socket.assigns.channel_id
    
    case load_messages_before(channel_id, before_id, 20) do
      {:ok, messages} ->
        push(socket, "older_messages_loaded", %{messages: messages})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "load_error", %{reason: reason})
        {:noreply, socket}
    end
  end

  def handle_in("start_thread", %{"message_id" => message_id}, socket) do
    case get_message_with_thread(message_id) do
      {:ok, message_with_thread} ->
        push(socket, "thread_started", %{
          message_id: message_id,
          thread: message_with_thread.thread
        })
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "thread_error", %{message_id: message_id, reason: reason})
        {:noreply, socket}
    end
  end

  # Handle PubSub events
  @impl true
  def handle_info({:new_message, message}, socket) do
    push(socket, "new_message", %{message: message})
    {:noreply, socket}
  end

  def handle_info({:message_updated, message}, socket) do
    push(socket, "message_updated", %{message: message})
    {:noreply, socket}
  end

  def handle_info({:message_deleted, %{id: message_id}}, socket) do
    push(socket, "message_deleted", %{message_id: message_id})
    {:noreply, socket}
  end

  def handle_info({:typing_start, typing_data}, socket) do
    # Don't broadcast own typing events back
    unless typing_data.user_id == socket.assigns.current_user.id do
      push(socket, "typing_start", typing_data)
    end
    {:noreply, socket}
  end

  def handle_info({:typing_stop, typing_data}, socket) do
    # Don't broadcast own typing events back
    unless typing_data.user_id == socket.assigns.current_user.id do
      push(socket, "typing_stop", typing_data)
    end
    {:noreply, socket}
  end

  def handle_info({:reaction_added, reaction_data}, socket) do
    push(socket, "reaction_added", reaction_data)
    {:noreply, socket}
  end

  def handle_info({:reaction_removed, reaction_data}, socket) do
    push(socket, "reaction_removed", reaction_data)
    {:noreply, socket}
  end

  def handle_info({:message_read, read_data}, socket) do
    push(socket, "message_read", read_data)
    {:noreply, socket}
  end

  def handle_info({:thread_reply, reply_data}, socket) do
    push(socket, "thread_reply", reply_data)
    {:noreply, socket}
  end

  def handle_info({:user_joined, user}, socket) do
    push(socket, "user_joined", %{user: user})
    {:noreply, socket}
  end

  def handle_info({:user_left, %{user_id: user_id}}, socket) do
    push(socket, "user_left", %{user_id: user_id})
    {:noreply, socket}
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    push(socket, "presence_diff", diff)
    {:noreply, socket}
  end

  def handle_info(:typing_timeout, socket) do
    handle_typing_stop(socket)
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    # Clean up typing indicator if active
    if socket.assigns[:typing_timer] do
      handle_typing_stop(socket)
    end
    
    # Unsubscribe from channel events
    channel_id = socket.assigns[:channel_id]
    if channel_id do
      PubSub.unsubscribe_from_channel(channel_id)
    end
    
    :ok
  end

  # Private helper functions
  
  defp handle_thread_reply(socket, content, thread_id) do
    user = socket.assigns.current_user
    channel_id = socket.assigns.channel_id

    case create_thread_reply(thread_id, user.id, content) do
      {:ok, reply} ->
        # Broadcast thread reply
        PubSub.broadcast_thread_reply(thread_id, reply)
        
        push(socket, "thread_reply_sent", %{reply: reply})
        {:noreply, socket}

      {:error, changeset} ->
        push(socket, "thread_reply_error", %{
          thread_id: thread_id,
          errors: format_changeset_errors(changeset)
        })
        {:noreply, socket}
    end
  end

  defp handle_typing_stop(socket) do
    user = socket.assigns.current_user
    channel_id = socket.assigns.channel_id

    # Cancel timer if exists
    if socket.assigns.typing_timer do
      Process.cancel_timer(socket.assigns.typing_timer)
    end

    # Broadcast typing stop
    PubSub.broadcast_typing_stop(channel_id, user)

    socket = assign(socket, :typing_timer, nil)
    {:noreply, socket}
  end

  defp authorize_channel_access(channel_id, user) do
    # Mock authorization - replace with actual channel membership check
    case channel_id do
      "unauthorized" -> {:error, "Access denied"}
      _ -> {:ok, %{id: channel_id, name: "general", type: "public"}}
    end
  end

  defp extract_message_metadata(params) do
    %{
      attachments: params["attachments"] || [],
      mentions: extract_mentions(params["content"] || ""),
      temp_id: params["temp_id"]
    }
  end

  defp extract_mentions(content) do
    # Extract @username mentions
    Regex.scan(~r/@(\w+)/, content)
    |> Enum.map(fn [_, username] -> username end)
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # Mock functions - replace with actual implementations
  defp load_recent_messages(_channel_id, _limit) do
    []
  end

  defp load_messages_before(_channel_id, _before_id, _limit) do
    {:ok, []}
  end

  defp create_message(_channel_id, _user_id, _content, _metadata) do
    {:error, :not_implemented}
  end

  defp edit_message(_message_id, _content, _user_id) do
    {:error, :not_implemented}
  end

  defp delete_message(_message_id, _user_id) do
    {:error, :not_implemented}
  end

  defp add_reaction_to_message(_message_id, _emoji, _user_id) do
    {:error, :not_implemented}
  end

  defp remove_reaction(_reaction_id, _user_id) do
    {:error, :not_implemented}
  end

  defp mark_message_as_read(_message_id, _user_id) do
    {:ok, :marked}
  end

  defp create_thread_reply(_thread_id, _user_id, _content) do
    {:error, :not_implemented}
  end

  defp get_message_with_thread(_message_id) do
    {:error, :not_implemented}
  end
end