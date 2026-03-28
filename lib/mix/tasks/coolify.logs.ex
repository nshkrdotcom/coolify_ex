defmodule Mix.Tasks.Coolify.Logs do
  use Mix.Task

  @shortdoc "Prints deployment logs from Coolify"

  alias CoolifyEx
  alias CoolifyEx.Client
  alias CoolifyEx.MixTaskSupport

  @moduledoc """
  Prints deployment logs from Coolify by deployment UUID or latest project deploy.

      mix coolify.logs DEPLOYMENT_UUID
      mix coolify.logs --project web --latest --tail 50
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
          latest: :boolean,
          tail: :integer
        ]
      )

    config = MixTaskSupport.load_config!(opts, "Could not fetch deployment logs")

    case resolve_deployment_uuid(config, argv, opts) do
      {:ok, deployment_uuid} ->
        fetch_and_print_logs(config, deployment_uuid, Keyword.get(opts, :tail, 100))

      {:error, :usage} ->
        Mix.raise(
          "Usage: mix coolify.logs DEPLOYMENT_UUID [--config path] [--tail 100] or mix coolify.logs --project PROJECT --latest [--tail 100]"
        )

      {:error, reason} ->
        Mix.raise(
          "Could not fetch deployment logs: #{MixTaskSupport.format_lookup_error(reason)}"
        )
    end
  end

  defp tail_lines(lines, count) when count <= 0, do: lines
  defp tail_lines(lines, count), do: Enum.take(lines, -count)

  defp fetch_and_print_logs(config, deployment_uuid, tail) do
    case Client.fetch_deployment(config.base_url, config.token, deployment_uuid) do
      {:ok, deployment} ->
        deployment.logs
        |> tail_lines(tail)
        |> Enum.each(&print_log_line/1)

      {:error, reason} ->
        Mix.raise(
          "Could not fetch deployment logs: #{MixTaskSupport.format_lookup_error(reason)}"
        )
    end
  end

  defp resolve_deployment_uuid(_config, [deployment_uuid], _opts), do: {:ok, deployment_uuid}

  defp resolve_deployment_uuid(config, [], opts) do
    if Keyword.get(opts, :latest, false) do
      case CoolifyEx.fetch_latest_application_deployment(
             config,
             Keyword.get(opts, :project),
             app_uuid_opt(opts)
           ) do
        {:ok, deployment} -> {:ok, deployment.uuid}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :usage}
    end
  end

  defp resolve_deployment_uuid(_config, _argv, _opts), do: {:error, :usage}

  defp print_log_line(line) do
    Mix.shell().info(MixTaskSupport.log_line_prefix(line.timestamp) <> line.output)
  end

  defp app_uuid_opt(opts) do
    case Keyword.get(opts, :app_uuid) || Keyword.get(opts, :app) do
      nil -> []
      app_uuid -> [app_uuid: app_uuid]
    end
  end
end
