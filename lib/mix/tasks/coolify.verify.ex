defmodule Mix.Tasks.Coolify.Verify do
  use Mix.Task

  @shortdoc "Waits for readiness and runs verification checks against a configured Coolify app"

  alias CoolifyEx.Config
  alias CoolifyEx.MixTaskSupport
  alias CoolifyEx.Verifier

  @moduledoc """
  Waits for readiness and then runs verification checks defined in the deployment manifest.

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
        print_success(result)

      {:error, result} when is_struct(result, CoolifyEx.Verifier.Result) ->
        print_failed_checks(result)
        Mix.raise(failure_message(result))

      {:error, reason} ->
        Mix.raise("Could not verify app: #{inspect(reason)}")
    end
  end

  defp print_success(result) do
    Mix.shell().info(
      "Readiness passed for #{result.app} after #{result.readiness.attempts} attempt(s)"
    )

    Mix.shell().info(
      "Verification passed: #{result.verification.passed}/#{result.verification.total} checks"
    )
  end

  defp print_failed_checks(result) do
    result
    |> failed_checks()
    |> Enum.each(fn check ->
      if not check.ok? do
        Mix.shell().error("#{check.phase} #{check.name}: #{check.reason}")
      end
    end)
  end

  defp failed_checks(result) do
    result.readiness.checks ++ result.verification.checks
  end

  defp failure_message(result) do
    cond do
      result.readiness.failed > 0 ->
        "Verification failed during readiness for #{result.app}"

      result.verification.failed > 0 ->
        "Verification failed for #{result.app}"

      true ->
        "Verification failed for #{result.app}"
    end
  end
end
