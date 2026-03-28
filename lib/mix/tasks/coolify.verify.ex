defmodule Mix.Tasks.Coolify.Verify do
  use Mix.Task

  @shortdoc "Runs smoke checks against a configured Coolify app"

  alias CoolifyEx.Config
  alias CoolifyEx.MixTaskSupport
  alias CoolifyEx.Verifier

  @moduledoc """
  Runs smoke checks defined in the deployment manifest.

      mix coolify.verify
      mix coolify.verify --project web
  """

  @impl Mix.Task
  def run(args) do
    MixTaskSupport.ensure_started!()

    {opts, _argv, _invalid} =
      OptionParser.parse(args, strict: [project: :string, app: :string, config: :string])

    case Config.load(Keyword.get(opts, :config)) do
      {:ok, config} ->
        run_verification(config, Keyword.get(opts, :project) || Keyword.get(opts, :app))

      {:error, reason} ->
        Mix.raise("Could not load config: #{inspect(reason)}")
    end
  end

  defp run_verification(config, app_name) do
    case Verifier.verify(config, app_name) do
      {:ok, result} ->
        Mix.shell().info("All #{result.total} checks passed for #{result.app}")

      {:error, %{checks: checks, app: app}} = _result ->
        print_failed_checks(checks)
        Mix.raise("Verification failed for #{app}")

      {:error, reason} ->
        Mix.raise("Could not verify app: #{inspect(reason)}")
    end
  end

  defp print_failed_checks(checks) do
    Enum.each(checks, fn check ->
      if not check.ok? do
        Mix.shell().error("#{check.name}: #{check.reason}")
      end
    end)
  end
end
