# Script for populating the database with demo data for Slack Clone
# Run with: mix run priv/repo/seeds.exs

alias SlackClone.{Repo, Accounts, Workspaces, Channels, Messages}
alias SlackClone.Accounts.User
alias SlackClone.Workspaces.Workspace
alias SlackClone.Channels.{Channel, ChannelMembership}
alias SlackClone.Messages.Message

# Clear existing data in development
if Mix.env() == :dev do
  IO.puts("🗑️  Clearing existing data...")
  Repo.delete_all(Message)
  Repo.delete_all(ChannelMembership) 
  Repo.delete_all(Channel)
  Repo.delete_all("workspace_memberships") # assuming join table
  Repo.delete_all(Workspace)
  Repo.delete_all(User)
end

IO.puts("🌱 Seeding database with demo data...")

# Create demo users
IO.puts("👥 Creating users...")

users = [
  %{
    email: "admin@slackclone.com",
    name: "Admin User",
    username: "admin",
    password: "password123456",
    role: "admin",
    avatar_url: "https://api.dicebear.com/7.x/avataaars/svg?seed=admin",
    status: "active",
    timezone: "America/New_York"
  },
  %{
    email: "alice@slackclone.com", 
    name: "Alice Johnson",
    username: "alice",
    password: "password123456",
    avatar_url: "https://api.dicebear.com/7.x/avataaars/svg?seed=alice",
    status: "active",
    timezone: "America/New_York"
  },
  %{
    email: "bob@slackclone.com",
    name: "Bob Smith", 
    username: "bob",
    password: "password123456",
    avatar_url: "https://api.dicebear.com/7.x/avataaars/svg?seed=bob",
    status: "active",
    timezone: "America/Los_Angeles"
  },
  %{
    email: "carol@slackclone.com",
    name: "Carol Davis",
    username: "carol", 
    password: "password123456",
    avatar_url: "https://api.dicebear.com/7.x/avataaars/svg?seed=carol",
    status: "active",
    timezone: "Europe/London"
  },
  %{
    email: "dave@slackclone.com",
    name: "Dave Wilson",
    username: "dave",
    password: "password123456", 
    avatar_url: "https://api.dicebear.com/7.x/avataaars/svg?seed=dave",
    status: "active",
    timezone: "Asia/Tokyo"
  },
  %{
    email: "eve@slackclone.com",
    name: "Eve Chen",
    username: "eve",
    password: "password123456",
    avatar_url: "https://api.dicebear.com/7.x/avataaars/svg?seed=eve", 
    status: "active",
    timezone: "Australia/Sydney"
  }
]

created_users = for user_attrs <- users do
  case Accounts.get_user_by_email(user_attrs.email) do
    nil ->
      {:ok, user} = Accounts.register_user(user_attrs)
      IO.puts("  ✅ Created user: #{user.name} (#{user.email})")
      user
    existing_user ->
      IO.puts("  ↩️  User already exists: #{existing_user.name}")
      existing_user
  end
end

[admin, alice, bob, carol, dave, eve] = created_users

# Create demo workspaces
IO.puts("🏢 Creating workspaces...")

workspaces_data = [
  %{
    name: "Acme Corp",
    slug: "acme-corp", 
    description: "The main workspace for Acme Corporation",
    owner_id: admin.id,
    avatar_url: "https://api.dicebear.com/7.x/initials/svg?seed=Acme",
    settings: %{
      "allow_invites" => true,
      "public" => false,
      "require_approval" => false,
      "default_channels" => ["general", "random"],
      "timezone" => "America/New_York",
      "theme" => "light"
    }
  },
  %{
    name: "Dev Team",
    slug: "dev-team",
    description: "Development team collaboration space", 
    owner_id: alice.id,
    avatar_url: "https://api.dicebear.com/7.x/initials/svg?seed=Dev",
    settings: %{
      "allow_invites" => true,
      "public" => false,
      "require_approval" => true,
      "default_channels" => ["general", "development", "bugs"],
      "timezone" => "America/Los_Angeles",
      "theme" => "dark"
    }
  }
]

created_workspaces = for workspace_attrs <- workspaces_data do
  case Workspaces.get_workspace_by_slug(workspace_attrs.slug) do
    nil ->
      {:ok, workspace} = Workspaces.create_workspace(workspace_attrs)
      IO.puts("  ✅ Created workspace: #{workspace.name}")
      workspace
    existing_workspace ->
      IO.puts("  ↩️  Workspace already exists: #{existing_workspace.name}")
      existing_workspace
  end
end

[acme_workspace, dev_workspace] = created_workspaces

# Add users to workspaces
IO.puts("🔗 Adding users to workspaces...")

# Add all users to Acme Corp
acme_members = [admin, alice, bob, carol, dave, eve]
for user <- acme_members do
  case Workspaces.add_member(acme_workspace, user, %{role: (if user == admin, do: "admin", else: "member")}) do
    {:ok, _membership} ->
      IO.puts("  ✅ Added #{user.name} to #{acme_workspace.name}")
    {:error, _changeset} ->
      IO.puts("  ↩️  #{user.name} already in #{acme_workspace.name}")
  end
end

# Add dev team to Dev Team workspace
dev_members = [alice, bob, carol]
for user <- dev_members do
  case Workspaces.add_member(dev_workspace, user, %{role: (if user == alice, do: "admin", else: "member")}) do
    {:ok, _membership} ->
      IO.puts("  ✅ Added #{user.name} to #{dev_workspace.name}")
    {:error, _changeset} ->
      IO.puts("  ↩️  #{user.name} already in #{dev_workspace.name}")
  end
end

# Create channels
IO.puts("📺 Creating channels...")

acme_channels_data = [
  %{
    name: "general",
    description: "General discussion for everyone", 
    topic: "Welcome to Acme Corp! 👋",
    type: "public",
    workspace_id: acme_workspace.id,
    creator_id: admin.id
  },
  %{
    name: "random", 
    description: "Random chit-chat and fun stuff",
    topic: "🎲 Random thoughts and conversations",
    type: "public",
    workspace_id: acme_workspace.id,
    creator_id: admin.id
  },
  %{
    name: "announcements",
    description: "Important company announcements",
    topic: "📢 Official company news and updates", 
    type: "public",
    workspace_id: acme_workspace.id,
    creator_id: admin.id
  },
  %{
    name: "engineering",
    description: "Engineering team discussions",
    topic: "⚙️ Technical discussions and engineering topics",
    type: "public", 
    workspace_id: acme_workspace.id,
    creator_id: alice.id
  },
  %{
    name: "design",
    description: "Design team collaboration",
    topic: "🎨 Design discussions and feedback",
    type: "public",
    workspace_id: acme_workspace.id,
    creator_id: carol.id
  },
  %{
    name: "leadership",
    description: "Leadership team private discussions", 
    topic: "🔒 Confidential leadership discussions",
    type: "private",
    workspace_id: acme_workspace.id,
    creator_id: admin.id
  }
]

dev_channels_data = [
  %{
    name: "general",
    description: "General development discussions",
    topic: "Development team coordination",
    type: "public", 
    workspace_id: dev_workspace.id,
    creator_id: alice.id
  },
  %{
    name: "bugs",
    description: "Bug reports and tracking",
    topic: "🐛 Bug reports and fixes",
    type: "public",
    workspace_id: dev_workspace.id, 
    creator_id: alice.id
  },
  %{
    name: "code-review",
    description: "Code review discussions",
    topic: "👀 Code reviews and feedback", 
    type: "public",
    workspace_id: dev_workspace.id,
    creator_id: bob.id
  }
]

all_channels_data = acme_channels_data ++ dev_channels_data

created_channels = for channel_attrs <- all_channels_data do
  case Channels.get_channel_by_name(channel_attrs.workspace_id, channel_attrs.name) do
    nil ->
      {:ok, channel} = Channels.create_channel(channel_attrs)
      IO.puts("  ✅ Created channel: ##{channel.name} in #{(if channel.workspace_id == acme_workspace.id, do: "Acme Corp", else: "Dev Team")}")
      channel
    existing_channel ->
      IO.puts("  ↩️  Channel already exists: ##{existing_channel.name}")
      existing_channel
  end
end

# Organize channels by workspace
{acme_channels, dev_channels} = Enum.split(created_channels, length(acme_channels_data))
[general_acme, random_acme, announcements_acme, engineering_acme, design_acme, leadership_acme] = acme_channels
[general_dev, bugs_dev, code_review_dev] = dev_channels

# Add users to channels
IO.puts("👥 Adding users to channels...")

# Acme Corp channel memberships
public_acme_channels = [general_acme, random_acme, announcements_acme, engineering_acme, design_acme]
for channel <- public_acme_channels do
  for user <- acme_members do
    case Channels.add_member(channel, user) do
      {:ok, _membership} ->
        IO.puts("  ✅ Added #{user.name} to ##{channel.name}")
      {:error, _} ->
        IO.puts("  ↩️  #{user.name} already in ##{channel.name}")
    end
  end
end

# Leadership channel - only admin and select members
leadership_members = [admin, alice]
for user <- leadership_members do
  case Channels.add_member(leadership_acme, user) do
    {:ok, _membership} ->
      IO.puts("  ✅ Added #{user.name} to ##{leadership_acme.name}")
    {:error, _} ->
      IO.puts("  ↩️  #{user.name} already in ##{leadership_acme.name}")
  end
end

# Dev Team channel memberships  
dev_team_channels = [general_dev, bugs_dev, code_review_dev]
for channel <- dev_team_channels do
  for user <- dev_members do
    case Channels.add_member(channel, user) do
      {:ok, _membership} ->
        IO.puts("  ✅ Added #{user.name} to ##{channel.name}")
      {:error, _} ->
        IO.puts("  ↩️  #{user.name} already in ##{channel.name}")
    end
  end
end

# Create demo messages
IO.puts("💬 Creating demo messages...")

demo_messages = [
  # General channel messages
  {general_acme, admin, "Welcome everyone to our new Slack clone! 🎉", -120},
  {general_acme, alice, "This looks great! The real-time features are working perfectly.", -115},
  {general_acme, bob, "I love the clean interface. Much better than our old chat system.", -110},
  {general_acme, carol, "The typing indicators are so smooth! Great job on the UX.", -105},
  {general_acme, dave, "Can we customize the themes? I'd love a dark mode option.", -100},
  {general_acme, eve, "Dark mode is already available in settings! Check the workspace preferences.", -95},
  
  # Random channel messages
  {random_acme, bob, "Anyone else excited for the weekend? ☀️", -90},
  {random_acme, carol, "I'm planning to try that new coffee shop downtown!", -85},
  {random_acme, alice, "Coffee sounds great! Mind if I join?", -80},
  {random_acme, dave, "Make it three! I could use some good coffee ☕", -75},
  
  # Engineering channel messages
  {engineering_acme, alice, "We should discuss the new microservices architecture in our next meeting.", -70},
  {engineering_acme, bob, "I've been working on the database optimization. Seeing 40% performance improvement!", -65},
  {engineering_acme, alice, "That's fantastic! Can you share your benchmarks?", -60},
  {engineering_acme, dave, "The real-time features are handling 1000+ concurrent users without issues.", -55},
  
  # Design channel messages
  {design_acme, carol, "I've updated the color palette for better accessibility. Thoughts?", -50},
  {design_acme, eve, "The contrast ratios look perfect now. WCAG AAA compliant! ♿", -45},
  {design_acme, carol, "Should we update the mobile interface to match?", -40},
  {design_acme, alice, "Definitely! Consistency across platforms is key.", -35},
  
  # Announcements
  {announcements_acme, admin, "🚀 Version 2.0 is now live! New features include file sharing and video calls.", -30},
  {announcements_acme, admin, "Team meeting scheduled for Friday at 2 PM. See calendar for details.", -25},
  
  # Leadership private channel
  {leadership_acme, admin, "Q4 numbers are looking strong. Revenue up 25%.", -20},
  {leadership_acme, alice, "The engineering team has exceeded all sprint goals this quarter.", -15},
  
  # Dev Team workspace messages
  {general_dev, alice, "Welcome to the dev team workspace! Let's coordinate our efforts here.", -60},
  {general_dev, bob, "Perfect! This will help us stay more focused.", -55},
  {general_dev, carol, "I'll move our ongoing discussions here.", -50},
  
  {bugs_dev, bob, "Found a race condition in the message ordering. Working on a fix.", -45},
  {bugs_dev, alice, "Priority level? Should we hotfix or include in next release?", -40},
  {bugs_dev, bob, "It's rare but critical. I'd say hotfix.", -35},
  
  {code_review_dev, alice, "Please review PR #123 - implements new caching layer.", -30},
  {code_review_dev, carol, "Looking at it now. The Redis integration looks solid.", -25},
  {code_review_dev, bob, "LGTM! Ready to merge.", -20}
]

# Create messages with timestamps spread over the last 2 hours
base_time = DateTime.utc_now()

for {channel, user, content, minutes_ago} <- demo_messages do
  timestamp = DateTime.add(base_time, minutes_ago * 60, :second)
  
  message_attrs = %{
    content: content,
    channel_id: channel.id,
    user_id: user.id,
    type: "text",
    metadata: %{},
    inserted_at: timestamp,
    updated_at: timestamp
  }
  
  case Messages.create_message(message_attrs) do
    {:ok, message} ->
      IO.puts("  ✅ Created message in ##{channel.name}: #{String.slice(content, 0, 50)}...")
    {:error, changeset} ->
      IO.puts("  ❌ Failed to create message: #{inspect(changeset.errors)}")
  end
end

# Create some threaded messages
IO.puts("🧵 Creating threaded conversations...")

# Find the performance message to create a thread
case Messages.get_messages_by_content_pattern(engineering_acme.id, "performance improvement") do
  [parent_message | _] ->
    thread_replies = [
      {bob, "Here are the benchmarks: https://example.com/benchmarks.pdf", -58},
      {alice, "Impressive results! What was the bottleneck?", -56}, 
      {bob, "Mostly N+1 queries and missing database indexes.", -54},
      {dave, "We should apply these optimizations to other services too.", -52}
    ]
    
    for {user, content, minutes_ago} <- thread_replies do
      timestamp = DateTime.add(base_time, minutes_ago * 60, :second)
      
      reply_attrs = %{
        content: content,
        channel_id: engineering_acme.id,
        user_id: user.id,
        type: "text",
        thread_id: parent_message.id,
        metadata: %{},
        inserted_at: timestamp,
        updated_at: timestamp
      }
      
      case Messages.create_message(reply_attrs) do
        {:ok, _reply} ->
          IO.puts("  ✅ Created thread reply: #{String.slice(content, 0, 30)}...")
        {:error, changeset} ->
          IO.puts("  ❌ Failed to create thread reply: #{inspect(changeset.errors)}")
      end
    end
  
  [] ->
    IO.puts("  ⚠️  Parent message not found for threading")
end

IO.puts("\n🎉 Database seeding completed successfully!")
IO.puts("\n📊 Demo Data Summary:")
IO.puts("  👥 Users: #{length(created_users)}")
IO.puts("  🏢 Workspaces: #{length(created_workspaces)}")
IO.puts("  📺 Channels: #{length(created_channels)}")
IO.puts("  💬 Messages: #{length(demo_messages) + 4}")  # messages + thread replies

IO.puts("\n🚀 You can now test the application with these demo accounts:")
IO.puts("  📧 admin@slackclone.com (Admin)")
IO.puts("  📧 alice@slackclone.com (Team Lead)")
IO.puts("  📧 bob@slackclone.com (Developer)")
IO.puts("  📧 carol@slackclone.com (Designer)")
IO.puts("  📧 dave@slackclone.com (Developer)")
IO.puts("  📧 eve@slackclone.com (QA Engineer)")
IO.puts("  🔑 Password for all accounts: password123")

IO.puts("\n🌟 Workspaces available:")
IO.puts("  🏢 Acme Corp (acme-corp) - Main company workspace")
IO.puts("  💻 Dev Team (dev-team) - Development team workspace")

IO.puts("\n✨ Features to test:")
IO.puts("  💬 Real-time messaging")
IO.puts("  👀 Presence indicators") 
IO.puts("  ⌨️  Typing indicators")
IO.puts("  🧵 Threaded conversations")
IO.puts("  👍 Message reactions")
IO.puts("  📎 File attachments")
IO.puts("  💌 Direct messages")
IO.puts("  🔒 Private channels")
IO.puts("  🎨 Multiple workspaces")
