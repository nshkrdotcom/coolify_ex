defmodule Mix.Tasks.Coolify.Status do
  use Mix.Task

  @shortdoc "Fetches deployment status from Coolify"

  alias CoolifyEx.Client
  alias CoolifyEx.Config
  alias CoolifyEx.MixTaskSupport

  @moduledoc """
  Fetches a deployment by UUID.

      mix coolify.status DEPLOYMENT_UUID
      mix coolify.status DEPLOYMENT_UUID --config .coolify_ex.exs
  """

  @impl Mix.Task
  def run(args) do
    MixTaskSupport.ensure_started!()

    {opts, argv, _invalid} = OptionParser.parse(args, strict: [config: :string])

    case argv do
      [deployment_uuid] ->
        case Config.load(Keyword.get(opts, :config)) do
          {:ok, config} -> fetch_and_print_status(config, deployment_uuid)
          {:error, reason} -> Mix.raise("Could not fetch deployment status: #{inspect(reason)}")
        end

      _ ->
        Mix.raise("Usage: mix coolify.status DEPLOYMENT_UUID [--config path]")
    end
  end

  defp fetch_and_print_status(config, deployment_uuid) do
    case Client.fetch_deployment(config.base_url, config.token, deployment_uuid) do
      {:ok, deployment} ->
        Mix.shell().info("Status: #{deployment.status}")
        print_logs_url(deployment.deployment_url)

      {:error, reason} ->
        Mix.raise("Could not fetch deployment status: #{inspect(reason)}")
    end
  end

  defp print_logs_url(nil), do: :ok
  defp print_logs_url(url), do: Mix.shell().info("Logs: #{url}")
end
