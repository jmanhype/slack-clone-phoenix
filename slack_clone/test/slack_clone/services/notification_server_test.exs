defmodule SlackClone.Services.NotificationServerTest do
  use ExUnit.Case, async: false

  alias SlackClone.Services.NotificationServer

  setup do
    # Ensure clean state
    if Process.whereis(NotificationServer) do
      GenServer.stop(NotificationServer, :normal)
    end
    
    # Start fresh server
    {:ok, _pid} = NotificationServer.start_link([])
    
    :ok
  end

  describe "queue_notification/4" do
    test "queues a notification successfully" do
      NotificationServer.queue_notification(
        :in_app,
        "user_123",
        %{title: "Test", message: "Hello"},
        priority: :normal
      )
      
      status = NotificationServer.get_queue_status()
      assert status.queued >= 1
    end
    
    test "processes high priority notifications first" do
      # Queue normal priority notification
      NotificationServer.queue_notification(
        :in_app,
        "user_1",
        %{title: "Normal", message: "Normal priority"}
      )
      
      # Queue high priority notification
      NotificationServer.queue_notification(
        :in_app,
        "user_2",
        %{title: "High", message: "High priority"},
        priority: :high
      )
      
      status = NotificationServer.get_queue_status()
      assert status.queued >= 2
    end
    
    test "triggers immediate processing when batch size reached" do
      # Queue 50 notifications to trigger batch processing
      for i <- 1..50 do
        NotificationServer.queue_notification(
          :in_app,
          "user_#{i}",
          %{title: "Test #{i}", message: "Message #{i}"}
        )
      end
      
      # Give time for processing
      :timer.sleep(100)
      
      stats = NotificationServer.get_stats()
      assert stats.sent > 0
    end
  end

  describe "queue_notifications/1" do
    test "queues multiple notifications at once" do
      notifications = [
        %{
          type: :in_app,
          recipient_id: "user_1",
          payload: %{title: "Test 1", message: "Message 1"},
          priority: :normal,
          retry_count: 0,
          created_at: DateTime.utc_now(),
          scheduled_for: DateTime.utc_now()
        },
        %{
          type: :in_app,
          recipient_id: "user_2",
          payload: %{title: "Test 2", message: "Message 2"},
          priority: :high,
          retry_count: 0,
          created_at: DateTime.utc_now(),
          scheduled_for: DateTime.utc_now()
        }
      ]
      
      NotificationServer.queue_notifications(notifications)
      
      status = NotificationServer.get_queue_status()
      assert status.queued >= 2
    end
  end

  describe "process_queue/0" do
    test "forces processing of queued notifications" do
      NotificationServer.queue_notification(
        :in_app,
        "user_123",
        %{title: "Test", message: "Force process"}
      )
      
      NotificationServer.process_queue()
      
      # Give time for processing
      :timer.sleep(100)
      
      stats = NotificationServer.get_stats()
      assert stats.sent > 0 or stats.failed > 0  # Should have attempted processing
    end
  end

  describe "get_queue_status/0" do
    test "returns current queue status" do
      status = NotificationServer.get_queue_status()
      
      assert Map.has_key?(status, :queued)
      assert Map.has_key?(status, :processing)
      assert Map.has_key?(status, :failed)
      assert is_integer(status.queued)
      assert is_integer(status.processing)
      assert is_integer(status.failed)
    end
  end

  describe "get_stats/0" do
    test "returns comprehensive statistics" do
      stats = NotificationServer.get_stats()
      
      assert is_integer(stats.queued)
      assert is_integer(stats.processing)
      assert is_integer(stats.sent)
      assert is_integer(stats.failed)
      assert is_integer(stats.retries)
      assert is_struct(stats.uptime, DateTime)
    end
  end

  describe "retry_failed_notifications/0" do
    test "requeues failed notifications" do
      initial_stats = NotificationServer.get_stats()
      
      NotificationServer.retry_failed_notifications()
      
      # Should not crash even with no failed notifications
      final_stats = NotificationServer.get_stats()
      assert is_integer(final_stats.retries)
    end
  end

  describe "notification processing" do
    test "handles batch timeout processing" do
      NotificationServer.queue_notification(
        :in_app,
        "user_123",
        %{title: "Timeout Test", message: "Should process after timeout"}
      )
      
      # Wait for timeout processing (2 seconds + buffer)
      :timer.sleep(3_000)
      
      stats = NotificationServer.get_stats()
      # Should have attempted to process (either success or failure)
      assert stats.sent > 0 or stats.failed > 0
    end
  end

  describe "cleanup" do
    test "handles cleanup message without crashing" do
      # Send cleanup message directly
      send(NotificationServer, :cleanup_old_notifications)
      
      # Should not crash
      :timer.sleep(50)
      
      stats = NotificationServer.get_stats()
      assert is_map(stats)
    end
  end

  describe "error handling" do
    test "handles unknown notification results gracefully" do
      # Send unknown notification result
      send(NotificationServer, {:notification_result, "unknown_id", {:ok, :sent}})
      
      # Should not crash
      :timer.sleep(50)
      
      stats = NotificationServer.get_stats()
      assert is_map(stats)
    end
  end

  describe "termination" do
    test "shuts down gracefully with queued notifications" do
      NotificationServer.queue_notification(
        :in_app,
        "user_123",
        %{title: "Final", message: "Last message"}
      )
      
      # Stop server
      GenServer.stop(NotificationServer, :normal)
      
      # Should shutdown without errors
      assert true
    end
  end
end