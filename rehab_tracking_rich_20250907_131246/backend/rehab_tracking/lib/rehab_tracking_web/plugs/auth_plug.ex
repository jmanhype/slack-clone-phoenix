defmodule RehabTrackingWeb.Plugs.AuthPlug do
  @moduledoc """
  Authentication plug that validates JWT tokens and sets current user context.
  Supports both API tokens and session-based authentication.
  """
  
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        validate_jwt_token(conn, token)
      
      [] ->
        # No auth header - check if auth is required for this route
        conn
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid authorization header format"})
        |> halt()
    end
  end

  defp validate_jwt_token(conn, token) do
    case RehabTracking.Auth.TokenService.verify_token(token) do
      {:ok, claims} ->
        conn
        |> assign(:current_user_id, claims["sub"])
        |> assign(:current_user_role, claims["role"])
        |> assign(:current_user_permissions, claims["permissions"] || [])
        |> assign(:authenticated, true)
        
      {:error, reason} ->
        Logger.warn("JWT validation failed: #{inspect(reason)}")
        
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid or expired token"})
        |> halt()
    end
  end
end