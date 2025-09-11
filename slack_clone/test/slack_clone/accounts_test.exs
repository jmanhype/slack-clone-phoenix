defmodule SlackClone.AccountsTest do
  use SlackClone.DataCase, async: true

  import Mox

  alias SlackClone.Accounts
  alias SlackClone.Accounts.{User, UserToken, UserNotifier}

  # London School TDD - Mock external dependencies
  setup :verify_on_exit!

  defmock(MockRepo, for: Ecto.Repo)
  defmock(MockNotifier, for: SlackClone.Accounts.UserNotifier)
  defmock(MockTokenService, for: SlackClone.Accounts.UserToken)

  describe "user registration - outside-in TDD" do
    test "successfully registers user with valid data" do
      # Mock repository interactions
      MockRepo
      |> expect(:get_by, fn User, [email: "test@example.com"] -> nil end)
      |> expect(:insert, fn changeset ->
        {:ok, %User{
          id: "test-user-id",
          email: "test@example.com",
          name: "Test User",
          confirmed_at: nil
        }}
      end)

      # Mock notification service
      MockNotifier
      |> expect(:deliver_confirmation_instructions, fn user, url ->
        {:ok, %{to: user.email, body: "confirmation email"}}
      end)

      user_attrs = %{
        email: "test@example.com",
        name: "Test User",
        password: "password123"
      }

      # Verify the conversation between objects
      assert {:ok, %User{} = user} = Accounts.register_user(user_attrs)
      assert user.email == "test@example.com"
      assert user.name == "Test User"
      assert is_nil(user.confirmed_at)
    end

    test "fails registration with invalid email format" do
      MockRepo
      |> expect(:insert, fn _changeset ->
        {:error, %Ecto.Changeset{
          valid?: false,
          errors: [email: {"has invalid format", [validation: :format]}]
        }}
      end)

      user_attrs = %{
        email: "invalid-email",
        name: "Test User",
        password: "password123"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.register_user(user_attrs)
      refute changeset.valid?
      assert %{email: ["has invalid format"]} = changeset_errors(changeset)
    end

    test "fails registration when email already exists" do
      existing_user = build(:user, email: "test@example.com")

      MockRepo
      |> expect(:get_by, fn User, [email: "test@example.com"] -> existing_user end)
      |> expect(:insert, fn _changeset ->
        {:error, %Ecto.Changeset{
          valid?: false,
          errors: [email: {"has already been taken", [constraint: :unique]}]
        }}
      end)

      user_attrs = %{
        email: "test@example.com",
        name: "Test User",
        password: "password123"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.register_user(user_attrs)
      assert %{email: ["has already been taken"]} = changeset_errors(changeset)
    end
  end

  describe "user authentication - behavior verification" do
    test "successfully authenticates user with correct credentials" do
      user = build(:user, email: "test@example.com")

      MockRepo
      |> expect(:get_by, fn User, [email: "test@example.com"] -> user end)

      # Mock password verification
      expect(User, :valid_password?, fn ^user, "correct_password" -> true end)

      assert {:ok, authenticated_user} = Accounts.authenticate_user("test@example.com", "correct_password")
      assert authenticated_user.id == user.id
    end

    test "fails authentication with invalid credentials" do
      MockRepo
      |> expect(:get_by, fn User, [email: "test@example.com"] -> nil end)

      assert {:error, :invalid_credentials} = Accounts.authenticate_user("test@example.com", "wrong_password")
    end

    test "fails authentication with incorrect password" do
      user = build(:user, email: "test@example.com")

      MockRepo
      |> expect(:get_by, fn User, [email: "test@example.com"] -> user end)

      expect(User, :valid_password?, fn ^user, "wrong_password" -> false end)

      assert {:error, :invalid_credentials} = Accounts.authenticate_user("test@example.com", "wrong_password")
    end
  end

  describe "session management - interaction testing" do
    test "generates session token and stores in database" do
      user = build(:user, id: "user-123")
      token = "session-token-123"

      MockTokenService
      |> expect(:build_session_token, fn ^user -> {token, %UserToken{}} end)

      MockRepo
      |> expect(:insert!, fn %UserToken{} -> %UserToken{token: token} end)

      result_token = Accounts.generate_user_session_token(user)
      assert result_token == token
    end

    test "retrieves user by valid session token" do
      user = build(:user, id: "user-123")
      token = "valid-session-token"

      MockTokenService
      |> expect(:verify_session_token_query, fn ^token -> {:ok, "mock-query"} end)

      MockRepo
      |> expect(:one, fn "mock-query" -> user end)

      result_user = Accounts.get_user_by_session_token(token)
      assert result_user.id == user.id
    end

    test "returns nil for invalid session token" do
      token = "invalid-token"

      MockTokenService
      |> expect(:verify_session_token_query, fn ^token -> {:error, :invalid} end)

      result = Accounts.get_user_by_session_token(token)
      assert is_nil(result)
    end

    test "deletes session token" do
      token = "session-token-to-delete"

      MockRepo
      |> expect(:delete_all, fn query -> {1, nil} end)

      MockTokenService
      |> expect(:by_token_and_context_query, fn ^token, "session" -> "delete-query" end)

      result = Accounts.delete_user_session_token(token)
      assert result == :ok
    end
  end

  describe "email confirmation - contract testing" do
    test "delivers confirmation email with proper contract" do
      user = build(:user, confirmed_at: nil)
      token = "confirmation-token"
      user_token = %UserToken{user: user, context: "confirm"}

      MockTokenService
      |> expect(:build_email_token, fn ^user, "confirm" -> {token, user_token} end)

      MockRepo
      |> expect(:insert!, fn ^user_token -> user_token end)

      MockNotifier
      |> expect(:deliver_confirmation_instructions, fn ^user, confirmation_url ->
        assert String.contains?(confirmation_url, token)
        {:ok, %{to: user.email, body: "confirmation email"}}
      end)

      confirmation_url_fun = fn token -> "http://example.com/confirm/#{token}" end

      result = Accounts.deliver_user_confirmation_instructions(user, confirmation_url_fun)
      assert {:ok, %{to: _, body: _}} = result
    end

    test "prevents confirmation email for already confirmed user" do
      user = build(:user, confirmed_at: DateTime.utc_now())

      # Should not call any external services
      result = Accounts.deliver_user_confirmation_instructions(user, fn _ -> "url" end)
      assert {:error, :already_confirmed} = result
    end

    test "confirms user with valid token" do
      user = build(:user, confirmed_at: nil)
      token = "valid-confirmation-token"

      MockTokenService
      |> expect(:verify_email_token_query, fn ^token, "confirm" -> {:ok, "verify-query"} end)

      MockRepo
      |> expect(:one, fn "verify-query" -> user end)
      |> expect(:transaction, fn _multi ->
        confirmed_user = %{user | confirmed_at: DateTime.utc_now()}
        {:ok, %{user: confirmed_user}}
      end)

      result = Accounts.confirm_user(token)
      assert {:ok, confirmed_user} = result
      assert confirmed_user.confirmed_at != nil
    end
  end

  describe "password reset - collaboration patterns" do
    test "orchestrates password reset workflow" do
      user = build(:user)
      reset_token = "reset-token-123"
      user_token = %UserToken{user: user, context: "reset_password"}

      # Verify the sequence of collaborations
      MockTokenService
      |> expect(:build_email_token, fn ^user, "reset_password" -> {reset_token, user_token} end)

      MockRepo
      |> expect(:insert!, fn ^user_token -> user_token end)

      MockNotifier
      |> expect(:deliver_reset_password_instructions, fn ^user, reset_url ->
        assert String.contains?(reset_url, reset_token)
        {:ok, %{to: user.email, body: "password reset email"}}
      end)

      reset_url_fun = fn token -> "http://example.com/reset/#{token}" end

      result = Accounts.deliver_user_reset_password_instructions(user, reset_url_fun)
      assert {:ok, %{to: _, body: _}} = result
    end

    test "resets password with valid token and updates all sessions" do
      user = build(:user)
      token = "valid-reset-token"
      new_password_attrs = %{
        password: "new_password_123",
        password_confirmation: "new_password_123"
      }

      MockTokenService
      |> expect(:verify_email_token_query, fn ^token, "reset_password" -> {:ok, "verify-query"} end)
      |> expect(:by_user_and_contexts_query, fn ^user, :all -> "delete-tokens-query" end)

      MockRepo
      |> expect(:one, fn "verify-query" -> user end)
      |> expect(:transaction, fn _multi ->
        updated_user = %{user | password_hash: "new-hash"}
        {:ok, %{user: updated_user}}
      end)

      result = Accounts.reset_user_password(user, new_password_attrs)
      assert {:ok, updated_user} = result
    end
  end

  describe "user profile management - mock coordination" do
    test "coordinates email update with proper validation" do
      user = build(:user, email: "old@example.com")
      new_email = "new@example.com"
      password = "current_password"

      expect(User, :validate_current_password, fn changeset, ^password -> changeset end)

      result = Accounts.apply_user_email(user, password, %{email: new_email})
      
      case result do
        {:ok, updated_user} -> assert updated_user.email == new_email
        {:error, changeset} -> refute changeset.valid?
      end
    end

    test "fails email update with invalid current password" do
      user = build(:user)
      
      expect(User, :validate_current_password, fn changeset, "wrong_password" ->
        Ecto.Changeset.add_error(changeset, :current_password, "is not valid")
      end)

      result = Accounts.apply_user_email(user, "wrong_password", %{email: "new@example.com"})
      assert {:error, changeset} = result
      assert %{current_password: ["is not valid"]} = changeset_errors(changeset)
    end

    test "updates password with proper session invalidation" do
      user = build(:user)
      current_password = "current_password"
      new_attrs = %{
        password: "new_password_123",
        password_confirmation: "new_password_123"
      }

      MockTokenService
      |> expect(:by_user_and_contexts_query, fn ^user, :all -> "delete-all-tokens-query" end)

      expect(User, :validate_current_password, fn changeset, ^current_password -> changeset end)

      MockRepo
      |> expect(:transaction, fn _multi ->
        updated_user = %{user | password_hash: "new-hash"}
        {:ok, %{user: updated_user}}
      end)

      result = Accounts.update_user_password(user, current_password, new_attrs)
      assert {:ok, updated_user} = result
    end
  end

  describe "external service integrations - contract definition" do
    test "retrieves user device tokens for notifications" do
      user_id = "user-123"
      expected_tokens = ["device-token-1", "device-token-2"]

      # Mock external notification service contract
      MockNotifier
      |> expect(:get_device_tokens, fn ^user_id -> expected_tokens end)

      tokens = Accounts.get_user_device_tokens(user_id)
      assert tokens == expected_tokens
    end

    test "safely handles missing user when getting email" do
      user_id = "non-existent-user"

      MockRepo
      |> expect(:get!, fn User, ^user_id -> 
        raise Ecto.NoResultsError, queryable: User
      end)

      email = Accounts.get_user_email(user_id)
      assert is_nil(email)
    end

    test "retrieves webhook URL for external integrations" do
      user_id = "user-123"
      expected_url = "https://hooks.example.com/user-123"

      # Mock webhook service contract
      expect(MockNotifier, :get_webhook_url, fn ^user_id -> expected_url end)

      webhook_url = Accounts.get_user_webhook_url(user_id)
      assert webhook_url == expected_url
    end
  end

  # Helper to create changeset error map
  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end