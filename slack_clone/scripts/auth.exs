#!/usr/bin/env elixir

# Simple authentication script to generate JWT tokens for testing
# Run with: mix run scripts/auth.exs

alias SlackClone.{Accounts, Guardian}

# Create or get a test user
email = "test@example.com"
password = "password123456"  # Minimum 12 characters

IO.puts("\n🔐 SlackClone Authentication Helper\n")

user = case Accounts.get_user_by_email(email) do
  nil ->
    IO.puts("Creating new test user...")
    {:ok, user} = Accounts.register_user(%{
      email: email,
      password: password
    })
    IO.puts("✅ User created: #{user.email}")
    user
    
  existing_user ->
    IO.puts("✅ Using existing user: #{existing_user.email}")
    existing_user
end

# Authenticate and generate token
IO.puts("\nAuthenticating...")
case Accounts.authenticate_user(email, password) do
  {:ok, user} ->
    # Generate JWT token
    {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")
    {:ok, refresh_token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {7, :days})
    
    IO.puts("\n✅ Authentication successful!")
    IO.puts("\n📋 User Details:")
    IO.puts("  ID: #{user.id}")
    IO.puts("  Email: #{user.email}")
    
    IO.puts("\n🔑 Access Token (valid for 24 hours):")
    IO.puts("#{token}")
    
    IO.puts("\n🔄 Refresh Token (valid for 7 days):")
    IO.puts("#{refresh_token}")
    
    IO.puts("\n📡 API Usage Examples:")
    IO.puts("\n1. Test authentication:")
    IO.puts("curl -H \"Authorization: Bearer #{token}\" http://localhost:4000/api/me")
    
    IO.puts("\n2. Get workspaces:")
    IO.puts("curl -H \"Authorization: Bearer #{token}\" http://localhost:4000/api/workspaces")
    
    IO.puts("\n3. Send a message:")
    IO.puts("""
    curl -X POST http://localhost:4000/api/channels/{channel_id}/messages \\
      -H "Authorization: Bearer #{token}" \\
      -H "Content-Type: application/json" \\
      -d '{"content": "Hello from API!"}'
    """)
    
    IO.puts("\n4. WebSocket connection:")
    IO.puts("ws://localhost:4000/socket/websocket?token=#{token}")
    
    IO.puts("\n🌐 Browser Usage:")
    IO.puts("You can also use this token in the browser console:")
    IO.puts("""
    // Store token in localStorage
    localStorage.setItem('auth_token', '#{token}');
    
    // Use in fetch requests
    fetch('/api/me', {
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('auth_token')}`
      }
    }).then(r => r.json()).then(console.log);
    """)
    
  {:error, reason} ->
    IO.puts("\n❌ Authentication failed: #{reason}")
    IO.puts("Make sure the user exists and password is correct.")
end

IO.puts("\n---")
IO.puts("You can also test with these demo accounts:")
IO.puts("  📧 admin@slackclone.com (password: password123)")
IO.puts("  📧 alice@slackclone.com (password: password123)")
IO.puts("  📧 bob@slackclone.com (password: password123)")