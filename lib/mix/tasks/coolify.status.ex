defmodule Mix.Tasks.Coolify.Status do
  use Mix.Task

  @shortdoc "Fetches deployment status from Coolify"

  alias CoolifyEx
  alias CoolifyEx.Client
  alias CoolifyEx.MixTaskSupport

  @moduledoc """
  Fetches a deployment by UUID or resolves the latest deployment for a project.

      mix coolify.status DEPLOYMENT_UUID
      mix coolify.status --project web --latest
  """

  @impl Mix.Task
  def run(args) do
    MixTaskSupport.ensure_started!()

    {opts, argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          project: :string,
          app: :string,
          app_uuid: :string,
          config: :string,
          latest: :boolean
        ]
      )

    config = MixTaskSupport.load_config!(opts, "Could not fetch deployment status")

    case resolve_deployment_uuid(config, argv, opts) do
      {:ok, {deployment_uuid, project_name}} ->
        fetch_and_print_status(config, deployment_uuid, project_name)

      {:error, :usage} ->
        Mix.raise(
          "Usage: mix coolify.status DEPLOYMENT_UUID [--config path] or mix coolify.status --project PROJECT --latest"
        )

      {:error, reason} ->
        Mix.raise(
          "Could not fetch deployment status: #{MixTaskSupport.format_lookup_error(reason)}"
        )
    end
  end

  defp fetch_and_print_status(config, deployment_uuid, project_name) do
    case Client.fetch_deployment(config.base_url, config.token, deployment_uuid) do
      {:ok, deployment} ->
        if project_name do
          Mix.shell().info("Project: #{project_name}")
          Mix.shell().info("Latest deployment: #{deployment.uuid}")
        end

        Mix.shell().info("Status: #{deployment.status}")
        print_field("Commit", deployment.commit)
        print_field("Created at", deployment.created_at)
        print_field("Finished at", deployment.finished_at)
        print_field("Commit message", deployment.commit_message)
        print_logs_url(deployment.deployment_url)

      {:error, reason} ->
        Mix.raise(
          "Could not fetch deployment status: #{MixTaskSupport.format_lookup_error(reason)}"
        )
    end
  end

  defp resolve_deployment_uuid(_config, [deployment_uuid], _opts),
    do: {:ok, {deployment_uuid, nil}}

  defp resolve_deployment_uuid(config, [], opts) do
    if Keyword.get(opts, :latest, false) do
      project_name = Keyword.get(opts, :project)

      case CoolifyEx.fetch_latest_application_deployment(config, project_name, app_uuid_opt(opts)) do
        {:ok, deployment} -> {:ok, {deployment.uuid, project_name}}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :usage}
    end
  end

  defp resolve_deployment_uuid(_config, _argv, _opts), do: {:error, :usage}

  defp print_logs_url(nil), do: :ok
  defp print_logs_url(url), do: Mix.shell().info("Logs: #{url}")

  defp print_field(_label, nil), do: :ok
  defp print_field(label, value), do: Mix.shell().info("#{label}: #{value}")

  defp app_uuid_opt(opts) do
    case Keyword.get(opts, :app_uuid) || Keyword.get(opts, :app) do
      nil -> []
      app_uuid -> [app_uuid: app_uuid]
    end
  end
end
