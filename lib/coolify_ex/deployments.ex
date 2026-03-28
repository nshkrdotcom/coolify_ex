defmodule CoolifyEx.Deployments do
  @moduledoc """
  High-level deployment listing and latest-deployment lookup for Coolify apps.
  """

  alias CoolifyEx.Client
  alias CoolifyEx.Config
  alias CoolifyEx.Target

  @spec list(Config.t(), String.t() | atom() | nil, keyword()) ::
          {:ok, [CoolifyEx.Deployment.t()]} | {:error, term()}
  def list(%Config{} = config, project_name \\ nil, opts \\ []) do
    client = Keyword.get(opts, :client, Client)

    with {:ok, %Target{} = target} <- Target.resolve(config, project_name, opts) do
      client.list_application_deployments(
        config.base_url,
        config.token,
        target.app_uuid,
        client_opts(opts)
      )
    end
  end

  @spec fetch_latest(Config.t(), String.t() | atom() | nil, keyword()) ::
          {:ok, CoolifyEx.Deployment.t()} | {:error, term()}
  def fetch_latest(%Config{} = config, project_name \\ nil, opts \\ []) do
    client = Keyword.get(opts, :client, Client)

    case Target.resolve(config, project_name, opts) do
      {:ok, %Target{} = target} ->
        case client.fetch_latest_application_deployment(
               config.base_url,
               config.token,
               target.app_uuid,
               client_opts(opts)
             ) do
          {:ok, deployment} ->
            {:ok, deployment}

          {:error, :empty_deployments} ->
            {:error,
             {:empty_deployments, %{project_name: target.project_name, app_uuid: target.app_uuid}}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp client_opts(opts) do
    opts
    |> Keyword.take([:take, :skip, :status, :branch, :commit])
    |> Keyword.reject(fn {_key, value} -> is_nil(value) end)
  end
end
