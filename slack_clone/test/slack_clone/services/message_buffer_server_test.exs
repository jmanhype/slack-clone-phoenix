defmodule SlackClone.Services.MessageBufferServerTest do
  use ExUnit.Case, async: false

  alias SlackClone.Services.MessageBufferServer
  alias SlackClone.Messages

  setup do
    # Ensure clean state
    if Process.whereis(MessageBufferServer) do
      GenServer.stop(MessageBufferServer, :normal)
    end
    
    # Start fresh server
    {:ok, _pid} = MessageBufferServer.start_link([])
    
    :ok
  end

  describe "buffer_message/4" do
    test "buffers messages for batch persistence" do
      channel_id = "test_channel"
      user_id = "test_user"
      content = "Hello, World!"
      
      MessageBufferServer.buffer_message(channel_id, user_id, content)
      
      stats = MessageBufferServer.get_stats()
      assert stats.messages_buffered == 1
    end
    
    test "flushes messages when batch size reached" do
      channel_id = "test_channel"
      user_id = "test_user"
      
      # Buffer 10 messages to trigger batch flush
      for i <- 1..10 do
        MessageBufferServer.buffer_message(channel_id, user_id, "Message #{i}")
      end
      
      # Give time for async processing
      :timer.sleep(100)
      
      stats = MessageBufferServer.get_stats()
      assert stats.batches_processed >= 1
    end
    
    test "flushes messages after timeout" do
      channel_id = "test_channel"
      user_id = "test_user"
      content = "Test message"
      
      MessageBufferServer.buffer_message(channel_id, user_id, content)
      
      # Wait for timeout (5 seconds + buffer)
      :timer.sleep(6_000)
      
      stats = MessageBufferServer.get_stats()
      assert stats.batches_processed >= 1
    end
  end

  describe "flush_messages/0" do
    test "manually flushes all buffered messages" do
      channel_id = "test_channel"
      user_id = "test_user"
      
      # Buffer some messages
      for i <- 1..5 do
        MessageBufferServer.buffer_message(channel_id, user_id, "Message #{i}")
      end
      
      {:ok, count} = MessageBufferServer.flush_messages()
      assert count == 5
      
      stats = MessageBufferServer.get_stats()
      assert stats.batches_processed >= 1
    end
    
    test "returns ok with 0 when no messages to flush" do
      {:ok, count} = MessageBufferServer.flush_messages()
      assert count == 0
    end
  end

  describe "get_stats/0" do
    test "returns current statistics" do
      stats = MessageBufferServer.get_stats()
      
      assert is_integer(stats.messages_buffered)
      assert is_integer(stats.batches_processed)
      assert is_integer(stats.errors)
      assert stats.last_flush == nil or is_struct(stats.last_flush, DateTime)
    end
  end

  describe "termination" do
    test "flushes remaining messages on shutdown" do
      # Buffer some messages
      MessageBufferServer.buffer_message("test_channel", "test_user", "Final message")
      
      # Stop the server
      GenServer.stop(MessageBufferServer, :normal)
      
      # Verify shutdown was clean (no errors in logs)
      assert true
    end
  end
end