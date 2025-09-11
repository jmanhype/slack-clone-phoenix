defmodule SlackClone.Services.MessageBufferServer do
  @moduledoc """
  GenServer for batching message persistence to optimize database writes.
  Batches messages every 5 seconds or when 10 messages accumulate.
  """

  use GenServer
  require Logger

  alias SlackClone.Messages
  alias SlackClone.Messages.Message

  @batch_size 10
  @batch_timeout 5_000

  defstruct [:buffer, :timer_ref, :stats]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Buffer a message for batch persistence
  """
  def buffer_message(channel_id, user_id, content, metadata \\ %{}) do
    message_data = %{
      channel_id: channel_id,
      user_id: user_id,
      content: content,
      metadata: metadata,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    
    GenServer.cast(__MODULE__, {:buffer_message, message_data})
  end

  @doc """
  Force flush all buffered messages immediately
  """
  def flush_messages do
    GenServer.call(__MODULE__, :flush_messages)
  end

  @doc """
  Get buffer statistics
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting MessageBufferServer")
    
    state = %__MODULE__{
      buffer: [],
      timer_ref: nil,
      stats: %{
        messages_buffered: 0,
        batches_processed: 0,
        last_flush: nil,
        errors: 0
      }
    }
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:buffer_message, message_data}, state) do
    new_buffer = [message_data | state.buffer]
    buffer_size = length(new_buffer)
    
    Logger.debug("Buffered message, total: #{buffer_size}")
    
    # Cancel existing timer if we're about to flush
    new_timer_ref = if buffer_size >= @batch_size do
      cancel_timer(state.timer_ref)
      send(self(), :flush_buffer)
      nil
    else
      # Start timer if this is the first message
      if state.timer_ref == nil do
        Process.send_after(self(), :flush_buffer, @batch_timeout)
      else
        state.timer_ref
      end
    end
    
    new_stats = %{state.stats | messages_buffered: state.stats.messages_buffered + 1}
    
    {:noreply, %{state | buffer: new_buffer, timer_ref: new_timer_ref, stats: new_stats}}
  end

  @impl true
  def handle_call(:flush_messages, _from, state) do
    {result, new_state} = do_flush_buffer(state)
    {:reply, result, new_state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info(:flush_buffer, state) do
    {_result, new_state} = do_flush_buffer(state)
    {:noreply, new_state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("MessageBufferServer terminating: #{inspect(reason)}")
    
    # Flush any remaining messages
    if length(state.buffer) > 0 do
      Logger.info("Flushing #{length(state.buffer)} remaining messages on shutdown")
      do_flush_buffer(state)
    end
    
    :ok
  end

  ## Private Functions

  defp do_flush_buffer(%{buffer: []} = state) do
    {{:ok, 0}, state}
  end

  defp do_flush_buffer(state) do
    buffer_size = length(state.buffer)
    Logger.info("Flushing #{buffer_size} messages to database")
    
    try do
      # Insert messages in batch
      {count, _} = Messages.insert_messages_batch(Enum.reverse(state.buffer))
      
      Logger.info("Successfully persisted #{count} messages")
      
      # Broadcast successful flush
      Phoenix.PubSub.broadcast(
        SlackClone.PubSub,
        "message_buffer:stats",
        {:messages_flushed, count}
      )
      
      new_stats = %{
        state.stats |
        batches_processed: state.stats.batches_processed + 1,
        last_flush: DateTime.utc_now()
      }
      
      new_state = %{
        state |
        buffer: [],
        timer_ref: nil,
        stats: new_stats
      }
      
      {{:ok, count}, new_state}
      
    rescue
      error ->
        Logger.error("Failed to flush messages: #{inspect(error)}")
        
        new_stats = %{state.stats | errors: state.stats.errors + 1}
        
        # Keep messages in buffer and retry later
        timer_ref = Process.send_after(self(), :flush_buffer, @batch_timeout)
        
        new_state = %{
          state |
          timer_ref: timer_ref,
          stats: new_stats
        }
        
        {{:error, error}, new_state}
    end
  end

  defp cancel_timer(nil), do: nil
  defp cancel_timer(timer_ref) do
    Process.cancel_timer(timer_ref)
    nil
  end
end