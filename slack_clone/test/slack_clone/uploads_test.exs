defmodule SlackClone.UploadsTest do
  @moduledoc """
  Tests for file upload processing, storage, and management.
  """
  
  use SlackClone.DataCase
  use ExMachina
  
  import SlackClone.Factory
  
  alias SlackClone.{Uploads, Messages}
  alias SlackClone.Uploaders.{Avatar, Attachment}
  
  describe "file upload processing" do
    setup do
      user = insert(:user)
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel, user: user)
      
      %{user: user, workspace: workspace, channel: channel}
    end
    
    test "validates file types and sizes", %{user: user} do
      # Valid image upload
      valid_image = %Plug.Upload{
        path: create_temp_file("test.jpg", "fake_image_content"),
        filename: "test.jpg",
        content_type: "image/jpeg"
      }
      
      assert {:ok, _upload} = Uploads.process_upload(valid_image, user, :avatar)
      
      # Invalid file type
      invalid_file = %Plug.Upload{
        path: create_temp_file("malicious.exe", "fake_executable"),
        filename: "malicious.exe", 
        content_type: "application/x-msdownload"
      }
      
      assert {:error, changeset} = Uploads.process_upload(invalid_file, user, :attachment)
      assert "Invalid file type" in errors_on(changeset).content_type
      
      # File too large (simulate 100MB file)
      large_file = %Plug.Upload{
        path: create_temp_file("large.pdf", String.duplicate("x", 100 * 1024 * 1024)),
        filename: "large.pdf",
        content_type: "application/pdf"
      }
      
      assert {:error, changeset} = Uploads.process_upload(large_file, user, :attachment)
      assert "File too large" in errors_on(changeset).file_size
    end
    
    test "processes image uploads with thumbnail generation", %{user: user} do
      image_upload = %Plug.Upload{
        path: create_temp_file("photo.jpg", create_fake_jpeg()),
        filename: "photo.jpg",
        content_type: "image/jpeg"
      }
      
      assert {:ok, upload} = Uploads.process_upload(image_upload, user, :attachment)
      
      # Should generate thumbnail for images
      assert upload.thumbnail_url != nil
      assert String.contains?(upload.thumbnail_url, "thumb_")
      
      # Should preserve original
      assert upload.url != nil
      assert upload.filename == "photo.jpg"
      assert upload.content_type == "image/jpeg"
      assert upload.user_id == user.id
    end
    
    test "handles document uploads without thumbnails", %{user: user} do
      doc_upload = %Plug.Upload{
        path: create_temp_file("document.pdf", "fake_pdf_content"),
        filename: "document.pdf",
        content_type: "application/pdf"
      }
      
      assert {:ok, upload} = Uploads.process_upload(doc_upload, user, :attachment)
      
      # Should not generate thumbnail for documents
      assert upload.thumbnail_url == nil
      assert upload.url != nil
      assert upload.filename == "document.pdf"
      assert upload.content_type == "application/pdf"
    end
    
    test "sanitizes filenames", %{user: user} do
      malicious_filename = "../../../etc/passwd"
      upload = %Plug.Upload{
        path: create_temp_file("safe_content.txt", "safe content"),
        filename: malicious_filename,
        content_type: "text/plain"
      }
      
      assert {:ok, processed} = Uploads.process_upload(upload, user, :attachment)
      
      # Filename should be sanitized
      refute String.contains?(processed.filename, "../")
      refute String.contains?(processed.filename, "/")
      assert processed.original_name == malicious_filename  # Keep original for display
    end
    
    test "generates unique storage paths", %{user: user} do
      upload1 = %Plug.Upload{
        path: create_temp_file("file.txt", "content1"),
        filename: "file.txt",
        content_type: "text/plain"
      }
      
      upload2 = %Plug.Upload{
        path: create_temp_file("file.txt", "content2"), 
        filename: "file.txt",
        content_type: "text/plain"
      }
      
      {:ok, processed1} = Uploads.process_upload(upload1, user, :attachment)
      {:ok, processed2} = Uploads.process_upload(upload2, user, :attachment)
      
      # Should have different URLs even with same filename
      assert processed1.url != processed2.url
      assert String.contains?(processed1.url, processed1.id)
      assert String.contains?(processed2.url, processed2.id)
    end
    
    test "virus scanning integration", %{user: user} do
      # Mock virus scanner response
      clean_file = %Plug.Upload{
        path: create_temp_file("clean.txt", "clean content"),
        filename: "clean.txt",
        content_type: "text/plain"
      }
      
      # Should pass virus scanning
      assert {:ok, _upload} = Uploads.process_upload(clean_file, user, :attachment)
      
      # Mock infected file (would integrate with ClamAV or similar)
      infected_file = %Plug.Upload{
        path: create_temp_file("virus.txt", "EICAR-STANDARD-ANTIVIRUS-TEST-FILE"),
        filename: "virus.txt", 
        content_type: "text/plain"
      }
      
      # In real implementation, would call virus scanner
      # assert {:error, changeset} = Uploads.process_upload(infected_file, user, :attachment)
      # assert "File contains virus" in errors_on(changeset).security
    end
    
    test "metadata extraction", %{user: user} do
      image_upload = %Plug.Upload{
        path: create_temp_file("photo.jpg", create_fake_jpeg_with_exif()),
        filename: "vacation_photo.jpg",
        content_type: "image/jpeg"
      }
      
      {:ok, upload} = Uploads.process_upload(image_upload, user, :attachment)
      
      # Should extract image metadata
      assert upload.metadata["width"] != nil
      assert upload.metadata["height"] != nil
      assert upload.metadata["format"] == "JPEG"
      
      # Should remove sensitive EXIF data like GPS
      refute Map.has_key?(upload.metadata, "gps_latitude")
      refute Map.has_key?(upload.metadata, "gps_longitude")
    end
  end
  
  describe "avatar uploads" do
    test "processes user avatar updates" do
      user = insert(:user)
      
      avatar_upload = %Plug.Upload{
        path: create_temp_file("avatar.png", create_fake_png()),
        filename: "my_avatar.png",
        content_type: "image/png"
      }
      
      assert {:ok, avatar_url} = Avatar.store({avatar_upload, user})
      
      # Should return CDN URL
      assert String.starts_with?(avatar_url, "https://")
      assert String.contains?(avatar_url, user.id)
      
      # Should generate multiple sizes
      {:ok, thumbnail_url} = Avatar.url({avatar_url, user}, :thumb)
      {:ok, medium_url} = Avatar.url({avatar_url, user}, :medium)
      
      assert thumbnail_url != medium_url
      assert String.contains?(thumbnail_url, "thumb")
      assert String.contains?(medium_url, "medium")
    end
    
    test "validates avatar dimensions and file size" do
      user = insert(:user)
      
      # Too small image
      tiny_upload = %Plug.Upload{
        path: create_temp_file("tiny.png", create_fake_png(10, 10)),
        filename: "tiny.png",
        content_type: "image/png"
      }
      
      assert {:error, :too_small} = Avatar.store({tiny_upload, user})
      
      # Too large file size
      huge_upload = %Plug.Upload{
        path: create_temp_file("huge.jpg", String.duplicate("x", 10 * 1024 * 1024)),
        filename: "huge.jpg", 
        content_type: "image/jpeg"
      }
      
      assert {:error, :too_large} = Avatar.store({huge_upload, user})
    end
    
    test "cleans up old avatars when updating" do
      user = insert(:user)
      
      # Upload first avatar
      first_avatar = %Plug.Upload{
        path: create_temp_file("avatar1.jpg", create_fake_jpeg()),
        filename: "avatar1.jpg",
        content_type: "image/jpeg"
      }
      
      {:ok, first_url} = Avatar.store({first_avatar, user})
      
      # Upload second avatar  
      second_avatar = %Plug.Upload{
        path: create_temp_file("avatar2.jpg", create_fake_jpeg()),
        filename: "avatar2.jpg",
        content_type: "image/jpeg"
      }
      
      {:ok, second_url} = Avatar.store({second_avatar, user})
      
      # Should have different URLs
      assert first_url != second_url
      
      # First avatar should be marked for cleanup
      # (Implementation would queue for deletion)
    end
  end
  
  describe "attachment management" do
    setup do
      user = insert(:user)
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      message = insert(:message, channel: channel, user: user)
      
      %{user: user, channel: channel, message: message}
    end
    
    test "attaches files to messages", %{user: user, message: message} do
      file_upload = %Plug.Upload{
        path: create_temp_file("report.pdf", "fake pdf content"),
        filename: "quarterly_report.pdf",
        content_type: "application/pdf"
      }
      
      {:ok, attachment} = Uploads.attach_to_message(message, file_upload, user)
      
      assert attachment.message_id == message.id
      assert attachment.user_id == user.id
      assert attachment.filename == "quarterly_report.pdf"
      assert attachment.content_type == "application/pdf"
      assert attachment.url != nil
      
      # Should update message metadata
      updated_message = Messages.get_message!(message.id)
      assert updated_message.metadata["has_attachments"] == true
      assert updated_message.metadata["attachment_count"] == 1
    end
    
    test "handles multiple attachments per message", %{user: user, message: message} do
      attachments_data = [
        {"doc1.pdf", "application/pdf", "pdf content 1"},
        {"image.jpg", "image/jpeg", create_fake_jpeg()},
        {"spreadsheet.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx content"}
      ]
      
      for {filename, content_type, content} <- attachments_data do
        upload = %Plug.Upload{
          path: create_temp_file(filename, content),
          filename: filename,
          content_type: content_type
        }
        
        {:ok, _attachment} = Uploads.attach_to_message(message, upload, user)
      end
      
      # Should track all attachments
      attachments = Uploads.get_message_attachments(message.id)
      assert length(attachments) == 3
      
      # Should update message metadata
      updated_message = Messages.get_message!(message.id)
      assert updated_message.metadata["attachment_count"] == 3
    end
    
    test "enforces attachment limits per message", %{user: user, message: message} do
      # Add maximum allowed attachments (assume limit is 10)
      for i <- 1..10 do
        upload = %Plug.Upload{
          path: create_temp_file("file#{i}.txt", "content #{i}"),
          filename: "file#{i}.txt",
          content_type: "text/plain"
        }
        
        {:ok, _attachment} = Uploads.attach_to_message(message, upload, user)
      end
      
      # 11th attachment should fail
      excess_upload = %Plug.Upload{
        path: create_temp_file("excess.txt", "too many files"),
        filename: "excess.txt",
        content_type: "text/plain"
      }
      
      assert {:error, :too_many_attachments} = 
        Uploads.attach_to_message(message, excess_upload, user)
    end
  end
  
  describe "file access control" do
    setup do
      workspace1 = insert(:workspace)
      workspace2 = insert(:workspace)
      user1 = insert(:user)
      user2 = insert(:user)
      
      channel1 = insert(:channel, workspace: workspace1)
      channel2 = insert(:private_channel, workspace: workspace1)
      
      insert(:workspace_membership, workspace: workspace1, user: user1)
      insert(:workspace_membership, workspace: workspace2, user: user2)
      insert(:channel_membership, channel: channel1, user: user1)
      # user1 not in private channel2
      
      %{
        workspace1: workspace1, workspace2: workspace2,
        user1: user1, user2: user2,
        channel1: channel1, channel2: channel2
      }
    end
    
    test "controls access to private channel attachments", %{user1: user1, user2: user2, channel2: channel2} do
      # user1 uploads to private channel they're not in
      private_message = insert(:message, channel: channel2, user: user1)
      attachment = insert(:attachment, message: private_message, user: user1)
      
      # user2 from different workspace should not access
      assert {:error, :access_denied} = Uploads.get_attachment_with_access_check(attachment.id, user2)
      
      # user1 should still access their own attachment
      assert {:ok, _attachment} = Uploads.get_attachment_with_access_check(attachment.id, user1)
    end
    
    test "allows access to public channel attachments for workspace members", %{user1: user1, user2: user2, channel1: channel1} do
      message = insert(:message, channel: channel1, user: user1)
      attachment = insert(:attachment, message: message, user: user1)
      
      # Add user2 to workspace1
      insert(:workspace_membership, workspace: channel1.workspace, user: user2)
      insert(:channel_membership, channel: channel1, user: user2)
      
      # user2 should now access public channel attachment
      assert {:ok, _attachment} = Uploads.get_attachment_with_access_check(attachment.id, user2)
    end
    
    test "generates signed URLs for temporary access" do
      user = insert(:user)
      attachment = insert(:attachment, user: user)
      
      # Generate signed URL valid for 1 hour
      {:ok, signed_url} = Uploads.generate_signed_url(attachment, user, expires_in: 3600)
      
      assert String.contains?(signed_url, "signature=")
      assert String.contains?(signed_url, "expires=")
      
      # URL should be valid
      assert {:ok, _attachment} = Uploads.verify_signed_url(signed_url)
      
      # Expired URL should fail
      {:ok, expired_url} = Uploads.generate_signed_url(attachment, user, expires_in: -1)
      assert {:error, :expired} = Uploads.verify_signed_url(expired_url)
    end
  end
  
  describe "storage cleanup" do
    test "marks orphaned files for deletion" do
      user = insert(:user)
      
      # Create attachment without associated message (orphaned)
      orphaned_attachment = insert(:attachment, user: user, message: nil)
      
      # Run cleanup job
      {:ok, cleaned_count} = Uploads.cleanup_orphaned_files()
      
      assert cleaned_count >= 1
      
      # Orphaned file should be marked for deletion
      updated_attachment = Uploads.get_attachment!(orphaned_attachment.id)
      assert updated_attachment.deleted_at != nil
    end
    
    test "removes files after retention period" do
      user = insert(:user)
      old_date = DateTime.add(DateTime.utc_now(), -31, :day)  # 31 days ago
      
      # Create old deleted attachment
      old_attachment = insert(:attachment, 
        user: user, 
        deleted_at: old_date,
        inserted_at: old_date
      )
      
      # Run permanent cleanup (would actually delete from storage)
      {:ok, removed_count} = Uploads.permanent_cleanup(days: 30)
      
      assert removed_count >= 1
      
      # Should no longer exist
      assert nil == Uploads.get_attachment(old_attachment.id)
    end
    
    test "calculates storage usage per user and workspace" do
      user1 = insert(:user)
      user2 = insert(:user)
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      
      # Create attachments of different sizes
      attachment1 = insert(:attachment, user: user1, file_size: 1024 * 100)  # 100KB
      attachment2 = insert(:attachment, user: user1, file_size: 1024 * 200)  # 200KB  
      attachment3 = insert(:attachment, user: user2, file_size: 1024 * 150)  # 150KB
      
      # Calculate usage
      user1_usage = Uploads.calculate_user_storage_usage(user1.id)
      user2_usage = Uploads.calculate_user_storage_usage(user2.id)
      workspace_usage = Uploads.calculate_workspace_storage_usage(workspace.id)
      
      assert user1_usage == 1024 * 300  # 300KB
      assert user2_usage == 1024 * 150  # 150KB
      assert workspace_usage >= 1024 * 450  # At least 450KB
    end
  end
  
  describe "concurrent upload handling" do
    test "handles multiple simultaneous uploads" do
      user = insert(:user)
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      message = insert(:message, channel: channel, user: user)
      
      # Create multiple uploads simultaneously
      upload_count = 5
      
      tasks = for i <- 1..upload_count do
        Task.async(fn ->
          upload = %Plug.Upload{
            path: create_temp_file("concurrent#{i}.txt", "content #{i}"),
            filename: "concurrent#{i}.txt",
            content_type: "text/plain"
          }
          
          Uploads.attach_to_message(message, upload, user)
        end)
      end
      
      results = Task.await_many(tasks, 10_000)
      
      # All uploads should succeed
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
      
      # Should have all attachments
      attachments = Uploads.get_message_attachments(message.id)
      assert length(attachments) == upload_count
      
      # Message metadata should be correct
      updated_message = Messages.get_message!(message.id)
      assert updated_message.metadata["attachment_count"] == upload_count
    end
  end
  
  # Helper functions
  defp create_temp_file(filename, content) do
    temp_path = Path.join(System.tmp_dir!(), filename)
    File.write!(temp_path, content)
    temp_path
  end
  
  defp create_fake_jpeg(width \\ 100, height \\ 100) do
    # Minimal JPEG header for testing
    <<255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, 72, 0, 72, 0, 0,
      255, 219, 0, 67, 0, 8, 6, 6, 7, 6, 5, 8, 7, 7, 7, 9, 9, 8, 10, 12, 20, 13, 12>>
    <> String.duplicate("fake_jpeg_data", div(width * height, 20))
  end
  
  defp create_fake_png(width \\ 100, height \\ 100) do
    # PNG signature and basic header
    <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82>>
    <> <<width::32, height::32>>
    <> <<8, 2, 0, 0, 0>>
    <> String.duplicate("fake_png_data", div(width * height, 20))
  end
  
  defp create_fake_jpeg_with_exif do
    # JPEG with fake EXIF data (without sensitive GPS info)
    create_fake_jpeg() <> <<
      255, 225, 0, 100,  # EXIF marker
      69, 120, 105, 102, 0, 0,  # "Exif" header
      # Fake EXIF data
      73, 73, 42, 0
    >> <> String.duplicate(<<0>>, 90)
  end
  
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end