defmodule CoolifyEx.ClientBehaviour do
  @moduledoc false

  alias CoolifyEx.ApplicationLogs
  alias CoolifyEx.Deployment

  @callback start_deployment(String.t(), String.t(), String.t(), keyword()) ::
              {:ok, Deployment.t()} | {:error, term()}

  @callback fetch_deployment(String.t(), String.t(), String.t()) ::
              {:ok, Deployment.t()} | {:error, term()}

  @callback list_application_deployments(String.t(), String.t(), String.t(), keyword()) ::
              {:ok, [Deployment.t()]} | {:error, term()}

  @callback fetch_latest_application_deployment(String.t(), String.t(), String.t(), keyword()) ::
              {:ok, Deployment.t()} | {:error, term()}

  @callback fetch_application_logs(String.t(), String.t(), String.t(), keyword()) ::
              {:ok, ApplicationLogs.t()} | {:error, term()}
end
