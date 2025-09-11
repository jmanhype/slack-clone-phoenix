# Debug password verification
alias SlackClone.{Accounts, Repo}
alias SlackClone.Accounts.User

# Get the user from database
user = Repo.get_by(User, email: "admin@slack.local")
IO.inspect(user, label: "User from DB")

if user do
  IO.inspect(user.hashed_password, label: "Stored hash")
  
  # Test direct Bcrypt verification with the problematic hash
  test_hash = "$2b$12$KnCHcY2fqMQQ366axXfqw.0rdSuiz/6W/EJPs70TTvAuP7GUfxssW"
  test_password = "password123"
  
  IO.puts("\n=== Direct Bcrypt Tests ===")
  IO.inspect(Bcrypt.verify_pass(test_password, test_hash), label: "Direct Bcrypt.verify_pass with test hash")
  IO.inspect(Bcrypt.verify_pass(test_password, user.hashed_password), label: "Direct Bcrypt.verify_pass with stored hash")
  
  IO.puts("\n=== User.valid_password? Tests ===")
  IO.inspect(User.valid_password?(user, test_password), label: "User.valid_password? with 'password123'")
  IO.inspect(User.valid_password?(user, "password"), label: "User.valid_password? with 'password'")
  IO.inspect(User.valid_password?(user, "wrongpassword"), label: "User.valid_password? with wrong password")
  
  IO.puts("\n=== Accounts.authenticate_user Tests ===")
  IO.inspect(Accounts.authenticate_user("admin@slack.local", test_password), label: "Accounts.authenticate_user with 'password123'")
  IO.inspect(Accounts.authenticate_user("admin@slack.local", "password"), label: "Accounts.authenticate_user with 'password'")
  
  IO.puts("\n=== Password length and encoding check ===")
  IO.inspect(byte_size(test_password), label: "Byte size of test password")
  IO.inspect(String.length(test_password), label: "String length of test password")
  IO.inspect(:unicode.characters_to_binary(test_password), label: "Unicode encoding check")
  
  # Test hash generation
  IO.puts("\n=== Hash generation test ===")
  new_hash = Bcrypt.hash_pwd_salt(test_password)
  IO.inspect(new_hash, label: "New hash for 'password123'")
  IO.inspect(Bcrypt.verify_pass(test_password, new_hash), label: "Verify new hash works")
else
  IO.puts("No user found with email admin@slack.local")
end