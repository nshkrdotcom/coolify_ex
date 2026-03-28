defmodule CoolifyEx do
  @moduledoc """
  `CoolifyEx` provides generic Elixir tooling for operating Coolify deployments.

  The library is deliberately generic:

  - it is not tied to any specific project layout
  - it supports top-level Mix applications and monorepos
  - it treats Coolify as an external deployment target driven by a local manifest

  The public API centers around four workflows:

  - loading a manifest with `CoolifyEx.Config.load/1`
  - deploying with `CoolifyEx.Deployer.deploy/3`
  - listing deployments and resolving the latest deployment for an app
  - fetching runtime application logs with `CoolifyEx.ApplicationLogs.fetch/3`
  - verifying a live app with `CoolifyEx.Verifier.verify/3`
  """

  alias CoolifyEx.ApplicationLogs
  alias CoolifyEx.Config
  alias CoolifyEx.Deployer
  alias CoolifyEx.Deployments
  alias CoolifyEx.Verifier

  @spec load_config(Path.t() | nil, keyword()) :: {:ok, Config.t()} | {:error, term()}
  def load_config(path \\ nil, opts \\ []) do
    Config.load(path, opts)
  end

  @spec deploy(Config.t(), String.t() | atom(), keyword()) ::
          {:ok, CoolifyEx.Deployment.t()} | {:error, term()}
  def deploy(%Config{} = config, app_name, opts \\ []) do
    Deployer.deploy(config, app_name, opts)
  end

  @spec list_application_deployments(Config.t(), String.t() | atom() | nil, keyword()) ::
          {:ok, [CoolifyEx.Deployment.t()]} | {:error, term()}
  def list_application_deployments(%Config{} = config, project_or_app \\ nil, opts \\ []) do
    Deployments.list(config, project_or_app, opts)
  end

  @spec fetch_latest_application_deployment(Config.t(), String.t() | atom() | nil, keyword()) ::
          {:ok, CoolifyEx.Deployment.t()} | {:error, term()}
  def fetch_latest_application_deployment(%Config{} = config, project_or_app \\ nil, opts \\ []) do
    Deployments.fetch_latest(config, project_or_app, opts)
  end

  @spec fetch_application_logs(Config.t(), String.t() | atom() | nil, keyword()) ::
          {:ok, ApplicationLogs.t()} | {:error, term()}
  def fetch_application_logs(%Config{} = config, app_name \\ nil, opts \\ []) do
    ApplicationLogs.fetch(config, app_name, opts)
  end

  @spec follow_application_logs(
          Config.t(),
          String.t() | atom() | nil,
          (CoolifyEx.LogLine.t() -> term()),
          keyword()
        ) :: :ok | {:error, term()}
  def follow_application_logs(%Config{} = config, app_name, callback, opts \\ [])
      when is_function(callback, 1) do
    ApplicationLogs.follow(config, app_name, callback, opts)
  end

  @spec verify(Config.t(), String.t() | atom(), keyword()) ::
          {:ok, CoolifyEx.Verifier.Result.t()} | {:error, CoolifyEx.Verifier.Result.t()}
  def verify(%Config{} = config, app_name, opts \\ []) do
    Verifier.verify(config, app_name, opts)
  end
end
