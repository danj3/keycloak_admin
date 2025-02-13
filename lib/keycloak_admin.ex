defmodule KeycloakAdmin do
  @moduledoc """
  Documentation for `KeycloakAdmin`.
  """

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

  defp admin_base(realm, token_name) do
    Req.new(
      base_url: "https://id.magex.cloud/admin/realms/#{realm}",
      auth: {:bearer, KeycloakAdmin.TokenCache.get_token(token_name).access.token}
    )
  end

  defp result({:ok, %Req.Response{status: status, body: body}})
       when status == 200 and not is_nil(body),
       do: {:ok, body}
  defp result({:ok, %Req.Response{status: status, body: body}})
       when status >= 200 and status < 299 and not is_nil(body),
       do: {:ok, %{status: status, body: body}}

  defp result({:ok, %Req.Response{status: status}})
       when status >= 200 and status < 299,
       do: {:ok, %{status: status}}

  defp result(other), do: other
  
  def org_list(realm, token_name) do
    admin_base(realm, token_name)
    |> Req.get(url: "/organizations")
    |> result()
  end

  def user_count(realm, token_name) do
    admin_base(realm,token_name)
    |> Req.get(url: "/users/count")
    |> result()
  end

  def user_list(realm, token_name) do
    admin_base(realm,token_name)
    |> Req.get(url: "/users")
    |> result()
  end

  def user_action(userid, redirect_uri, action, realm, token_name) do
    admin_base(realm,token_name)
    |> Req.Request.merge_options(
      params: %{
        redirect_uri: redirect_uri,
        lifespan: "7200",
      },
      json: %{"string" => action}
    )
    |> Map.put(:url, URI.parse("/users/#{userid}/execute-actions-email"))

  end
end
