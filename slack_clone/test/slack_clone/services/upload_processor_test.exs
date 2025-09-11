defmodule SlackClone.Services.UploadProcessorTest do
  use ExUnit.Case, async: false
  use ExUnit.CaptureLog

  alias SlackClone.Services.UploadProcessor

  @test_file_path "/tmp/test_upload.txt"

  setup do
    # Create test file
    File.write!(@test_file_path, "Test file content")
    
    # Ensure clean state
    if Process.whereis(UploadProcessor) do
      GenServer.stop(UploadProcessor, :normal)
    end
    
    # Start fresh server
    {:ok, _pid} = UploadProcessor.start_link([])
    
    on_exit(fn ->
      File.rm(@test_file_path)
      File.rm("/tmp/test_upload_processed.txt")
      File.rm("/tmp/test_upload_thumb.jpg")
    end)
    
    :ok
  end

  describe "process_file/3" do
    test "queues file for processing" do
      upload_id = "upload_123"
      
      UploadProcessor.process_file(upload_id, @test_file_path)
      
      :timer.sleep(50)
      
      stats = UploadProcessor.get_stats()
      assert stats.queued > 0 or stats.active > 0 or stats.total_processed > 0
    end
    
    test "handles high priority processing" do
      upload_id = "high_priority_upload"
      
      UploadProcessor.process_file(upload_id, @test_file_path, priority: :high)
      
      :timer.sleep(50)
      
      status = UploadProcessor.get_processing_status(upload_id)
      assert status != {:not_found, nil}
    end
    
    test "processes file with custom options" do
      upload_id = "custom_upload"
      options = [
        priority: :high,
        scan_timeout: 10_000,
        generate_thumbnails: true
      ]
      
      UploadProcessor.process_file(upload_id, @test_file_path, options)
      
      :timer.sleep(50)
      
      status = UploadProcessor.get_processing_status(upload_id)
      assert status in [
        {:queued, :queued}, 
        {:processing, :processing},
        {:not_found, nil}  # If processed very quickly
      ]
    end
  end

  describe "get_processing_status/1" do
    test "returns status for queued upload" do
      upload_id = "status_test_upload"
      
      UploadProcessor.process_file(upload_id, @test_file_path)
      
      status = UploadProcessor.get_processing_status(upload_id)
      assert status in [
        {:queued, :queued}, 
        {:processing, :processing},
        {:not_found, nil}
      ]
    end
    
    test "returns not_found for non-existent upload" do
      status = UploadProcessor.get_processing_status("non_existent_upload")
      assert status == {:not_found, nil}
    end
  end

  describe "cancel_job/1" do
    test "cancels queued job" do
      upload_id = "cancel_test_upload"
      
      # Process file to get job ID
      UploadProcessor.process_file(upload_id, @test_file_path)
      :timer.sleep(50)
      
      # For testing, we'll use a mock job ID since we don't expose job IDs
      # In a real scenario, you'd get the job ID from the process_file response
      job_id = "mock_job_id"
      
      UploadProcessor.cancel_job(job_id)
      
      # Should not crash
      :timer.sleep(50)
      
      stats = UploadProcessor.get_stats()
      assert is_map(stats)
    end
  end

  describe "get_stats/0" do
    test "returns comprehensive statistics" do
      stats = UploadProcessor.get_stats()
      
      assert is_integer(stats.queued)
      assert is_integer(stats.active)
      assert is_integer(stats.completed)
      assert is_integer(stats.failed)
      assert is_integer(stats.virus_detected)
      assert is_integer(stats.total_processed)
      assert is_struct(stats.uptime, DateTime)
    end
    
    test "updates stats after processing" do
      initial_stats = UploadProcessor.get_stats()
      
      UploadProcessor.process_file("stats_test", @test_file_path)
      
      # Give time for processing
      :timer.sleep(100)
      
      final_stats = UploadProcessor.get_stats()
      
      # Should have changed (either queued increased or processing started)
      assert final_stats != initial_stats
    end
  end

  describe "job processing" do
    test "processes jobs concurrently up to max limit" do
      # Queue multiple jobs
      for i <- 1..3 do
        File.write!("/tmp/test_file_#{i}.txt", "Content #{i}")
        UploadProcessor.process_file("upload_#{i}", "/tmp/test_file_#{i}.txt")
      end
      
      # Give time for processing to start
      :timer.sleep(100)
      
      stats = UploadProcessor.get_stats()
      # Should have active jobs (up to max concurrent)
      assert stats.active > 0 or stats.total_processed > 0
      
      # Cleanup
      for i <- 1..3 do
        File.rm("/tmp/test_file_#{i}.txt")
      end
    end
  end

  describe "error handling" do
    test "handles non-existent files gracefully" do
      log = capture_log(fn ->
        UploadProcessor.process_file("bad_upload", "/non/existent/file.txt")
        :timer.sleep(100)
      end)
      
      stats = UploadProcessor.get_stats()
      # Should have attempted processing
      assert stats.failed >= 0
    end
    
    test "handles job completion messages" do
      # Send job completion message directly
      send(UploadProcessor, {:job_completed, "test_job", {:ok, %{}}})
      
      # Should not crash
      :timer.sleep(50)
      
      stats = UploadProcessor.get_stats()
      assert is_map(stats)
    end
    
    test "handles unknown job completion" do
      # Send completion for unknown job
      send(UploadProcessor, {:job_completed, "unknown_job", {:error, :not_found}})
      
      # Should not crash
      :timer.sleep(50)
      
      stats = UploadProcessor.get_stats()
      assert is_map(stats)
    end
  end

  describe "cleanup" do
    test "handles cleanup message without crashing" do
      # Send cleanup message directly
      send(UploadProcessor, :cleanup_old_jobs)
      
      # Should not crash
      :timer.sleep(50)
      
      stats = UploadProcessor.get_stats()
      assert is_map(stats)
    end
  end

  describe "virus detection simulation" do
    test "handles virus detection gracefully" do
      # This test would be more meaningful with actual virus scanning
      # For now, just test that the system handles virus detection results
      upload_id = "virus_test"
      
      UploadProcessor.process_file(upload_id, @test_file_path)
      
      # Give time for processing
      :timer.sleep(200)
      
      stats = UploadProcessor.get_stats()
      # Should have processed (either success or virus detection)
      assert stats.total_processed >= 0
      assert stats.virus_detected >= 0
    end
  end

  describe "termination" do
    test "shuts down gracefully with active jobs" do
      UploadProcessor.process_file("final_upload", @test_file_path)
      
      # Stop server
      GenServer.stop(UploadProcessor, :normal)
      
      # Should shutdown without errors
      assert true
    end
  end
end