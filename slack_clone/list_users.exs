# List all users in database
alias SlackClone.{Accounts, Repo}
alias SlackClone.Accounts.User

# Get all users from database
users = Repo.all(User)
IO.inspect(length(users), label: "Total users in database")

for user <- users do
  IO.puts("Email: #{user.email}, ID: #{user.id}")
end

if length(users) == 0 do
  IO.puts("\n=== No users found! Creating test user ===")
  
  # Create a test user
  attrs = %{
    email: "admin@slack.local", 
    password: "password123"
  }
  
  case Accounts.register_user(attrs) do
    {:ok, user} -> 
      IO.puts("Created user: #{user.email} with ID: #{user.id}")
      IO.inspect(user.hashed_password, label: "New hash")
      
      # Test the new user immediately
      IO.puts("\n=== Testing new user ===")
      IO.inspect(User.valid_password?(user, "password123"), label: "Password verification")
      IO.inspect(Accounts.authenticate_user("admin@slack.local", "password123"), label: "Authentication")
      
    {:error, changeset} -> 
      IO.puts("Failed to create user:")
      IO.inspect(changeset.errors)
  end
end