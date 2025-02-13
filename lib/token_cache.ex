defmodule KeycloakAdmin.TokenCache do
  @behaviour :gen_statem

  def get_token(cache_ref) do
    :gen_statem.call(cache_ref, :get_token)
  end

  def child_spec({name, args}) do
    %{
      id: name,
      start: {__MODULE__, :start_link, [{name, args}]}
    }
  end

  def start_link({name, %{client_id: client_id, client_secret: client_secret, provider: provider}}) do
    :gen_statem.start_link(
      {:local, name},
      __MODULE__,
      {client_id, client_secret, provider},
      []
    )
  end
  
  defstruct [
    :client_id,
    :client_secret,
    :provider,
    :token,
    :ttl,
    :exp_at_s
  ]
  
  def callback_mode, do: :state_functions

  def init({client_id, client_secret, provider}) do
    state=%__MODULE__{
      client_id: client_id,
      client_secret: client_secret,
      provider: provider
    }

    {
      :ok,
      :no_token,
      state
    }
  end

  def no_token({:call, from}, :get_token, state) do
    {:next_state, :have_token, state,
     [
       {:next_event, :internal, :get_token},
       {:next_event, {:call, from}, :get_token}
     ]
    }
  end

  def have_token(:internal, :get_token, state) do
    {:ok, %{access: %{expires: ttl}} = token} =
      Oidcc.client_credentials_token(
        state.provider,
        state.client_id,
        state.client_secret,
        %{}
      )
    
    {:keep_state, %{state |
      token: token,
      exp_at_s: System.monotonic_time(:second)+ttl,
    },
     [
       {{:timeout, :expire}, ttl*1000, :access_expired}
     ]
    } |> dbg()
  end


  def have_token({:call, from}, :get_token, state) do
    {:keep_state, state, [{:reply, from, state.token}]}
  end

  def have_token({:timeout, :expire}, :access_expired, state) do
    {:next_state, :no_token, %{state | token: nil}} |> dbg
  end
end
