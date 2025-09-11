defmodule SlackClone.Guardian do
  @moduledoc """
  Guardian implementation for JWT token handling in SlackClone.
  
  This module configures Guardian to work with our User schema and provides
  JWT token generation and verification for authentication purposes.
  """
  use Guardian, otp_app: :slack_clone

  alias SlackClone.Accounts
  alias SlackClone.Accounts.User

  @doc """
  Encodes the subject from the given resource.
  For users, we use their binary ID as the subject.
  """
  def subject_for_token(%User{id: id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(_, _), do: {:error, :invalid_resource}

  @doc """
  Retrieves the resource from the given subject.
  We expect the subject to be a user ID string.
  """
  def resource_from_claims(%{"sub" => user_id}) do
    case Accounts.get_user!(user_id) do
      %User{} = user -> {:ok, user}
      nil -> {:error, :resource_not_found}
    end
  rescue
    Ecto.NoResultsError -> {:error, :resource_not_found}
  end

  def resource_from_claims(_claims), do: {:error, :invalid_claims}

  @doc """
  Generates a JWT token for the given user.
  """
  def generate_jwt(user) do
    encode_and_sign(user, %{}, ttl: {24, :hours})
  end

  @doc """
  Verifies and decodes a JWT token.
  """
  def verify_jwt(token) do
    decode_and_verify(token)
  end

  @doc """
  Generates a refresh token for the given user.
  """
  def generate_refresh_token(user) do
    encode_and_sign(user, %{"typ" => "refresh"}, ttl: {7, :days})
  end

  @doc """
  Revokes a JWT token by adding it to a blacklist (if implemented).
  For now, this is a no-op but can be extended with token blacklisting.
  """
  def revoke_token(_token), do: :ok
end