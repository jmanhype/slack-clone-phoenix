defmodule SlackClone.Uploaders.Avatar do
  @moduledoc """
  Avatar uploader using Waffle for handling user profile pictures.
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original, :thumb]
  @extension_whitelist ~w(.jpg .jpeg .png .gif .webp)

  def acl(:thumb, _), do: :public_read
  def acl(:original, _), do: :public_read

  # Define a thumbnail transformation for the thumb version.
  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 150x150^ -gravity center -extent 150x150 -format png", :png}
  end

  # Override the persisted filenames.
  def filename(version, {file, scope}) do
    file_name = Path.basename(file.file_name, Path.extname(file.file_name))
    "#{scope.id}_#{version}_#{file_name}"
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "uploads/avatars/#{scope.id}/"
  end

  # Provide a default URL if there has been no file uploaded
  def default_url(version, _scope) do
    "/images/default_avatar_#{version}.png"
  end

  # Specify custom headers for s3 objects
  # Available options are [:cache_control, :content_disposition,
  #    :content_encoding, :content_language, :content_type,
  #    :expires, :storage_class, :website_redirect_location]
  def s3_object_headers(_version, {file, _scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()
    Enum.member?(@extension_whitelist, file_extension)
  end
end