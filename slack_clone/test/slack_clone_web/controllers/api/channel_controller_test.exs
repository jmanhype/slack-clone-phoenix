defmodule SlackCloneWeb.Api.ChannelControllerTest do
  @moduledoc """
  Comprehensive functional tests for channel API endpoints within workspaces.
  Tests channel creation, reading, updating, deletion, and user permissions.
  """
  use SlackCloneWeb.ConnCase, async: true
  use SlackClone.Factory

  import SlackClone.AccountsFixtures
  alias SlackClone.{Workspaces, Channels, Accounts}
  alias SlackClone.Guardian

  describe "POST /api/workspaces/:workspace_id/channels - Create channel" do
    setup :setup_authenticated_workspace

    test "creates public channel with valid data", %{conn: conn, workspace: workspace} do
      channel_attrs = %{
        name: "new-channel",
        description: "A test channel",
        is_private: false
      }

      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      
      assert %{
        "id" => channel_id,
        "name" => "new-channel",
        "description" => "A test channel",
        "is_private" => false,
        "workspace_id" => workspace_id,
        "created_by_id" => creator_id
      } = json_response(conn, 201)["data"]
      
      assert workspace_id == workspace.id
      assert channel_id != nil
      assert creator_id != nil
    end

    test "creates private channel", %{conn: conn, workspace: workspace} do
      channel_attrs = %{
        name: "private-channel",
        description: "A private channel",
        is_private: true
      }

      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      
      assert %{
        "name" => "private-channel",
        "is_private" => true
      } = json_response(conn, 201)["data"]
    end

    test "validates channel name format", %{conn: conn, workspace: workspace} do
      # Test invalid characters
      invalid_attrs = %{
        name: "Invalid Channel Name!",
        description: "Test"
      }

      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: invalid_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"name" => _} = errors
    end

    test "prevents duplicate channel names in same workspace", %{conn: conn, workspace: workspace} do
      # Create first channel
      first_attrs = %{name: "duplicate-test", description: "First"}
      post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: first_attrs)

      # Try to create second with same name
      second_attrs = %{name: "duplicate-test", description: "Second"}
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: second_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"name" => ["has already been taken"]} = errors
    end

    test "allows same channel name in different workspaces", %{conn: conn, workspace: workspace, user: user} do
      # Create channel in first workspace
      first_attrs = %{name: "shared-name", description: "First workspace"}
      post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: first_attrs)

      # Create second workspace
      workspace2 = insert(:workspace, owner: user)
      
      # Create channel with same name in second workspace
      second_attrs = %{name: "shared-name", description: "Second workspace"}
      conn = post(conn, ~p"/api/workspaces/#{workspace2.id}/channels", channel: second_attrs)
      
      assert %{"name" => "shared-name"} = json_response(conn, 201)["data"]
    end

    test "requires workspace membership", %{conn: conn} do
      other_user = insert(:user)
      other_workspace = insert(:workspace, owner: other_user)
      
      channel_attrs = %{name: "test-channel", description: "Test"}
      
      conn = post(conn, ~p"/api/workspaces/#{other_workspace.id}/channels", channel: channel_attrs)
      
      assert json_response(conn, 403)
    end

    test "validates required fields", %{conn: conn, workspace: workspace} do
      invalid_attrs = %{description: "Missing name"}
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: invalid_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"name" => ["can't be blank"]} = errors
    end
  end

  describe "GET /api/workspaces/:workspace_id/channels - List channels" do
    setup :setup_authenticated_workspace

    test "lists workspace channels for member", %{conn: conn, workspace: workspace, user: user} do
      # Create channels
      channel1 = insert(:channel, workspace: workspace, name: "general", is_private: false)
      channel2 = insert(:channel, workspace: workspace, name: "random", is_private: false)
      private_channel = insert(:channel, workspace: workspace, name: "private", is_private: true)
      
      # Add user to private channel
      insert(:channel_membership, channel: private_channel, user: user)

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels")
      
      channels = json_response(conn, 200)["data"]
      channel_names = Enum.map(channels, & &1["name"])
      
      assert length(channels) == 3
      assert "general" in channel_names
      assert "random" in channel_names
      assert "private" in channel_names
    end

    test "excludes private channels user is not member of", %{conn: conn, workspace: workspace} do
      # Create public and private channels
      insert(:channel, workspace: workspace, name: "general", is_private: false)
      insert(:channel, workspace: workspace, name: "private", is_private: true)

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels")
      
      channels = json_response(conn, 200)["data"]
      channel_names = Enum.map(channels, & &1["name"])
      
      assert length(channels) == 1
      assert "general" in channel_names
      assert "private" not in channel_names
    end

    test "includes channel metadata", %{conn: conn, workspace: workspace} do
      channel = insert(:channel, 
        workspace: workspace,
        name: "test-channel",
        description: "Test description",
        topic: "Test topic",
        is_private: false
      )

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels")
      
      [channel_data] = json_response(conn, 200)["data"]
      
      assert channel_data["id"] == channel.id
      assert channel_data["name"] == "test-channel"
      assert channel_data["description"] == "Test description"
      assert channel_data["topic"] == "Test topic"
      assert channel_data["is_private"] == false
      assert channel_data["member_count"] >= 0
    end

    test "requires workspace membership", %{conn: conn} do
      other_user = insert(:user)
      other_workspace = insert(:workspace, owner: other_user)
      
      conn = get(conn, ~p"/api/workspaces/#{other_workspace.id}/channels")
      
      assert json_response(conn, 403)
    end

    test "returns empty list for workspace with no channels", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels")
      
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "GET /api/workspaces/:workspace_id/channels/:id - Show channel" do
    setup :setup_authenticated_workspace

    test "shows public channel details", %{conn: conn, workspace: workspace} do
      channel = insert(:channel, workspace: workspace, is_private: false)
      
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}")
      
      assert %{
        "id" => channel_id,
        "name" => name,
        "description" => description,
        "workspace_id" => workspace_id,
        "is_private" => false
      } = json_response(conn, 200)["data"]
      
      assert channel_id == channel.id
      assert workspace_id == workspace.id
    end

    test "shows private channel for member", %{conn: conn, workspace: workspace, user: user} do
      channel = insert(:channel, workspace: workspace, is_private: true)
      insert(:channel_membership, channel: channel, user: user)
      
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}")
      
      assert %{"is_private" => true} = json_response(conn, 200)["data"]
    end

    test "returns 403 for private channel non-member", %{conn: conn, workspace: workspace} do
      channel = insert(:channel, workspace: workspace, is_private: true)
      
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}")
      
      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent channel", %{conn: conn, workspace: workspace} do
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/non-existent-id")
      
      assert json_response(conn, 404)
    end

    test "returns 404 for channel in different workspace", %{conn: conn, workspace: workspace} do
      other_workspace = insert(:workspace)
      other_channel = insert(:channel, workspace: other_workspace)
      
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{other_channel.id}")
      
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/workspaces/:workspace_id/channels/:id - Update channel" do
    setup :setup_authenticated_workspace

    test "updates channel as creator", %{conn: conn, workspace: workspace, user: user} do
      channel = insert(:channel, workspace: workspace, created_by: user)
      
      update_attrs = %{
        name: "updated-name",
        description: "Updated description",
        topic: "Updated topic"
      }
      
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}", channel: update_attrs)
      
      assert %{
        "name" => "updated-name",
        "description" => "Updated description",
        "topic" => "Updated topic"
      } = json_response(conn, 200)["data"]
    end

    test "updates channel as workspace admin", %{conn: conn, workspace: workspace, user: user} do
      other_user = insert(:user)
      channel = insert(:channel, workspace: workspace, created_by: other_user)
      insert(:workspace_membership, workspace: workspace, user: user, role: "admin")
      
      update_attrs = %{description: "Updated by admin"}
      
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}", channel: update_attrs)
      
      assert %{"description" => "Updated by admin"} = json_response(conn, 200)["data"]
    end

    test "returns 403 for regular member", %{conn: conn, workspace: workspace} do
      other_user = insert(:user)
      channel = insert(:channel, workspace: workspace, created_by: other_user)
      
      update_attrs = %{description: "Unauthorized update"}
      
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}", channel: update_attrs)
      
      assert json_response(conn, 403)
    end

    test "validates name format on update", %{conn: conn, workspace: workspace, user: user} do
      channel = insert(:channel, workspace: workspace, created_by: user)
      
      update_attrs = %{name: "Invalid Name!"}
      
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}", channel: update_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"name" => _} = errors
    end
  end

  describe "DELETE /api/workspaces/:workspace_id/channels/:id - Delete/Archive channel" do
    setup :setup_authenticated_workspace

    test "archives channel as creator", %{conn: conn, workspace: workspace, user: user} do
      channel = insert(:channel, workspace: workspace, created_by: user)
      
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}")
      
      assert response(conn, 204)
      
      # Verify channel is archived, not deleted
      updated_channel = Repo.get!(Channel, channel.id)
      assert updated_channel.is_archived == true
    end

    test "archives channel as workspace owner", %{conn: conn, workspace: workspace} do
      other_user = insert(:user)
      channel = insert(:channel, workspace: workspace, created_by: other_user)
      
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}")
      
      assert response(conn, 204)
    end

    test "preserves messages when archiving", %{conn: conn, workspace: workspace, user: user} do
      channel = insert(:channel, workspace: workspace, created_by: user)
      message = insert(:message, channel: channel)
      
      delete(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}")
      
      # Messages should still exist
      assert Repo.get!(Message, message.id)
    end

    test "returns 403 for regular member", %{conn: conn, workspace: workspace} do
      other_user = insert(:user)
      channel = insert(:channel, workspace: workspace, created_by: other_user)
      
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}")
      
      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent channel", %{conn: conn, workspace: workspace} do
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}/channels/non-existent-id")
      
      assert json_response(conn, 404)
    end
  end

  describe "Channel membership management" do
    setup :setup_authenticated_workspace

    test "auto-adds creator to channel", %{conn: conn, workspace: workspace, user: user} do
      channel_attrs = %{name: "auto-join-test", description: "Test auto-join"}
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      
      channel_id = json_response(conn, 201)["data"]["id"]
      
      # Verify user is automatically a member
      membership = Repo.get_by(ChannelMembership, channel_id: channel_id, user_id: user.id)
      assert membership != nil
      assert membership.role == "admin"
    end

    test "workspace owner automatically joins all channels", %{conn: conn, workspace: workspace, user: user} do
      other_user = insert(:user)
      insert(:workspace_membership, workspace: workspace, user: other_user, role: "member")
      
      # Other user creates channel
      {:ok, token, _} = Guardian.encode_and_sign(other_user)
      other_conn = 
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")
      
      channel_attrs = %{name: "owner-auto-join", description: "Test"}
      post(other_conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      
      # Verify workspace owner is automatically added
      channel = Repo.get_by!(Channel, name: "owner-auto-join")
      membership = Repo.get_by(ChannelMembership, channel_id: channel.id, user_id: user.id)
      assert membership != nil
    end

    test "private channel only includes invited members", %{conn: conn, workspace: workspace, user: user} do
      channel_attrs = %{
        name: "private-exclusive",
        description: "Private channel",
        is_private: true
      }
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      
      channel_id = json_response(conn, 201)["data"]["id"]
      
      # Only creator should be member
      memberships = Repo.all(from m in ChannelMembership, where: m.channel_id == ^channel_id)
      assert length(memberships) == 1
      assert List.first(memberships).user_id == user.id
    end
  end

  describe "Channel data validation and constraints" do
    setup :setup_authenticated_workspace

    test "validates name length constraints", %{conn: conn, workspace: workspace} do
      # Test maximum length (80 characters)
      long_name = String.duplicate("a", 81)
      long_name_attrs = %{name: long_name, description: "Test"}
      
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: long_name_attrs)
      
      assert %{"errors" => %{"name" => _}} = json_response(conn, 422)
    end

    test "validates name format constraints", %{conn: conn, workspace: workspace} do
      invalid_names = [
        "Channel With Spaces",
        "UPPERCASE-CHANNEL",
        "channel@symbol",
        "channel#hash",
        "channel.dot"
      ]
      
      for invalid_name <- invalid_names do
        attrs = %{name: invalid_name, description: "Test"}
        conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: attrs)
        
        assert %{"errors" => %{"name" => _}} = json_response(conn, 422)
      end
    end

    test "accepts valid name formats", %{conn: conn, workspace: workspace} do
      valid_names = [
        "channel-name",
        "channel_name",
        "channel123",
        "ch",
        "a"
      ]
      
      for valid_name <- valid_names do
        attrs = %{name: valid_name, description: "Test"}
        conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: attrs)
        
        assert %{"name" => ^valid_name} = json_response(conn, 201)["data"]
      end
    end

    test "handles concurrent channel creation", %{conn: conn, workspace: workspace} do
      channel_attrs = %{name: "concurrent-test", description: "Testing concurrency"}
      
      # Simulate concurrent requests
      tasks = 
        1..5
        |> Enum.map(fn _i ->
          Task.async(fn ->
            post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
          end)
        end)
        |> Enum.map(&Task.await/1)
      
      successful_requests = Enum.count(tasks, &(&1.status == 201))
      failed_requests = Enum.count(tasks, &(&1.status == 422))
      
      # Only one should succeed due to unique constraint
      assert successful_requests == 1
      assert failed_requests == 4
    end
  end

  describe "Cross-workspace channel access prevention" do
    setup :setup_authenticated_workspace

    test "prevents accessing channels from different workspace", %{conn: conn, user: user} do
      # Create second workspace and channel
      other_workspace = insert(:workspace)
      other_channel = insert(:channel, workspace: other_workspace)
      
      # User should not be able to access channel from different workspace
      conn = get(conn, ~p"/api/workspaces/#{other_workspace.id}/channels/#{other_channel.id}")
      assert json_response(conn, 403)
      
      # Even if trying to access via wrong workspace ID
      conn = get(conn, ~p"/api/workspaces/999/channels/#{other_channel.id}")
      assert json_response(conn, 404)
    end

    test "prevents channel operations across workspaces", %{conn: conn, workspace: workspace} do
      other_workspace = insert(:workspace)
      other_channel = insert(:channel, workspace: other_workspace)
      
      # Cannot update channel from different workspace
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{other_channel.id}", 
                channel: %{name: "hacked"})
      assert json_response(conn, 404)
      
      # Cannot delete channel from different workspace
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{other_channel.id}")
      assert json_response(conn, 404)
    end
  end

  # Test helper functions
  defp setup_authenticated_workspace(_context) do
    user = insert(:user)
    workspace = insert(:workspace, owner: user)
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    
    conn = 
      build_conn()
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")
    
    %{conn: conn, user: user, workspace: workspace, token: token}
  end
end