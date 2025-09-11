defmodule SlackClone.Factory do
  @moduledoc """
  ExMachina factory for generating test data
  """
  use ExMachina.Ecto, repo: SlackClone.Repo

  alias SlackClone.Accounts.User
  alias SlackClone.Workspaces.Workspace
  alias SlackClone.Channels.Channel
  alias SlackClone.Messages.Message
  alias SlackClone.Uploaders.Attachment

  def user_factory do
    %User{
      email: sequence(:email, &"user#{&1}@example.com"),
      name: sequence(:name, &"User #{&1}"),
      username: sequence(:username, &"user#{&1}"),
      password_hash: Argon2.hash_pwd_salt("password123"),
      avatar_url: "https://avatars.dicebear.com/api/avataaars/#{sequence(:avatar, & &1)}.svg",
      status: "active",
      timezone: "America/New_York",
      last_seen_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def admin_user_factory do
    build(:user, %{
      name: "Admin User",
      email: "admin@example.com",
      username: "admin",
      role: "admin"
    })
  end

  def workspace_factory do
    %Workspace{
      name: sequence(:workspace_name, &"Workspace #{&1}"),
      slug: sequence(:workspace_slug, &"workspace-#{&1}"),
      description: "A test workspace for collaboration",
      avatar_url: "https://via.placeholder.com/100x100",
      settings: %{
        "allow_invites" => true,
        "public" => false,
        "timezone" => "UTC"
      },
      owner: build(:user),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def channel_factory do
    %Channel{
      name: sequence(:channel_name, &"channel-#{&1}"),
      description: sequence(:channel_description, &"Test channel #{&1}"),
      topic: "General discussion",
      type: "public",
      archived: false,
      workspace: build(:workspace),
      creator: build(:user),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def private_channel_factory do
    build(:channel, %{
      type: "private",
      name: sequence(:private_channel, &"private-#{&1}")
    })
  end

  def dm_channel_factory do
    build(:channel, %{
      type: "dm",
      name: nil,
      description: nil
    })
  end

  def message_factory do
    %Message{
      content: Faker.Lorem.sentence(4..20),
      type: "text",
      user: build(:user),
      channel: build(:channel),
      metadata: %{},
      thread_id: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def thread_message_factory do
    parent_message = build(:message)
    
    build(:message, %{
      thread_id: parent_message.id,
      channel: parent_message.channel
    })
  end

  def edited_message_factory do
    build(:message, %{
      content: "This message has been edited",
      metadata: %{
        "edited" => true,
        "edited_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    })
  end

  def attachment_factory do
    %Attachment{
      filename: sequence(:filename, &"file-#{&1}.pdf"),
      original_name: sequence(:original_name, &"Document #{&1}.pdf"),
      content_type: "application/pdf",
      file_size: Enum.random(1000..50000),
      url: sequence(:url, &"https://cdn.example.com/files/#{&1}.pdf"),
      thumbnail_url: nil,
      message: build(:message),
      user: build(:user),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def image_attachment_factory do
    build(:attachment, %{
      filename: sequence(:image_filename, &"image-#{&1}.jpg"),
      original_name: sequence(:image_original, &"Photo #{&1}.jpg"),
      content_type: "image/jpeg",
      file_size: Enum.random(50000..500000),
      url: sequence(:image_url, &"https://cdn.example.com/images/#{&1}.jpg"),
      thumbnail_url: sequence(:thumbnail_url, &"https://cdn.example.com/thumbnails/#{&1}.jpg")
    })
  end

  def workspace_membership_factory do
    %{
      workspace: build(:workspace),
      user: build(:user),
      role: "member",
      joined_at: DateTime.utc_now()
    }
  end

  def channel_membership_factory do
    %{
      channel: build(:channel),
      user: build(:user),
      role: "member",
      joined_at: DateTime.utc_now(),
      last_read_at: DateTime.utc_now()
    }
  end

  def typing_event_factory do
    %{
      user_id: sequence(:user_id, & &1),
      channel_id: sequence(:channel_id, & &1),
      started_at: DateTime.utc_now(),
      expires_at: DateTime.add(DateTime.utc_now(), 5, :second)
    }
  end

  def presence_factory do
    %{
      user_id: sequence(:presence_user_id, & &1),
      status: Enum.random([:online, :away, :offline]),
      last_seen: DateTime.utc_now(),
      metadata: %{
        "device" => "web",
        "location" => "New York, NY"
      }
    }
  end

  def reaction_factory do
    %{
      message: build(:message),
      user: build(:user),
      emoji: Enum.random(["👍", "❤️", "😊", "🎉", "🔥", "👏"]),
      inserted_at: DateTime.utc_now()
    }
  end

  def notification_factory do
    %{
      user: build(:user),
      type: "mention",
      title: "You were mentioned",
      content: "Someone mentioned you in #general",
      data: %{
        "channel_id" => sequence(:notif_channel_id, & &1),
        "message_id" => sequence(:notif_message_id, & &1)
      },
      read: false,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  # Utility functions for creating related data

  def user_with_workspace(attrs \\ %{}) do
    workspace = insert(:workspace)
    user = insert(:user, attrs)
    
    # Add user to workspace
    insert(:workspace_membership, workspace: workspace, user: user)
    
    %{user | workspaces: [workspace]}
  end

  def channel_with_messages(message_count \\ 5, attrs \\ %{}) do
    channel = insert(:channel, attrs)
    messages = insert_list(message_count, :message, channel: channel)
    
    %{channel | messages: messages}
  end

  def workspace_with_channels(channel_count \\ 3, attrs \\ %{}) do
    workspace = insert(:workspace, attrs)
    channels = insert_list(channel_count, :channel, workspace: workspace)
    
    %{workspace | channels: channels}
  end

  def message_with_reactions(reaction_count \\ 3, attrs \\ %{}) do
    message = insert(:message, attrs)
    reactions = insert_list(reaction_count, :reaction, message: message)
    
    %{message | reactions: reactions}
  end

  def message_with_attachments(attachment_count \\ 2, attrs \\ %{}) do
    message = insert(:message, attrs)
    attachments = insert_list(attachment_count, :attachment, message: message)
    
    %{message | attachments: attachments}
  end

  def thread_with_replies(reply_count \\ 3, attrs \\ %{}) do
    parent_message = insert(:message, attrs)
    replies = insert_list(reply_count, :thread_message, 
      thread_id: parent_message.id, 
      channel: parent_message.channel
    )
    
    %{parent_message | replies: replies}
  end

  def full_workspace_setup(attrs \\ %{}) do
    # Create workspace with owner
    owner = insert(:admin_user)
    workspace = insert(:workspace, Map.merge(attrs, %{owner: owner}))
    
    # Create channels
    general_channel = insert(:channel, 
      name: "general", 
      workspace: workspace, 
      creator: owner
    )
    random_channel = insert(:channel, 
      name: "random", 
      workspace: workspace, 
      creator: owner
    )
    private_channel = insert(:private_channel, 
      workspace: workspace, 
      creator: owner
    )
    
    # Create users and add to workspace
    users = insert_list(5, :user)
    
    for user <- [owner | users] do
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: general_channel, user: user)
      insert(:channel_membership, channel: random_channel, user: user)
    end
    
    # Add owner to private channel
    insert(:channel_membership, channel: private_channel, user: owner)
    
    # Create some messages
    for _ <- 1..10 do
      user = Enum.random([owner | users])
      channel = Enum.random([general_channel, random_channel])
      insert(:message, user: user, channel: channel)
    end
    
    %{
      workspace: workspace,
      owner: owner,
      users: users,
      channels: [general_channel, random_channel, private_channel],
      general_channel: general_channel,
      random_channel: random_channel,
      private_channel: private_channel
    }
  end
end