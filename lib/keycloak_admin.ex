defmodule KeycloakAdmin do
  @moduledoc """
  Documentation for `KeycloakAdmin`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> KeycloakAdmin.hello()
      :world

  """
  def hello do
    :world
  end

  def provider_spec(issuer, provider, worker_options \\ %{}) do
    Supervisor.child_spec(
      {
        Oidcc.ProviderConfiguration.Worker,
        %{
          issuer: issuer,
          name: provider
        } |> Map.merge(worker_options)
      },
      id: provider
    )
  end

  def token_spec(name, provider, client_id, client_secret) do
    Supervisor.child_spec(
      {
        KeycloakAdmin.TokenCache,
        {
          name,
          %{
            client_id: client_id,
            client_secret: client_secret,
            provider: provider
          }
        }
      },
      id: name
    )
  end
  
end
