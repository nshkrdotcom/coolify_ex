defmodule Mix.Tasks.Coolify.Deploy do
  use Mix.Task

  @shortdoc "Pushes git, triggers a Coolify deployment, and optionally verifies it"

  alias CoolifyEx.Config
  alias CoolifyEx.Deployer
  alias CoolifyEx.MixTaskSupport
  alias CoolifyEx.Verifier

  @moduledoc """
  Deploys one configured Coolify app.

      mix coolify.deploy
      mix coolify.deploy --project web
      mix coolify.deploy --project api --no-push --force
      mix coolify.deploy --config .coolify_ex.exs --skip-verify
  """

  @impl Mix.Task
  def run(args) do
    MixTaskSupport.ensure_started!()

    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          project: :string,
          app: :string,
          config: :string,
          force: :boolean,
          instant: :boolean,
          no_push: :boolean,
          poll_interval: :integer,
          skip_verify: :boolean,
          timeout: :integer
        ]
      )

    case Config.load(Keyword.get(opts, :config)) do
      {:ok, config} -> run_deploy(config, opts)
      {:error, reason} -> Mix.raise("Coolify deploy failed: #{inspect(reason)}")
    end
  end

  defp run_deploy(config, opts) do
    case Deployer.deploy(config, target_name(opts), deploy_opts(opts)) do
      {:ok, deployment} ->
        Mix.shell().info("Deployment finished: #{deployment.uuid}")
        maybe_verify(config, opts)

      {:error, {:deployment_failed, deployment}} ->
        Mix.raise("Deployment failed with status #{deployment.status}: #{deployment.uuid}")

      {:error, {:deployment_timeout, deployment}} ->
        Mix.raise("Deployment timed out while waiting for #{deployment.uuid}")

      {:error, reason} ->
        Mix.raise("Coolify deploy failed: #{inspect(reason)}")
    end
  end

  defp deploy_opts(opts) do
    [
      force: Keyword.get(opts, :force, false),
      instant: Keyword.get(opts, :instant, false),
      push?: not Keyword.get(opts, :no_push, false),
      poll_interval: Keyword.get(opts, :poll_interval, 3_000),
      timeout: Keyword.get(opts, :timeout, 900_000)
    ]
  end

  defp maybe_verify(config, opts) do
    if Keyword.get(opts, :skip_verify, false) do
      :ok
    else
      case Verifier.verify(config, target_name(opts)) do
        {:ok, result} ->
          Mix.shell().info("Verification passed: #{result.passed}/#{result.total} checks")

        {:error, result} ->
          Mix.raise("Verification failed with #{result.failed} failing checks")
      end
    end
  end

  defp target_name(opts), do: Keyword.get(opts, :project) || Keyword.get(opts, :app)
end
