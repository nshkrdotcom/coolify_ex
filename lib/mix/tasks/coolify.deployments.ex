defmodule Mix.Tasks.Coolify.Deployments do
  use Mix.Task

  @shortdoc "Lists recent Coolify deployments for a project or app"

  alias CoolifyEx
  alias CoolifyEx.MixTaskSupport
  alias CoolifyEx.Target

  @moduledoc """
  Lists recent deployments for a configured Coolify project or a direct app UUID.

      mix coolify.deployments --project web
      mix coolify.deployments --project web --take 5
      mix coolify.deployments --app-uuid app-123 --json
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
          take: :integer,
          skip: :integer,
          json: :boolean
        ]
      )

    config = MixTaskSupport.load_config!(opts, "Could not fetch deployments")

    with {:ok, target} <- Target.resolve(config, Keyword.get(opts, :project), app_uuid_opt(opts)),
         {:ok, deployments} <-
           CoolifyEx.list_application_deployments(
             config,
             nil,
             [app_uuid: target.app_uuid] ++ deployment_opts(opts)
           ) do
      print_deployments(deployments, target.project_name, target.app_uuid, opts)
    else
      {:error, reason} ->
        Mix.raise("Could not fetch deployments: #{MixTaskSupport.format_lookup_error(reason)}")
    end
  end

  defp deployment_opts(opts) do
    opts
    |> Keyword.take([:take, :skip])
    |> Keyword.put_new(:take, 1)
  end

  defp print_deployments(deployments, project_name, app_uuid, opts) do
    if Keyword.get(opts, :json, false) do
      MixTaskSupport.print_json!(%{
        project: project_name,
        app_uuid: app_uuid,
        deployments: Enum.map(deployments, &MixTaskSupport.deployment_to_map/1)
      })
    else
      maybe_print_target(project_name, app_uuid)
      Enum.each(deployments, &print_deployment_line/1)
    end
  end

  defp maybe_print_target(project_name, _app_uuid) when is_binary(project_name),
    do: Mix.shell().info("Project: #{project_name}")

  defp maybe_print_target(nil, app_uuid), do: Mix.shell().info("App UUID: #{app_uuid}")

  defp print_deployment_line(deployment) do
    fields =
      [
        deployment.uuid,
        deployment.status,
        deployment.commit,
        deployment.created_at,
        deployment.finished_at,
        MixTaskSupport.first_line(deployment.commit_message)
      ]
      |> Enum.map(&(&1 || "-"))

    Mix.shell().info(Enum.join(fields, " | "))
  end

  defp app_uuid_opt(opts) do
    case Keyword.get(opts, :app_uuid) || Keyword.get(opts, :app) do
      nil -> []
      app_uuid -> [app_uuid: app_uuid]
    end
  end
end
