defmodule SlackCloneWeb.Api.UserController do
  use SlackCloneWeb, :controller
  
  alias SlackClone.Accounts

  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    
    conn
    |> put_status(:ok)
    |> json(%{
      data: %{
        id: user.id,
        email: user.email,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
      }
    })
  end

  def update(conn, %{"user" => user_params}) do
    user = Guardian.Plug.current_resource(conn)
    
    case Accounts.update_user(user, user_params) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          data: %{
            id: updated_user.id,
            email: updated_user.email,
            updated_at: updated_user.updated_at
          }
        })
        
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{message: "Failed to update user", details: format_errors(changeset)}})
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end