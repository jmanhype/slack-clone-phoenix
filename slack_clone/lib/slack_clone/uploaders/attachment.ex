defmodule SlackClone.Uploaders.Attachment do
  @moduledoc """
  Attachment uploader using Waffle for handling file attachments in messages.
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def acl(:original, _), do: :public_read

  # Override the persisted filenames.
  def filename(version, {file, scope}) do
    file_name = Path.basename(file.file_name, Path.extname(file.file_name))
    extension = Path.extname(file.file_name)
    "#{scope.id}_#{version}_#{file_name}#{extension}"
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "uploads/attachments/#{scope.id}/"
  end

  # Specify custom headers for s3 objects
  def s3_object_headers(_version, {file, _scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end

  def validate({file, _}) do
    # Allow most file types for attachments, but limit file size
    file_extension = file.file_name |> Path.extname() |> String.downcase()
    
    # Block potentially dangerous file types
    blocked_extensions = ~w(.exe .bat .cmd .com .scr .vbs .js .jar .app .deb .pkg .dmg .msi .run)
    
    case Enum.member?(blocked_extensions, file_extension) do
      true -> false
      false ->
        # Check file size (limit to 50MB)
        case File.stat(file.path) do
          {:ok, %{size: size}} -> size <= 50 * 1024 * 1024
          _ -> false
        end
    end
  end
end