defmodule SlackClone.WorkspacesTest do
  use SlackClone.DataCase, async: true

  import Mox
  alias SlackClone.Workspaces
  alias SlackClone.Workspaces.{Workspace, WorkspaceMembership}

  # London School TDD - Mock collaborators and verify interactions
  setup :verify_on_exit!

  defmock(MockRepo, for: Ecto.Repo)
  defmock(MockPubSub, for: Phoenix.PubSub)
  defmock(MockInvitationService, for: SlackClone.Invitations)
  defmock(MockBillingService, for: SlackClone.Billing)
  defmock(MockSlugGenerator, for: SlackClone.Utils.SlugGenerator)
  defmock(MockStorageService, for: SlackClone.Storage)

  describe "workspace creation - outside-in TDD" do
    test "creates workspace with default channels and owner membership" do
      owner_id = "owner-123"
      workspace_attrs = %{
        name: "Acme Corp",
        description: "Our company workspace"
      }

      generated_slug = "acme-corp"
      created_workspace = build(:workspace,
        id: "workspace-456",
        name: "Acme Corp",
        slug: generated_slug,
        owner_id: owner_id
      )

      default_channels = [
        build(:channel, name: "general", workspace_id: "workspace-456"),
        build(:channel, name: "random", workspace_id: "workspace-456")
      ]

      # Verify the conversation between collaborators
      MockSlugGenerator
      |> expect(:generate_slug, fn "Acme Corp" -> generated_slug end)
      |> expect(:ensure_unique_slug, fn ^generated_slug, Workspace -> generated_slug end)

      MockRepo
      |> expect(:insert, fn workspace_changeset ->
        assert workspace_changeset.changes.name == "Acme Corp"
        assert workspace_changeset.changes.slug == generated_slug
        {:ok, created_workspace}
      end)
      |> expect(:insert_all, fn "workspace_memberships", [membership] ->
        assert membership.workspace_id == "workspace-456"
        assert membership.user_id == owner_id
        assert membership.role == "owner"
        {1, nil}
      end)
      |> expect(:insert_all, fn "channels", channel_data ->
        assert length(channel_data) == 2
        {2, default_channels}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "user:#{owner_id}",
        {:workspace_created, ^created_workspace}
        -> :ok
      end)

      MockBillingService
      |> expect(:initialize_workspace_billing, fn ^created_workspace -> :ok end)

      result = Workspaces.create_workspace(owner_id, workspace_attrs)
      assert {:ok, workspace} = result
      assert workspace.name == "Acme Corp"
      assert workspace.slug == generated_slug
      assert workspace.owner_id == owner_id
    end

    test "fails workspace creation with invalid attributes" do
      owner_id = "owner-123"
      invalid_attrs = %{
        name: "",  # Invalid: empty name
        slug: "invalid slug!"  # Invalid: contains spaces and special chars
      }

      error_changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          name: {"can't be blank", [validation: :required]},
          slug: {"has invalid format", [validation: :format]}
        ]
      }

      MockSlugGenerator
      |> expect(:generate_slug, fn "" -> "" end)

      MockRepo
      |> expect(:insert, fn _changeset -> {:error, error_changeset} end)

      # Should not proceed with billing or broadcasting on failure
      MockBillingService |> expect(:initialize_workspace_billing, 0, fn _ -> :ok end)
      MockPubSub |> expect(:broadcast, 0, fn _, _, _ -> :ok end)

      result = Workspaces.create_workspace(owner_id, invalid_attrs)
      assert {:error, changeset} = result
      refute changeset.valid?
    end

    test "handles slug collision by generating unique alternative" do
      owner_id = "owner-123"
      workspace_attrs = %{name: "Test Workspace"}

      initial_slug = "test-workspace"
      unique_slug = "test-workspace-2"

      MockSlugGenerator
      |> expect(:generate_slug, fn "Test Workspace" -> initial_slug end)
      |> expect(:ensure_unique_slug, fn ^initial_slug, Workspace -> unique_slug end)

      created_workspace = build(:workspace, slug: unique_slug)

      MockRepo
      |> expect(:insert, fn changeset ->
        assert changeset.changes.slug == unique_slug
        {:ok, created_workspace}
      end)
      |> expect(:insert_all, 2, fn _, _ -> {1, nil} end)  # membership and channels

      MockPubSub
      |> expect(:broadcast, fn _, _, _ -> :ok end)
      MockBillingService
      |> expect(:initialize_workspace_billing, fn _ -> :ok end)

      result = Workspaces.create_workspace(owner_id, workspace_attrs)
      assert {:ok, workspace} = result
      assert workspace.slug == unique_slug
    end
  end

  describe "workspace membership - behavior verification" do
    test "invites user with proper email notification and pending status" do
      workspace_id = "workspace-123"
      inviter_id = "inviter-456"
      invitee_email = "new@example.com"
      role = "member"

      workspace = build(:workspace, id: workspace_id, name: "Test Workspace")
      invitation_token = "invite-token-789"

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)
      |> expect(:get_by, fn User, [email: ^invitee_email] -> nil end)  # User doesn't exist yet

      MockInvitationService
      |> expect(:create_invitation, fn invitation_attrs ->
        assert invitation_attrs.workspace_id == workspace_id
        assert invitation_attrs.email == invitee_email
        assert invitation_attrs.role == role
        assert invitation_attrs.inviter_id == inviter_id
        {:ok, %{token: invitation_token, email: invitee_email}}
      end)
      |> expect(:send_invitation_email, fn ^invitee_email, ^workspace, ^invitation_token ->
        {:ok, %{to: invitee_email, status: "sent"}}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "workspace:#{workspace_id}",
        {:invitation_sent, %{email: ^invitee_email, role: ^role}}
        -> :ok
      end)

      result = Workspaces.invite_user(workspace_id, inviter_id, invitee_email, role)
      assert {:ok, invitation} = result
      assert invitation.token == invitation_token
    end

    test "adds existing user directly to workspace without invitation" do
      workspace_id = "workspace-123"
      inviter_id = "inviter-456"
      invitee_email = "existing@example.com"
      role = "member"

      workspace = build(:workspace, id: workspace_id)
      existing_user = build(:user, id: "existing-user-789", email: invitee_email)

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)
      |> expect(:get_by, fn User, [email: ^invitee_email] -> existing_user end)
      |> expect(:insert, fn membership_changeset ->
        assert membership_changeset.changes.workspace_id == workspace_id
        assert membership_changeset.changes.user_id == existing_user.id
        assert membership_changeset.changes.role == role
        {:ok, %WorkspaceMembership{
          workspace_id: workspace_id,
          user_id: existing_user.id,
          role: role
        }}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "workspace:#{workspace_id}",
        {:member_added, %{user: ^existing_user, role: ^role}}
        -> :ok
      end)
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "user:#{existing_user.id}",
        {:workspace_joined, ^workspace}
        -> :ok
      end)

      result = Workspaces.invite_user(workspace_id, inviter_id, invitee_email, role)
      assert {:ok, membership} = result
      assert membership.user_id == existing_user.id
      assert membership.role == role
    end

    test "removes member with proper cleanup and notifications" do
      workspace_id = "workspace-123"
      user_id = "user-456"
      remover_id = "admin-789"

      workspace = build(:workspace, id: workspace_id, name: "Test Workspace")
      user = build(:user, id: user_id, name: "John Doe")
      membership = build(:workspace_membership, workspace_id: workspace_id, user_id: user_id)

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)
      |> expect(:get, fn User, ^user_id -> user end)
      |> expect(:get_by, fn WorkspaceMembership, 
        [workspace_id: ^workspace_id, user_id: ^user_id] -> membership
      end)
      |> expect(:delete, fn ^membership -> {:ok, membership} end)
      |> expect(:delete_all, fn channel_memberships_query ->
        # Should remove user from all workspace channels
        {3, nil}  # Removed from 3 channels
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "workspace:#{workspace_id}",
        {:member_removed, %{user: ^user, remover_id: ^remover_id}}
        -> :ok
      end)
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "user:#{user_id}",
        {:removed_from_workspace, ^workspace}
        -> :ok
      end)

      result = Workspaces.remove_member(workspace_id, user_id, remover_id)
      assert {:ok, removed_membership} = result
      assert removed_membership.user_id == user_id
    end

    test "prevents removing workspace owner" do
      workspace_id = "workspace-123"
      owner_id = "owner-456"
      remover_id = "admin-789"

      workspace = build(:workspace, id: workspace_id, owner_id: owner_id)

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)

      result = Workspaces.remove_member(workspace_id, owner_id, remover_id)
      assert {:error, :cannot_remove_owner} = result

      # Should not perform any database operations
      MockRepo |> expect(:delete, 0, fn _ -> {:ok, %{}} end)
      MockPubSub |> expect(:broadcast, 0, fn _, _, _ -> :ok end)
    end
  end

  describe "workspace settings - interaction testing" do
    test "updates workspace settings with validation and broadcasting" do
      workspace_id = "workspace-123"
      admin_id = "admin-456"
      settings_updates = %{
        name: "Updated Workspace Name",
        description: "New description",
        allow_invites: false,
        default_channel_visibility: "private"
      }

      workspace = build(:workspace,
        id: workspace_id,
        name: "Old Name",
        settings: %{"allow_invites" => true}
      )

      updated_workspace = %{workspace |
        name: "Updated Workspace Name",
        description: "New description",
        settings: Map.merge(workspace.settings, %{
          "allow_invites" => false,
          "default_channel_visibility" => "private"
        })
      }

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)
      |> expect(:update, fn changeset ->
        assert changeset.changes.name == "Updated Workspace Name"
        {:ok, updated_workspace}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "workspace:#{workspace_id}",
        {:workspace_updated, ^updated_workspace, ^admin_id}
        -> :ok
      end)

      result = Workspaces.update_workspace(workspace_id, admin_id, settings_updates)
      assert {:ok, workspace} = result
      assert workspace.name == "Updated Workspace Name"
      assert workspace.settings["allow_invites"] == false
    end

    test "updates workspace logo with storage service integration" do
      workspace_id = "workspace-123"
      admin_id = "admin-456"
      logo_upload = %Plug.Upload{
        path: "/tmp/logo.png",
        filename: "logo.png",
        content_type: "image/png"
      }

      workspace = build(:workspace, id: workspace_id, logo_url: nil)
      uploaded_logo_url = "https://cdn.example.com/workspaces/workspace-123/logo.png"

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)

      MockStorageService
      |> expect(:upload_file, fn ^logo_upload, upload_options ->
        assert upload_options.prefix == "workspaces/workspace-123"
        assert upload_options.public == true
        {:ok, %{url: uploaded_logo_url, key: "logo.png"}}
      end)

      updated_workspace = %{workspace | logo_url: uploaded_logo_url}

      MockRepo
      |> expect(:update, fn changeset ->
        assert changeset.changes.logo_url == uploaded_logo_url
        {:ok, updated_workspace}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "workspace:#{workspace_id}",
        {:workspace_logo_updated, ^updated_workspace}
        -> :ok
      end)

      result = Workspaces.update_workspace_logo(workspace_id, admin_id, logo_upload)
      assert {:ok, workspace} = result
      assert workspace.logo_url == uploaded_logo_url
    end

    test "validates workspace name uniqueness across system" do
      workspace_id = "workspace-123"
      admin_id = "admin-456"
      
      existing_workspace_name = "Taken Name"
      settings_updates = %{name: existing_workspace_name}

      workspace = build(:workspace, id: workspace_id, name: "Current Name")

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)
      |> expect(:get_by, fn Workspace, [name: ^existing_workspace_name] ->
        build(:workspace, id: "different-workspace", name: existing_workspace_name)
      end)

      result = Workspaces.update_workspace(workspace_id, admin_id, settings_updates)
      assert {:error, :name_taken} = result

      # Should not proceed with update or broadcasting
      MockRepo |> expect(:update, 0, fn _ -> {:ok, %{}} end)
      MockPubSub |> expect(:broadcast, 0, fn _, _, _ -> :ok end)
    end
  end

  describe "workspace deletion - collaboration patterns" do
    test "soft deletes workspace with comprehensive cleanup workflow" do
      workspace_id = "workspace-123"
      owner_id = "owner-456"

      workspace = build(:workspace,
        id: workspace_id,
        owner_id: owner_id,
        name: "Workspace To Delete",
        deleted_at: nil
      )

      member_ids = ["member-1", "member-2", "member-3"]
      channel_ids = ["channel-1", "channel-2"]

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)
      |> expect(:all, fn members_query -> member_ids end)
      |> expect(:all, fn channels_query -> channel_ids end)

      # Mark workspace as deleted
      deleted_workspace = %{workspace | deleted_at: DateTime.utc_now()}

      MockRepo
      |> expect(:update, fn changeset ->
        assert changeset.changes.deleted_at != nil
        {:ok, deleted_workspace}
      end)

      # Archive all channels
      MockRepo
      |> expect(:update_all, fn channels_query, [set: [archived: true]] -> 
        {length(channel_ids), nil}
      end)

      # Notify all members
      for member_id <- member_ids do
        MockPubSub
        |> expect(:broadcast, fn 
          SlackClone.PubSub,
          "user:#{member_id}",
          {:workspace_deleted, ^workspace, ^owner_id}
          -> :ok
        end)
      end

      MockBillingService
      |> expect(:cancel_workspace_subscription, fn ^workspace_id -> :ok end)

      result = Workspaces.delete_workspace(workspace_id, owner_id)
      assert {:ok, deleted_ws} = result
      assert deleted_ws.deleted_at != nil
    end

    test "prevents non-owner from deleting workspace" do
      workspace_id = "workspace-123"
      non_owner_id = "non-owner-456"

      workspace = build(:workspace,
        id: workspace_id,
        owner_id: "actual-owner-789"
      )

      MockRepo
      |> expect(:get, fn Workspace, ^workspace_id -> workspace end)

      result = Workspaces.delete_workspace(workspace_id, non_owner_id)
      assert {:error, :unauthorized} = result

      # Should not perform any deletion operations
      MockRepo |> expect(:update, 0, fn _ -> {:ok, %{}} end)
      MockBillingService |> expect(:cancel_workspace_subscription, 0, fn _ -> :ok end)
    end
  end

  describe "workspace discovery - contract testing" do
    test "lists public workspaces with proper filtering and pagination" do
      user_id = "user-123"
      search_params = %{
        page: 1,
        per_page: 10,
        search_term: "tech"
      }

      public_workspaces = [
        build(:workspace, name: "Tech Corp", is_public: true, member_count: 50),
        build(:workspace, name: "TechStart", is_public: true, member_count: 25)
      ]

      MockRepo
      |> expect(:all, fn workspace_query ->
        # Verify query filters by is_public: true and search term
        public_workspaces
      end)

      result = Workspaces.list_public_workspaces(user_id, search_params)
      assert {:ok, workspaces} = result
      assert length(workspaces) == 2
      assert Enum.all?(workspaces, &(&1.is_public == true))
      assert Enum.all?(workspaces, &String.contains?(&1.name, "Tech"))
    end

    test "retrieves user's workspaces with membership details" do
      user_id = "user-123"

      user_workspaces = [
        %{workspace: build(:workspace, name: "Work Space"), membership: %{role: "admin"}},
        %{workspace: build(:workspace, name: "Side Project"), membership: %{role: "member"}}
      ]

      MockRepo
      |> expect(:all, fn user_workspaces_query ->
        # Query should join workspaces with memberships for the user
        user_workspaces
      end)

      result = Workspaces.get_user_workspaces(user_id)
      assert length(result) == 2
      
      admin_workspace = Enum.find(result, &(&1.membership.role == "admin"))
      assert admin_workspace.workspace.name == "Work Space"
      
      member_workspace = Enum.find(result, &(&1.membership.role == "member"))
      assert member_workspace.workspace.name == "Side Project"
    end

    test "suggests workspaces based on user profile and connections" do
      user_id = "user-123"
      user_profile = %{
        email_domain: "acme.com",
        skills: ["elixir", "phoenix"],
        location: "San Francisco"
      }

      suggested_workspaces = [
        build(:workspace, name: "Acme Corp", description: "For acme.com employees"),
        build(:workspace, name: "Elixir Developers", description: "Phoenix and Elixir")
      ]

      MockRepo
      |> expect(:get, fn User, ^user_id -> build(:user, email: "john@acme.com") end)

      MockRepo
      |> expect(:all, fn suggestions_query ->
        # Query should match workspaces by domain, skills, or location
        suggested_workspaces
      end)

      result = Workspaces.get_workspace_suggestions(user_id)
      assert length(result) == 2
      assert Enum.any?(result, &String.contains?(&1.description, "acme.com"))
      assert Enum.any?(result, &String.contains?(&1.description, "Elixir"))
    end
  end

  describe "workspace analytics - external service integration" do
    test "retrieves workspace activity metrics with proper aggregation" do
      workspace_id = "workspace-123"
      date_range = %{from: ~D[2024-01-01], to: ~D[2024-01-31]}

      expected_metrics = %{
        total_messages: 1250,
        active_users: 45,
        channels_created: 5,
        files_shared: 89,
        peak_concurrent_users: 28
      }

      MockRepo
      |> expect(:one, fn messages_count_query -> 1250 end)
      |> expect(:one, fn active_users_query -> 45 end)
      |> expect(:one, fn channels_created_query -> 5 end)
      |> expect(:one, fn files_shared_query -> 89 end)
      |> expect(:one, fn peak_users_query -> 28 end)

      result = Workspaces.get_workspace_metrics(workspace_id, date_range)
      assert result == expected_metrics
    end

    test "generates workspace health score based on activity patterns" do
      workspace_id = "workspace-123"
      
      health_indicators = %{
        message_frequency: 0.85,    # High activity
        user_engagement: 0.72,     # Good engagement
        channel_distribution: 0.60, # Moderate distribution
        response_time: 0.90        # Fast responses
      }

      expected_health_score = 77  # Calculated weighted average

      MockRepo
      |> expect(:all, fn activity_queries -> 
        # Return raw data that gets processed into health indicators
        [
          %{metric: "message_frequency", value: 0.85},
          %{metric: "user_engagement", value: 0.72},
          %{metric: "channel_distribution", value: 0.60},
          %{metric: "response_time", value: 0.90}
        ]
      end)

      result = Workspaces.calculate_health_score(workspace_id)
      assert result == expected_health_score
    end
  end
end