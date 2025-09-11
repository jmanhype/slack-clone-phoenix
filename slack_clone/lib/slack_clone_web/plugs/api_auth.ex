defmodule SlackCloneWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug for JWT authentication in API endpoints
  """
  import Plug.Conn
  alias SlackClone.Guardian

  def init(opts), do: opts

  def call(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.put_view(json: SlackCloneWeb.ErrorJSON)
        |> Phoenix.Controller.render(:error, %{message: "Unauthorized"})
        |> halt()

      user ->
        assign(conn, :current_user, user)
    end
  end

  def ensure_authenticated(conn, _opts) do
    if Guardian.Plug.authenticated?(conn) do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.put_view(json: SlackCloneWeb.ErrorJSON)
      |> Phoenix.Controller.render(:error, %{message: "Not authenticated"})
      |> halt()
    end
  end
end