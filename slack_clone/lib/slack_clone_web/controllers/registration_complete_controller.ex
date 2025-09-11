defmodule SlackCloneWeb.RegistrationCompleteController do
  use SlackCloneWeb, :controller

  alias SlackClone.Accounts
  alias SlackCloneWeb.UserAuth

  # GET /auth/complete?t=<signed_token>&workspace_id=<uuid>
  def complete(conn, %{"t" => token, "workspace_id" => workspace_id}) do
    with {:ok, %{"user_id" => user_id}} <- verify_token(token),
         %{} = user <- Accounts.get_user!(user_id) do
      conn
      |> put_session(:user_return_to, ~p"/workspace/#{workspace_id}")
      |> UserAuth.log_in_user(user)
    else
      _ ->
        conn
        |> put_flash(:error, "Your sign-in link is invalid or expired.")
        |> redirect(to: ~p"/auth/login")
    end
  end

  def complete(conn, _params) do
    conn
    |> put_flash(:error, "Missing authentication token.")
    |> redirect(to: ~p"/auth/login")
  end

  defp verify_token(token) do
    Phoenix.Token.verify(SlackCloneWeb.Endpoint, "registration_auth", token, max_age: 600)
  end
end

