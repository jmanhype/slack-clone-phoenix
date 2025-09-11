alias SlackClone.Repo
alias SlackClone.Accounts.User
alias SlackClone.Workspaces.{Workspace, WorkspaceMembership}
alias SlackClone.Channels.Channel
alias SlackClone.Messages.Message

# Clear existing data
IO.puts("Clearing existing test data...")
Repo.delete_all(Message)
Repo.delete_all(Channel)
Repo.delete_all(WorkspaceMembership)
Repo.delete_all(Workspace)
Repo.delete_all(User)

# Create test users
IO.puts("Creating test users...")
{:ok, user1} = SlackClone.Accounts.register_user(%{
  email: "john@example.com",
  password: "password123456",
  name: "John Doe",
  username: "john_doe"
})

{:ok, user2} = SlackClone.Accounts.register_user(%{
  email: "jane@example.com",
  password: "password123456",
  name: "Jane Smith",
  username: "jane_smith"
})

{:ok, user3} = SlackClone.Accounts.register_user(%{
  email: "bob@example.com", 
  password: "password123456",
  name: "Bob Johnson",
  username: "bob_johnson"
})

IO.puts("Created #{Repo.aggregate(User, :count)} users")

# Create test workspaces
IO.puts("Creating test workspaces...")
{:ok, workspace1} = SlackClone.Workspaces.create_workspace(%{
  name: "Acme Corp",
  slug: "acme-corp",
  description: "The main workspace for Acme Corporation",
  owner_id: user1.id
})

{:ok, workspace2} = SlackClone.Workspaces.create_workspace(%{
  name: "Test Team",
  slug: "test-team", 
  description: "A workspace for testing purposes",
  owner_id: user2.id
})

IO.puts("Created #{Repo.aggregate(Workspace, :count)} workspaces")

# Create workspace memberships
IO.puts("Creating workspace memberships...")
{:ok, _} = SlackClone.Workspaces.create_workspace_membership(%{
  workspace_id: workspace1.id,
  user_id: user1.id,
  role: "owner"
})

{:ok, _} = SlackClone.Workspaces.create_workspace_membership(%{
  workspace_id: workspace1.id,
  user_id: user2.id,
  role: "member"
})

{:ok, _} = SlackClone.Workspaces.create_workspace_membership(%{
  workspace_id: workspace1.id,
  user_id: user3.id,
  role: "member"
})

{:ok, _} = SlackClone.Workspaces.create_workspace_membership(%{
  workspace_id: workspace2.id,
  user_id: user2.id,
  role: "owner"
})

{:ok, _} = SlackClone.Workspaces.create_workspace_membership(%{
  workspace_id: workspace2.id,
  user_id: user1.id,
  role: "member"
})

IO.puts("Created #{Repo.aggregate(WorkspaceMembership, :count)} workspace memberships")

# Create test channels
IO.puts("Creating test channels...")
general_channel = Repo.insert!(%Channel{
  name: "general",
  description: "General discussions",
  is_private: false,
  workspace_id: workspace1.id,
  created_by_id: user1.id
})

random_channel = Repo.insert!(%Channel{
  name: "random",
  description: "Random conversations",
  is_private: false,
  workspace_id: workspace1.id,
  created_by_id: user1.id
})

dev_channel = Repo.insert!(%Channel{
  name: "development",
  description: "Development discussions",
  is_private: true,
  workspace_id: workspace1.id,
  created_by_id: user1.id
})

test_general = Repo.insert!(%Channel{
  name: "general",
  description: "General discussions for test team",
  is_private: false,
  workspace_id: workspace2.id,
  created_by_id: user2.id
})

IO.puts("Created #{Repo.aggregate(Channel, :count)} channels")

# Create some test messages
IO.puts("Creating test messages...")
now = DateTime.utc_now()

Repo.insert!(%Message{
  content: "Welcome to the Acme Corp workspace!",
  channel_id: general_channel.id,
  user_id: user1.id,
  inserted_at: DateTime.add(now, -3600, :second),
  updated_at: DateTime.add(now, -3600, :second)
})

Repo.insert!(%Message{
  content: "Thanks for setting this up, John!",
  channel_id: general_channel.id,
  user_id: user2.id,
  inserted_at: DateTime.add(now, -3000, :second),
  updated_at: DateTime.add(now, -3000, :second)
})

Repo.insert!(%Message{
  content: "Looking forward to working together!",
  channel_id: general_channel.id,
  user_id: user3.id,
  inserted_at: DateTime.add(now, -2400, :second),
  updated_at: DateTime.add(now, -2400, :second)
})

Repo.insert!(%Message{
  content: "What's everyone working on today?",
  channel_id: random_channel.id,
  user_id: user2.id,
  inserted_at: DateTime.add(now, -1800, :second),
  updated_at: DateTime.add(now, -1800, :second)
})

Repo.insert!(%Message{
  content: "Working on the new authentication system",
  channel_id: dev_channel.id,
  user_id: user1.id,
  inserted_at: DateTime.add(now, -1200, :second),
  updated_at: DateTime.add(now, -1200, :second)
})

Repo.insert!(%Message{
  content: "I can help with that! Let me know if you need any assistance.",
  channel_id: dev_channel.id,
  user_id: user3.id,
  inserted_at: DateTime.add(now, -600, :second),
  updated_at: DateTime.add(now, -600, :second)
})

IO.puts("Created #{Repo.aggregate(Message, :count)} messages")

IO.puts("\n✅ Test data seeding completed successfully!")
IO.puts("📊 Summary:")
IO.puts("  - Users: #{Repo.aggregate(User, :count)}")
IO.puts("  - Workspaces: #{Repo.aggregate(Workspace, :count)}")
IO.puts("  - Workspace Memberships: #{Repo.aggregate(WorkspaceMembership, :count)}")
IO.puts("  - Channels: #{Repo.aggregate(Channel, :count)}")
IO.puts("  - Messages: #{Repo.aggregate(Message, :count)}")

IO.puts("\n🔑 Test Credentials:")
IO.puts("  - john@example.com / password123456")
IO.puts("  - jane@example.com / password123456")
IO.puts("  - bob@example.com / password123456")

IO.puts("\n🏢 Test Workspaces:")
IO.puts("  - Acme Corp (acme-corp) - Owner: john@example.com")
IO.puts("  - Test Team (test-team) - Owner: jane@example.com")