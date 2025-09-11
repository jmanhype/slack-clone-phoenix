defmodule SlackClone.Services.UploadProcessor do
  @moduledoc """
  GenServer for background file processing with virus scanning.
  Handles file uploads, image processing, virus scanning, and storage.
  """

  use GenServer
  require Logger

  alias SlackClone.Uploads
  alias SlackClone.Uploads.Upload
  alias Phoenix.PubSub

  @max_concurrent_jobs 5
  @scan_timeout 30_000
  @image_processing_timeout 15_000
  @cleanup_interval 3_600_000  # 1 hour

  defstruct [
    :active_jobs,
    :job_queue,
    :job_supervisors,
    :stats
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue a file for processing
  """
  def process_file(upload_id, file_path, options \\ []) do
    job = %{
      id: generate_job_id(),
      upload_id: upload_id,
      file_path: file_path,
      options: options,
      status: :queued,
      created_at: DateTime.utc_now(),
      priority: Keyword.get(options, :priority, :normal)
    }
    
    GenServer.cast(__MODULE__, {:queue_job, job})
  end

  @doc """
  Get processing status for an upload
  """
  def get_processing_status(upload_id) do
    GenServer.call(__MODULE__, {:get_status, upload_id})
  end

  @doc """
  Get queue statistics
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Cancel a processing job
  """
  def cancel_job(job_id) do
    GenServer.cast(__MODULE__, {:cancel_job, job_id})
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting UploadProcessor")
    
    # Schedule periodic cleanup
    :timer.send_interval(@cleanup_interval, :cleanup_old_jobs)
    
    state = %__MODULE__{
      active_jobs: %{},
      job_queue: :queue.new(),
      job_supervisors: %{},
      stats: %{
        queued: 0,
        active: 0,
        completed: 0,
        failed: 0,
        virus_detected: 0,
        total_processed: 0,
        uptime: DateTime.utc_now()
      }
    }
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:queue_job, job}, state) do
    Logger.info("Queuing file processing job for upload #{job.upload_id}")
    
    # Add to queue based on priority
    new_queue = case job.priority do
      :high -> :queue.in_r(job, state.job_queue)
      _ -> :queue.in(job, state.job_queue)
    end
    
    new_stats = %{state.stats | queued: :queue.len(new_queue)}
    
    # Try to start processing if we have capacity
    new_state = %{state | job_queue: new_queue, stats: new_stats}
    |> try_start_next_job()
    
    {:noreply, new_state}
  end

  def handle_cast({:cancel_job, job_id}, state) do
    Logger.info("Cancelling job #{job_id}")
    
    # Remove from queue if present
    new_queue = remove_job_from_queue(state.job_queue, job_id)
    
    # Stop active job if running
    new_active_jobs = case Map.get(state.active_jobs, job_id) do
      nil -> state.active_jobs
      job ->
        stop_job_process(job)
        Map.delete(state.active_jobs, job_id)
    end
    
    new_stats = %{
      state.stats |
      queued: :queue.len(new_queue),
      active: map_size(new_active_jobs)
    }
    
    new_state = %{state |
      job_queue: new_queue,
      active_jobs: new_active_jobs,
      stats: new_stats
    }
    |> try_start_next_job()
    
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_status, upload_id}, _from, state) do
    # Check active jobs
    active_status = 
      state.active_jobs
      |> Enum.find_value(fn {_job_id, job} ->
        if job.upload_id == upload_id, do: {:processing, job.status}
      end)
    
    if active_status do
      {:reply, active_status, state}
    else
      # Check queue
      queue_status = 
        :queue.to_list(state.job_queue)
        |> Enum.find_value(fn job ->
          if job.upload_id == upload_id, do: {:queued, job.status}
        end)
      
      {:reply, queue_status || {:not_found, nil}, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info({:job_completed, job_id, result}, state) do
    Logger.info("Job #{job_id} completed with result: #{inspect(result)}")
    
    case Map.pop(state.active_jobs, job_id) do
      {nil, _} ->
        # Job not found (shouldn't happen)
        {:noreply, state}
        
      {job, new_active_jobs} ->
        # Update upload status based on result
        update_upload_status(job.upload_id, result)
        
        # Broadcast completion
        broadcast_job_completed(job, result)
        
        # Update stats
        new_stats = case result do
          {:ok, _} -> %{state.stats | 
            completed: state.stats.completed + 1,
            total_processed: state.stats.total_processed + 1
          }
          {:error, :virus_detected} -> %{state.stats | 
            virus_detected: state.stats.virus_detected + 1,
            failed: state.stats.failed + 1,
            total_processed: state.stats.total_processed + 1
          }
          {:error, _} -> %{state.stats | 
            failed: state.stats.failed + 1,
            total_processed: state.stats.total_processed + 1
          }
        end
        
        new_stats = %{new_stats | active: map_size(new_active_jobs)}
        
        # Try to start next job
        new_state = %{state |
          active_jobs: new_active_jobs,
          stats: new_stats
        }
        |> try_start_next_job()
        
        {:noreply, new_state}
    end
  end

  def handle_info(:cleanup_old_jobs, state) do
    Logger.debug("Running job cleanup")
    
    # This would clean up any stale job data, temp files, etc.
    # For now, just log
    Logger.debug("Job cleanup completed")
    
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("UploadProcessor terminating: #{inspect(reason)}")
    
    # Stop all active job processes
    state.active_jobs
    |> Enum.each(fn {_job_id, job} ->
      stop_job_process(job)
    end)
    
    # Log remaining jobs
    active_count = map_size(state.active_jobs)
    queued_count = :queue.len(state.job_queue)
    
    if active_count + queued_count > 0 do
      Logger.warn("Shutting down with #{active_count} active and #{queued_count} queued jobs")
    end
    
    :ok
  end

  ## Private Functions

  defp try_start_next_job(state) do
    if map_size(state.active_jobs) < @max_concurrent_jobs and not :queue.is_empty(state.job_queue) do
      case :queue.out(state.job_queue) do
        {:empty, _} -> state
        {{:value, job}, new_queue} ->
          case start_job_process(job) do
            {:ok, job_process} ->
              updated_job = %{job | 
                status: :processing, 
                started_at: DateTime.utc_now(),
                process: job_process
              }
              
              new_active_jobs = Map.put(state.active_jobs, job.id, updated_job)
              
              new_stats = %{
                state.stats |
                queued: :queue.len(new_queue),
                active: map_size(new_active_jobs)
              }
              
              Logger.info("Started processing job #{job.id} for upload #{job.upload_id}")
              
              %{state |
                job_queue: new_queue,
                active_jobs: new_active_jobs,
                stats: new_stats
              }
              |> try_start_next_job()  # Try to start another job
              
            {:error, reason} ->
              Logger.error("Failed to start job #{job.id}: #{inspect(reason)}")
              
              # Move job back to end of queue or mark as failed
              retry_job = %{job | 
                status: :failed,
                error: reason,
                retry_count: (job.retry_count || 0) + 1
              }
              
              if retry_job.retry_count < 3 do
                new_queue = :queue.in(retry_job, new_queue)
                %{state | job_queue: new_queue}
              else
                # Give up on this job
                update_upload_status(job.upload_id, {:error, reason})
                broadcast_job_completed(job, {:error, reason})
                
                new_stats = %{state.stats | 
                  failed: state.stats.failed + 1,
                  queued: :queue.len(new_queue)
                }
                
                %{state | job_queue: new_queue, stats: new_stats}
              end
          end
      end
    else
      state
    end
  end

  defp start_job_process(job) do
    parent = self()
    
    pid = spawn_link(fn ->
      process_file_job(parent, job)
    end)
    
    {:ok, pid}
  end

  defp stop_job_process(job) do
    if Map.has_key?(job, :process) and is_pid(job.process) do
      Process.exit(job.process, :kill)
    end
  end

  defp process_file_job(parent, job) do
    Logger.info("Processing file: #{job.file_path}")
    
    try do
      result = 
        job
        |> scan_for_viruses()
        |> process_file_content()
        |> generate_thumbnails()
        |> store_processed_file()
      
      send(parent, {:job_completed, job.id, result})
    rescue
      error ->
        Logger.error("Job #{job.id} failed: #{inspect(error)}")
        send(parent, {:job_completed, job.id, {:error, error}})
    end
  end

  defp scan_for_viruses(job) do
    Logger.debug("Scanning file for viruses: #{job.file_path}")
    
    # Simulate virus scanning (replace with actual scanner)
    case simulate_virus_scan(job.file_path) do
      {:ok, :clean} ->
        Logger.debug("File clean: #{job.file_path}")
        {:ok, job}
        
      {:error, :virus_detected} ->
        Logger.warn("Virus detected in file: #{job.file_path}")
        # Quarantine or delete the file
        File.rm(job.file_path)
        {:error, :virus_detected}
        
      {:error, reason} ->
        Logger.error("Virus scan failed: #{inspect(reason)}")
        {:error, {:scan_failed, reason}}
    end
  end

  defp process_file_content({:ok, job}) do
    Logger.debug("Processing file content: #{job.file_path}")
    
    case get_file_type(job.file_path) do
      :image -> process_image(job)
      :document -> process_document(job)
      :video -> process_video(job)
      _ -> {:ok, job}
    end
  end
  
  defp process_file_content(error), do: error

  defp process_image(job) do
    Logger.debug("Processing image: #{job.file_path}")
    
    try do
      # Simulate image processing (resize, optimize, etc.)
      processed_path = String.replace(job.file_path, ~r/\.[^.]+$/, "_processed\\0")
      
      # This would do actual image processing
      :timer.sleep(1000)  # Simulate processing time
      
      File.cp!(job.file_path, processed_path)
      
      {:ok, %{job | processed_path: processed_path}}
    rescue
      error ->
        {:error, {:image_processing_failed, error}}
    end
  end

  defp process_document(job) do
    Logger.debug("Processing document: #{job.file_path}")
    
    # Extract text, generate previews, etc.
    {:ok, job}
  end

  defp process_video(job) do
    Logger.debug("Processing video: #{job.file_path}")
    
    # Generate thumbnails, compress, etc.
    {:ok, job}
  end

  defp generate_thumbnails({:ok, job}) do
    Logger.debug("Generating thumbnails for: #{job.file_path}")
    
    case get_file_type(job.file_path) do
      type when type in [:image, :video] ->
        # Generate thumbnails
        thumbnail_path = String.replace(job.file_path, ~r/\.[^.]+$/, "_thumb.jpg")
        
        # Simulate thumbnail generation
        :timer.sleep(500)
        File.touch!(thumbnail_path)
        
        {:ok, %{job | thumbnail_path: thumbnail_path}}
        
      _ ->
        {:ok, job}
    end
  end
  
  defp generate_thumbnails(error), do: error

  defp store_processed_file({:ok, job}) do
    Logger.debug("Storing processed file: #{job.file_path}")
    
    # Move files to permanent storage (S3, etc.)
    # For now, just simulate
    :timer.sleep(500)
    
    processed_info = %{
      original_path: job.file_path,
      processed_path: Map.get(job, :processed_path),
      thumbnail_path: Map.get(job, :thumbnail_path),
      file_size: get_file_size(job.file_path),
      content_type: get_content_type(job.file_path),
      processed_at: DateTime.utc_now()
    }
    
    {:ok, processed_info}
  end
  
  defp store_processed_file(error), do: error

  defp simulate_virus_scan(file_path) do
    # Simulate virus scanning delay
    :timer.sleep(100)
    
    # Randomly detect "virus" for testing (very small chance)
    if :rand.uniform(1000) == 1 do
      {:error, :virus_detected}
    else
      {:ok, :clean}
    end
  end

  defp get_file_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ext when ext in [".jpg", ".jpeg", ".png", ".gif", ".webp"] -> :image
      ext when ext in [".pdf", ".doc", ".docx", ".txt"] -> :document
      ext when ext in [".mp4", ".mov", ".avi", ".mkv"] -> :video
      ext when ext in [".mp3", ".wav", ".flac"] -> :audio
      _ -> :unknown
    end
  end

  defp get_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end

  defp get_content_type(file_path) do
    case get_file_type(file_path) do
      :image -> "image/" <> (Path.extname(file_path) |> String.trim_leading("."))
      :document -> "application/octet-stream"
      :video -> "video/" <> (Path.extname(file_path) |> String.trim_leading("."))
      :audio -> "audio/" <> (Path.extname(file_path) |> String.trim_leading("."))
      _ -> "application/octet-stream"
    end
  end

  defp update_upload_status(upload_id, result) do
    case result do
      {:ok, processed_info} ->
        Uploads.update_upload_status(upload_id, :processed, processed_info)
        
      {:error, :virus_detected} ->
        Uploads.update_upload_status(upload_id, :virus_detected, %{})
        
      {:error, reason} ->
        Uploads.update_upload_status(upload_id, :failed, %{error: reason})
    end
  end

  defp broadcast_job_completed(job, result) do
    PubSub.broadcast(
      SlackClone.PubSub,
      "upload:#{job.upload_id}",
      {:processing_completed, job.upload_id, result}
    )
    
    PubSub.broadcast(
      SlackClone.PubSub,
      "upload_processor:jobs",
      {:job_completed, job.id, result}
    )
  end

  defp remove_job_from_queue(queue, job_id) do
    queue
    |> :queue.to_list()
    |> Enum.reject(&(&1.id == job_id))
    |> :queue.from_list()
  end

  defp generate_job_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end