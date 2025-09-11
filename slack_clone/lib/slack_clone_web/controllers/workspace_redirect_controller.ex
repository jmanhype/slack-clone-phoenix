defmodule SlackCloneWeb.WorkspaceRedirectController do
  use SlackCloneWeb, :controller
  alias SlackClone.{Accounts, Workspaces}

  def index(conn, _params) do
    with token when is_binary(token) <- get_session(conn, :user_token),
         %{} = user <- Accounts.get_user_by_session_token(token),
         %{} = workspace <- Workspaces.get_user_first_workspace(user) do
      redirect(conn, to: ~p"/workspace/#{workspace.id}")
    else
      _ -> redirect(conn, to: ~p"/")
    end
  end
end

