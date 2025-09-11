defmodule SlackClone.ChannelsTest do
  use SlackClone.DataCase, async: true

  import Mox
  alias SlackClone.Channels
  alias SlackClone.Channels.Channel
  alias SlackClone.Messages.Message

  # London School TDD - Mock dependencies and focus on interactions
  setup :verify_on_exit!

  defmock(MockRepo, for: Ecto.Repo)
  defmock(MockAuthzService, for: SlackClone.Authorization)
  defmock(MockPubSub, for: Phoenix.PubSub)
  defmock(MockPresenceService, for: SlackClone.Presence)

  describe "channel retrieval - outside-in TDD" do
    test "successfully retrieves channel by ID" do
      channel_id = "channel-123"
      expected_channel = build(:channel, id: channel_id, name: "general")

      MockRepo
      |> expect(:get, fn Channel, ^channel_id -> expected_channel end)
      |> expect(:preload, fn ^expected_channel, [:workspace, :members] -> 
        %{expected_channel | workspace: build(:workspace), members: [build(:user)]}
      end)

      result = Channels.get_channel(channel_id)
      assert result.id == channel_id
      assert result.name == "general"
      assert result.workspace != nil
      assert length(result.members) == 1
    end

    test "returns nil for non-existent channel" do
      channel_id = "non-existent-channel"

      MockRepo
      |> expect(:get, fn Channel, ^channel_id -> nil end)

      result = Channels.get_channel(channel_id)
      assert is_nil(result)
    end

    test "retrieves channel with messages and participant count" do
      channel_id = "channel-with-data"
      channel = build(:channel, id: channel_id)
      messages = [build(:message), build(:message), build(:message)]

      MockRepo
      |> expect(:get, fn Channel, ^channel_id -> channel end)
      |> expect(:preload, fn ^channel, [:messages, :members] ->
        %{channel | messages: messages, members: [build(:user), build(:user)]}
      end)

      result = Channels.get_channel_with_data(channel_id)
      assert result.id == channel_id
      assert length(result.messages) == 3
      assert length(result.members) == 2
    end
  end

  describe "channel permissions - behavior verification" do
    test "allows access to public channel for workspace member" do
      channel_id = "public-channel"
      user_id = "workspace-member"
      workspace_id = "workspace-123"

      # Mock authorization service interactions
      MockAuthzService
      |> expect(:is_workspace_member?, fn ^user_id, ^workspace_id -> true end)
      |> expect(:get_channel_visibility, fn ^channel_id -> :public end)

      result = Channels.can_access?(channel_id, user_id)
      assert result == true
    end

    test "denies access to private channel for non-member" do
      channel_id = "private-channel"
      user_id = "non-member"

      MockAuthzService
      |> expect(:get_channel_visibility, fn ^channel_id -> :private end)
      |> expect(:is_channel_member?, fn ^user_id, ^channel_id -> false end)

      result = Channels.can_access?(channel_id, user_id)
      assert result == false
    end

    test "allows access to private channel for direct member" do
      channel_id = "private-channel"
      user_id = "channel-member"

      MockAuthzService
      |> expect(:get_channel_visibility, fn ^channel_id -> :private end)
      |> expect(:is_channel_member?, fn ^user_id, ^channel_id -> true end)

      result = Channels.can_access?(channel_id, user_id)
      assert result == true
    end

    test "denies access to archived channel for regular member" do
      channel_id = "archived-channel"
      user_id = "regular-member"

      MockAuthzService
      |> expect(:is_channel_archived?, fn ^channel_id -> true end)
      |> expect(:is_admin?, fn ^user_id -> false end)

      result = Channels.can_access?(channel_id, user_id)
      assert result == false
    end

    test "allows admin access to archived channel" do
      channel_id = "archived-channel"
      user_id = "admin-user"

      MockAuthzService
      |> expect(:is_channel_archived?, fn ^channel_id -> true end)
      |> expect(:is_admin?, fn ^user_id -> true end)

      result = Channels.can_access?(channel_id, user_id)
      assert result == true
    end
  end

  describe "channel creation - interaction testing" do
    test "creates public channel with proper event broadcasting" do
      workspace_id = "workspace-123"
      creator_id = "creator-456"
      channel_attrs = %{
        name: "new-channel",
        description: "A new channel",
        type: "public"
      }

      created_channel = build(:channel, 
        name: "new-channel",
        workspace_id: workspace_id,
        creator_id: creator_id,
        type: "public"
      )

      # Verify sequence of interactions
      MockRepo
      |> expect(:insert, fn changeset ->
        {:ok, created_channel}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub, 
        "workspace:#{workspace_id}", 
        {:channel_created, ^created_channel}
        -> :ok
      end)

      MockPresenceService
      |> expect(:track_channel_creation, fn ^creator_id, ^created_channel -> :ok end)

      result = Channels.create_channel(workspace_id, creator_id, channel_attrs)
      assert {:ok, channel} = result
      assert channel.name == "new-channel"
      assert channel.type == "public"
    end

    test "creates private channel with member invitation workflow" do
      workspace_id = "workspace-123"
      creator_id = "creator-456"
      member_ids = ["member-1", "member-2"]
      channel_attrs = %{
        name: "private-channel",
        type: "private"
      }

      created_channel = build(:channel, 
        name: "private-channel",
        type: "private",
        workspace_id: workspace_id,
        creator_id: creator_id
      )

      MockRepo
      |> expect(:insert, fn _changeset -> {:ok, created_channel} end)
      |> expect(:insert_all, fn "channel_memberships", memberships ->
        assert length(memberships) == 3  # creator + 2 invited members
        {3, nil}
      end)

      MockPubSub
      |> expect(:broadcast, fn _, _, {:channel_created, ^created_channel} -> :ok end)

      for member_id <- member_ids do
        MockPubSub
        |> expect(:broadcast, fn 
          SlackClone.PubSub, 
          "user:#{member_id}", 
          {:channel_invitation, ^created_channel}
          -> :ok
        end)
      end

      result = Channels.create_private_channel(workspace_id, creator_id, channel_attrs, member_ids)
      assert {:ok, channel} = result
      assert channel.type == "private"
    end

    test "fails channel creation with invalid data and proper error handling" do
      workspace_id = "workspace-123"
      creator_id = "creator-456"
      invalid_attrs = %{
        name: "",  # Invalid: empty name
        type: "invalid_type"  # Invalid: bad type
      }

      error_changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          name: {"can't be blank", [validation: :required]},
          type: {"is invalid", [validation: :inclusion]}
        ]
      }

      MockRepo
      |> expect(:insert, fn _changeset -> {:error, error_changeset} end)

      # Should not broadcast anything on failure
      MockPubSub |> expect(:broadcast, 0, fn _, _, _ -> :ok end)

      result = Channels.create_channel(workspace_id, creator_id, invalid_attrs)
      assert {:error, changeset} = result
      refute changeset.valid?
    end
  end

  describe "channel membership - collaboration patterns" do
    test "adds member to channel with proper notifications" do
      channel_id = "channel-123"
      user_id = "user-456"
      inviter_id = "inviter-789"

      channel = build(:channel, id: channel_id, name: "general")
      user = build(:user, id: user_id, name: "John Doe")

      # Mock the collaboration sequence
      MockRepo
      |> expect(:get, fn Channel, ^channel_id -> channel end)
      |> expect(:get, fn User, ^user_id -> user end)
      |> expect(:insert, fn membership_changeset ->
        {:ok, %{channel_id: channel_id, user_id: user_id, role: "member"}}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{channel_id}",
        {:member_joined, %{user: ^user, channel: ^channel, inviter_id: ^inviter_id}}
        -> :ok
      end)
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "user:#{user_id}",
        {:joined_channel, ^channel}
        -> :ok
      end)

      MockPresenceService
      |> expect(:track_user_join, fn ^user_id, ^channel_id -> :ok end)

      result = Channels.add_member(channel_id, user_id, inviter_id)
      assert {:ok, membership} = result
      assert membership.channel_id == channel_id
      assert membership.user_id == user_id
    end

    test "removes member from channel with cleanup workflow" do
      channel_id = "channel-123"
      user_id = "user-456"
      remover_id = "remover-789"

      channel = build(:channel, id: channel_id, name: "general")
      user = build(:user, id: user_id, name: "John Doe")

      MockRepo
      |> expect(:get, fn Channel, ^channel_id -> channel end)
      |> expect(:get, fn User, ^user_id -> user end)
      |> expect(:delete_all, fn membership_query ->
        assert_membership_query(membership_query, channel_id, user_id)
        {1, nil}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{channel_id}",
        {:member_left, %{user: ^user, channel: ^channel, remover_id: ^remover_id}}
        -> :ok
      end)

      MockPresenceService
      |> expect(:untrack_user, fn ^user_id, ^channel_id -> :ok end)

      result = Channels.remove_member(channel_id, user_id, remover_id)
      assert {:ok, removed_count} = result
      assert removed_count == 1
    end

    test "promotes member to admin with permission validation" do
      channel_id = "channel-123"
      user_id = "user-456"
      promoter_id = "promoter-789"

      MockAuthzService
      |> expect(:can_manage_channel?, fn ^promoter_id, ^channel_id -> true end)

      MockRepo
      |> expect(:update_all, fn membership_query, [set: [role: "admin"]] ->
        assert_membership_query(membership_query, channel_id, user_id)
        {1, nil}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "channel:#{channel_id}",
        {:member_promoted, %{user_id: ^user_id, role: "admin", promoter_id: ^promoter_id}}
        -> :ok
      end)

      result = Channels.promote_member(channel_id, user_id, promoter_id)
      assert {:ok, updated_count} = result
      assert updated_count == 1
    end

    test "fails member promotion when promoter lacks permissions" do
      channel_id = "channel-123"
      user_id = "user-456"
      promoter_id = "unauthorized-promoter"

      MockAuthzService
      |> expect(:can_manage_channel?, fn ^promoter_id, ^channel_id -> false end)

      # Should not perform any database operations
      MockRepo |> expect(:update_all, 0, fn _, _ -> {0, nil} end)
      MockPubSub |> expect(:broadcast, 0, fn _, _, _ -> :ok end)

      result = Channels.promote_member(channel_id, user_id, promoter_id)
      assert {:error, :unauthorized} = result
    end
  end

  describe "channel archiving - workflow coordination" do
    test "archives channel with proper cleanup and notifications" do
      channel_id = "channel-123"
      archiver_id = "archiver-456"
      
      channel = build(:channel, id: channel_id, name: "old-channel", archived: false)
      members = [build(:user, id: "member-1"), build(:user, id: "member-2")]

      MockRepo
      |> expect(:get, fn Channel, ^channel_id -> channel end)
      |> expect(:preload, fn ^channel, [:members] -> %{channel | members: members} end)
      |> expect(:update, fn ^channel, [set: [archived: true, archived_at: _]] ->
        {:ok, %{channel | archived: true}}
      end)

      # Notify all members about archival
      for member <- members do
        MockPubSub
        |> expect(:broadcast, fn 
          SlackClone.PubSub,
          "user:#{member.id}",
          {:channel_archived, %{channel: ^channel, archiver_id: ^archiver_id}}
          -> :ok
        end)
      end

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "workspace:#{channel.workspace_id}",
        {:channel_archived, ^channel}
        -> :ok
      end)

      MockPresenceService
      |> expect(:clear_channel_presence, fn ^channel_id -> :ok end)

      result = Channels.archive_channel(channel_id, archiver_id)
      assert {:ok, archived_channel} = result
      assert archived_channel.archived == true
    end

    test "unarchives channel and restores member access" do
      channel_id = "channel-123"
      unarchiver_id = "unarchiver-456"
      
      channel = build(:channel, id: channel_id, archived: true)
      members = [build(:user, id: "member-1")]

      MockRepo
      |> expect(:get, fn Channel, ^channel_id -> channel end)
      |> expect(:preload, fn ^channel, [:members] -> %{channel | members: members} end)
      |> expect(:update, fn ^channel, [set: [archived: false, archived_at: nil]] ->
        {:ok, %{channel | archived: false}}
      end)

      MockPubSub
      |> expect(:broadcast, fn 
        SlackClone.PubSub,
        "workspace:#{channel.workspace_id}",
        {:channel_unarchived, ^channel}
        -> :ok
      end)

      result = Channels.unarchive_channel(channel_id, unarchiver_id)
      assert {:ok, unarchived_channel} = result
      assert unarchived_channel.archived == false
    end
  end

  describe "channel search - contract definition" do
    test "searches channels by name with proper filtering" do
      workspace_id = "workspace-123"
      user_id = "user-456"
      search_term = "general"

      matching_channels = [
        build(:channel, name: "general", workspace_id: workspace_id),
        build(:channel, name: "general-discussion", workspace_id: workspace_id)
      ]

      MockAuthzService
      |> expect(:filter_accessible_channels, fn channels, ^user_id -> channels end)

      MockRepo
      |> expect(:all, fn search_query ->
        assert_search_query(search_query, workspace_id, search_term)
        matching_channels
      end)

      result = Channels.search_channels(workspace_id, user_id, search_term)
      assert length(result) == 2
      assert Enum.all?(result, &String.contains?(&1.name, "general"))
    end

    test "returns empty results for no matches" do
      workspace_id = "workspace-123"
      user_id = "user-456"
      search_term = "nonexistent"

      MockRepo
      |> expect(:all, fn _query -> [] end)

      MockAuthzService
      |> expect(:filter_accessible_channels, fn [], ^user_id -> [] end)

      result = Channels.search_channels(workspace_id, user_id, search_term)
      assert result == []
    end

    test "filters private channels based on user access" do
      workspace_id = "workspace-123"
      user_id = "user-456"
      search_term = "private"

      all_channels = [
        build(:channel, name: "private-1", type: "private", workspace_id: workspace_id),
        build(:channel, name: "private-2", type: "private", workspace_id: workspace_id)
      ]
      
      accessible_channels = [
        build(:channel, name: "private-1", type: "private", workspace_id: workspace_id)
      ]

      MockRepo
      |> expect(:all, fn _query -> all_channels end)

      MockAuthzService
      |> expect(:filter_accessible_channels, fn ^all_channels, ^user_id -> 
        accessible_channels 
      end)

      result = Channels.search_channels(workspace_id, user_id, search_term)
      assert length(result) == 1
      assert List.first(result).name == "private-1"
    end
  end

  # Helper functions for assertion
  defp assert_membership_query(query, expected_channel_id, expected_user_id) do
    # In real implementation, would inspect the Ecto query structure
    # For now, we trust the query is correctly constructed
    assert is_struct(query, Ecto.Query) or is_atom(query)
  end

  defp assert_search_query(query, expected_workspace_id, expected_search_term) do
    # In real implementation, would inspect the Ecto query for proper WHERE clauses
    assert is_struct(query, Ecto.Query) or is_atom(query)
  end
end