defmodule CoolifyEx.ClientBehaviour do
  @moduledoc false

  alias CoolifyEx.Deployment

  @callback start_deployment(String.t(), String.t(), String.t(), keyword()) ::
              {:ok, Deployment.t()} | {:error, term()}

  @callback fetch_deployment(String.t(), String.t(), String.t()) ::
              {:ok, Deployment.t()} | {:error, term()}
end
