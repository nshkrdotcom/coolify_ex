defmodule CoolifyEx do
  @moduledoc """
  `CoolifyEx` provides generic Elixir tooling for operating Coolify deployments.

  The library is deliberately generic:

  - it is not tied to any specific project layout
  - it supports top-level Mix applications and monorepos
  - it treats Coolify as an external deployment target driven by a local manifest

  The public API centers around three workflows:

  - loading a manifest with `CoolifyEx.Config.load/1`
  - deploying with `CoolifyEx.Deployer.deploy/3`
  - verifying a live app with `CoolifyEx.Verifier.verify/3`
  """

  alias CoolifyEx.Config
  alias CoolifyEx.Deployer
  alias CoolifyEx.Verifier

  @spec load_config(Path.t(), keyword()) :: {:ok, Config.t()} | {:error, term()}
  def load_config(path \\ "coolify.exs", opts \\ []) do
    Config.load(path, opts)
  end

  @spec deploy(Config.t(), String.t() | atom(), keyword()) ::
          {:ok, CoolifyEx.Deployment.t()} | {:error, term()}
  def deploy(%Config{} = config, app_name, opts \\ []) do
    Deployer.deploy(config, app_name, opts)
  end

  @spec verify(Config.t(), String.t() | atom(), keyword()) ::
          {:ok, CoolifyEx.Verifier.Result.t()} | {:error, CoolifyEx.Verifier.Result.t()}
  def verify(%Config{} = config, app_name, opts \\ []) do
    Verifier.verify(config, app_name, opts)
  end
end
