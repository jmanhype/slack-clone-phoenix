defmodule SlackCloneWeb.Api.WorkspaceControllerTest do
  @moduledoc """
  Comprehensive functional tests for workspace API endpoints.
  Tests workspace creation, reading, updating, deletion, and user permissions.
  """
  use SlackCloneWeb.ConnCase, async: true
  use SlackClone.Factory

  import SlackClone.AccountsFixtures
  alias SlackClone.{Workspaces, Accounts}
  alias SlackClone.Guardian

  describe "POST /api/workspaces - Create workspace" do
    setup :setup_authenticated_user

    test "creates workspace with valid data", %{conn: conn, user: user} do
      workspace_attrs = %{
        name: "New Workspace",
        description: "A workspace for testing",
        is_public: false
      }

      conn = post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
      
      assert %{
        "id" => workspace_id,
        "name" => "New Workspace",
        "description" => "A workspace for testing",
        "is_public" => false,
        "slug" => "new-workspace",
        "owner_id" => owner_id
      } = json_response(conn, 201)["data"]
      
      assert owner_id == user.id
      assert workspace_id != nil
    end

    test "creates workspace with auto-generated slug", %{conn: conn} do
      workspace_attrs = %{
        name: "Test Workspace 123!@#",
        description: "Testing slug generation"
      }

      conn = post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
      
      assert %{
        "slug" => "test-workspace-123"
      } = json_response(conn, 201)["data"]
    end

    test "fails with invalid data", %{conn: conn} do
      workspace_attrs = %{
        name: "",  # Invalid: empty name
        description: "Test workspace"
      }

      conn = post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"name" => ["can't be blank"]} = errors
    end

    test "fails with duplicate slug", %{conn: conn} do
      # Create first workspace
      first_attrs = %{name: "Test Workspace", description: "First"}
      post(conn, ~p"/api/workspaces", workspace: first_attrs)

      # Try to create second with same name (will generate same slug)
      second_attrs = %{name: "Test Workspace", description: "Second"}
      conn = post(conn, ~p"/api/workspaces", workspace: second_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"slug" => ["has already been taken"]} = errors
    end

    test "requires authentication", %{conn: conn} do
      conn = 
        conn
        |> Plug.Conn.delete_req_header("authorization")
        |> post(~p"/api/workspaces", workspace: %{name: "Test"})
      
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/workspaces - List workspaces" do
    setup :setup_authenticated_user

    test "lists user's workspaces", %{conn: conn, user: user} do
      # Create workspaces with user as member
      workspace1 = insert(:workspace, owner: user)
      workspace2 = insert(:workspace)
      insert(:workspace_membership, workspace: workspace2, user: user, role: "member")
      
      # Create workspace user is not a member of
      _workspace3 = insert(:workspace)

      conn = get(conn, ~p"/api/workspaces")
      
      response_data = json_response(conn, 200)["data"]
      workspace_ids = Enum.map(response_data, & &1["id"])
      
      assert length(response_data) == 2
      assert workspace1.id in workspace_ids
      assert workspace2.id in workspace_ids
    end

    test "includes workspace metadata", %{conn: conn, user: user} do
      workspace = insert(:workspace, 
        owner: user,
        name: "Test Workspace",
        description: "A test workspace",
        is_public: true
      )

      conn = get(conn, ~p"/api/workspaces")
      
      [workspace_data] = json_response(conn, 200)["data"]
      
      assert workspace_data["id"] == workspace.id
      assert workspace_data["name"] == "Test Workspace"
      assert workspace_data["description"] == "A test workspace"
      assert workspace_data["is_public"] == true
      assert workspace_data["owner_id"] == user.id
      assert workspace_data["member_count"] >= 1
    end

    test "returns empty list for user with no workspaces", %{conn: conn} do
      conn = get(conn, ~p"/api/workspaces")
      
      assert json_response(conn, 200)["data"] == []
    end

    test "requires authentication", %{conn: conn} do
      conn = 
        conn
        |> Plug.Conn.delete_req_header("authorization")
        |> get(~p"/api/workspaces")
      
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/workspaces/:id - Show workspace" do
    setup :setup_authenticated_user

    test "shows workspace details for member", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user)
      
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}")
      
      assert %{
        "id" => workspace_id,
        "name" => name,
        "description" => description,
        "owner_id" => owner_id,
        "channels" => channels
      } = json_response(conn, 200)["data"]
      
      assert workspace_id == workspace.id
      assert owner_id == user.id
      assert is_list(channels)
    end

    test "includes channel list", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user)
      channel1 = insert(:channel, workspace: workspace, name: "general")
      channel2 = insert(:channel, workspace: workspace, name: "random")

      conn = get(conn, ~p"/api/workspaces/#{workspace.id}")
      
      channels = json_response(conn, 200)["data"]["channels"]
      channel_names = Enum.map(channels, & &1["name"])
      
      assert length(channels) == 2
      assert "general" in channel_names
      assert "random" in channel_names
    end

    test "returns 403 for non-member", %{conn: conn} do
      other_user = insert(:user)
      workspace = insert(:workspace, owner: other_user)
      
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}")
      
      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent workspace", %{conn: conn} do
      conn = get(conn, ~p"/api/workspaces/non-existent-id")
      
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/workspaces/:id - Update workspace" do
    setup :setup_authenticated_user

    test "updates workspace as owner", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user, name: "Old Name")
      
      update_attrs = %{
        name: "Updated Name",
        description: "Updated description",
        is_public: true
      }
      
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: update_attrs)
      
      assert %{
        "id" => workspace_id,
        "name" => "Updated Name",
        "description" => "Updated description",
        "is_public" => true
      } = json_response(conn, 200)["data"]
      
      assert workspace_id == workspace.id
    end

    test "updates slug when name changes", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user, name: "Old Name")
      
      update_attrs = %{name: "New Workspace Name"}
      
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: update_attrs)
      
      assert %{
        "slug" => "new-workspace-name"
      } = json_response(conn, 200)["data"]
    end

    test "returns 403 for non-owner", %{conn: conn, user: user} do
      other_user = insert(:user)
      workspace = insert(:workspace, owner: other_user)
      insert(:workspace_membership, workspace: workspace, user: user, role: "member")
      
      update_attrs = %{name: "Updated Name"}
      
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: update_attrs)
      
      assert json_response(conn, 403)
    end

    test "validates required fields", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user)
      
      update_attrs = %{name: ""}  # Invalid empty name
      
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: update_attrs)
      
      assert %{"errors" => errors} = json_response(conn, 422)
      assert %{"name" => ["can't be blank"]} = errors
    end
  end

  describe "DELETE /api/workspaces/:id - Delete workspace" do
    setup :setup_authenticated_user

    test "deletes workspace as owner", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user)
      
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}")
      
      assert response(conn, 204)
      
      # Verify workspace is deleted
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}")
      assert json_response(conn, 404)
    end

    test "cascades deletion to channels and messages", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user)
      channel = insert(:channel, workspace: workspace)
      message = insert(:message, channel: channel)
      
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}")
      
      assert response(conn, 204)
      
      # Verify related data is deleted
      refute Repo.get(Channel, channel.id)
      refute Repo.get(Message, message.id)
    end

    test "returns 403 for non-owner", %{conn: conn, user: user} do
      other_user = insert(:user)
      workspace = insert(:workspace, owner: other_user)
      insert(:workspace_membership, workspace: workspace, user: user, role: "member")
      
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}")
      
      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent workspace", %{conn: conn} do
      conn = delete(conn, ~p"/api/workspaces/non-existent-id")
      
      assert json_response(conn, 404)
    end
  end

  describe "Workspace membership and permissions" do
    setup :setup_authenticated_user

    test "workspace owner has full permissions", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user)
      
      # Owner can read
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}")
      assert json_response(conn, 200)
      
      # Owner can update
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: %{name: "Updated"})
      assert json_response(conn, 200)
      
      # Owner can delete
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}")
      assert response(conn, 204)
    end

    test "workspace member has limited permissions", %{conn: conn, user: user} do
      other_user = insert(:user)
      workspace = insert(:workspace, owner: other_user)
      insert(:workspace_membership, workspace: workspace, user: user, role: "member")
      
      # Member can read
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}")
      assert json_response(conn, 200)
      
      # Member cannot update
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: %{name: "Updated"})
      assert json_response(conn, 403)
      
      # Member cannot delete
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}")
      assert json_response(conn, 403)
    end

    test "admin member has elevated permissions", %{conn: conn, user: user} do
      other_user = insert(:user)
      workspace = insert(:workspace, owner: other_user)
      insert(:workspace_membership, workspace: workspace, user: user, role: "admin")
      
      # Admin can read
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}")
      assert json_response(conn, 200)
      
      # Admin can update
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: %{description: "Updated"})
      assert json_response(conn, 200)
      
      # Admin cannot delete (only owner can)
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}")
      assert json_response(conn, 403)
    end
  end

  describe "Workspace data validation and constraints" do
    setup :setup_authenticated_user

    test "validates name length constraints", %{conn: conn} do
      # Test minimum length
      short_name_attrs = %{name: "", description: "Test"}
      conn = post(conn, ~p"/api/workspaces", workspace: short_name_attrs)
      assert %{"errors" => %{"name" => _}} = json_response(conn, 422)
      
      # Test maximum length
      long_name = String.duplicate("a", 101)
      long_name_attrs = %{name: long_name, description: "Test"}
      conn = post(conn, ~p"/api/workspaces", workspace: long_name_attrs)
      assert %{"errors" => %{"name" => _}} = json_response(conn, 422)
    end

    test "validates slug format constraints", %{conn: conn} do
      invalid_chars_attrs = %{
        name: "Test@Workspace#123",
        slug: "test@workspace#123"
      }
      
      conn = post(conn, ~p"/api/workspaces", workspace: invalid_chars_attrs)
      assert %{"errors" => %{"slug" => _}} = json_response(conn, 422)
    end

    test "handles concurrent workspace creation", %{conn: conn} do
      workspace_attrs = %{name: "Concurrent Test", description: "Testing concurrency"}
      
      # Simulate concurrent requests
      tasks = 
        1..5
        |> Enum.map(fn _i ->
          Task.async(fn ->
            post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
          end)
        end)
        |> Enum.map(&Task.await/1)
      
      successful_requests = Enum.count(tasks, &(&1.status == 201))
      failed_requests = Enum.count(tasks, &(&1.status == 422))
      
      # Only one should succeed due to unique slug constraint
      assert successful_requests == 1
      assert failed_requests == 4
    end
  end

  # Test helper functions
  defp setup_authenticated_user(_context) do
    user = insert(:user)
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    
    conn = 
      build_conn()
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")
    
    %{conn: conn, user: user, token: token}
  end
end