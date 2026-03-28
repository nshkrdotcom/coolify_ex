defmodule Mix.Tasks.Coolify.Latest do
  use Mix.Task

  @shortdoc "Prints the latest Coolify deployment for a project or app"

  alias CoolifyEx
  alias CoolifyEx.MixTaskSupport
  alias CoolifyEx.Target

  @moduledoc """
  Fetches the newest deployment for a configured project or a direct app UUID.

      mix coolify.latest --project web
      mix coolify.latest --project web --json
      mix coolify.latest --app-uuid app-123
  """

  @impl Mix.Task
  def run(args) do
    MixTaskSupport.ensure_started!()

    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          project: :string,
          app: :string,
          app_uuid: :string,
          config: :string,
          json: :boolean
        ]
      )

    config = MixTaskSupport.load_config!(opts, "Could not fetch latest deployment")

    with {:ok, target} <- Target.resolve(config, Keyword.get(opts, :project), app_uuid_opt(opts)),
         {:ok, deployment} <-
           CoolifyEx.fetch_latest_application_deployment(
             config,
             nil,
             app_uuid: target.app_uuid
           ) do
      print_latest(deployment, target.project_name, target.app_uuid, opts)
    else
      {:error, reason} ->
        Mix.raise(
          "Could not fetch latest deployment: #{MixTaskSupport.format_lookup_error(reason)}"
        )
    end
  end

  defp print_latest(deployment, project_name, app_uuid, opts) do
    if Keyword.get(opts, :json, false) do
      MixTaskSupport.print_json!(%{
        project: project_name,
        app_uuid: app_uuid,
        deployment: MixTaskSupport.deployment_to_map(deployment)
      })
    else
      if project_name do
        Mix.shell().info("Project: #{project_name}")
      end

      Mix.shell().info("App UUID: #{app_uuid}")
      Mix.shell().info("Latest deployment: #{deployment.uuid}")
      Mix.shell().info("Status: #{deployment.status || "-"}")
      Mix.shell().info("Commit: #{deployment.commit || "-"}")
      Mix.shell().info("Created at: #{deployment.created_at || "-"}")
      Mix.shell().info("Finished at: #{deployment.finished_at || "-"}")
      Mix.shell().info("Commit message: #{deployment.commit_message || "-"}")
    end
  end

  defp app_uuid_opt(opts) do
    case Keyword.get(opts, :app_uuid) || Keyword.get(opts, :app) do
      nil -> []
      app_uuid -> [app_uuid: app_uuid]
    end
  end
end
