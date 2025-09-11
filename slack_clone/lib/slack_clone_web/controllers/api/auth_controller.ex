defmodule SlackCloneWeb.Api.AuthController do
  use SlackCloneWeb, :controller
  
  alias SlackClone.Accounts
  alias SlackClone.Guardian

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, access_token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")
        {:ok, refresh_token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {7, :days})
        
        conn
        |> put_status(:ok)
        |> json(%{
          data: %{
            access_token: access_token,
            refresh_token: refresh_token,
            user: %{
              id: user.id,
              email: user.email
            }
          }
        })
        
      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{message: "Invalid email or password"}})
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"}) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            {:ok, new_access_token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")
            
            conn
            |> put_status(:ok)
            |> json(%{
              data: %{
                access_token: new_access_token
              }
            })
            
          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: %{message: "Invalid refresh token"}})
        end
        
      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{message: "Invalid refresh token"}})
    end
  end

  def logout(conn, _params) do
    # In a real implementation, you might want to blacklist the token
    conn
    |> put_status(:ok)
    |> json(%{data: %{message: "Logged out successfully"}})
  end
end