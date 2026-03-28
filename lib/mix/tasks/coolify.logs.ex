defmodule Mix.Tasks.Coolify.Logs do
  use Mix.Task

  @shortdoc "Prints deployment logs from Coolify"

  alias CoolifyEx.Client
  alias CoolifyEx.Config
  alias CoolifyEx.MixTaskSupport

  @moduledoc """
  Prints deployment logs from Coolify.

      mix coolify.logs DEPLOYMENT_UUID
      mix coolify.logs DEPLOYMENT_UUID --tail 50
  """

  @impl Mix.Task
  def run(args) do
    MixTaskSupport.ensure_started!()

    {opts, argv, _invalid} = OptionParser.parse(args, strict: [config: :string, tail: :integer])

    case argv do
      [deployment_uuid] ->
        case Config.load(Keyword.get(opts, :config)) do
          {:ok, config} ->
            fetch_and_print_logs(config, deployment_uuid, Keyword.get(opts, :tail, 100))

          {:error, reason} ->
            Mix.raise("Could not fetch deployment logs: #{inspect(reason)}")
        end

      _ ->
        Mix.raise("Usage: mix coolify.logs DEPLOYMENT_UUID [--config path] [--tail 100]")
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
        Mix.raise("Could not fetch deployment logs: #{inspect(reason)}")
    end
  end

  defp print_log_line(line) do
    prefix =
      case line.timestamp do
        nil -> ""
        timestamp -> "[#{timestamp}] "
      end

    Mix.shell().info(prefix <> line.output)
  end
end
