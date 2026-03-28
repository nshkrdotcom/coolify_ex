defmodule Mix.Tasks.Coolify.AppLogs do
  use Mix.Task

  @shortdoc "Fetches runtime application logs from Coolify"

  alias CoolifyEx.ApplicationLogs
  alias CoolifyEx.Config
  alias CoolifyEx.MixTaskSupport

  @moduledoc """
  Fetches runtime logs for one configured Coolify app.

      mix coolify.app_logs
      mix coolify.app_logs --project web
      mix coolify.app_logs --project web --lines 200 --follow
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
          lines: :integer,
          follow: :boolean,
          poll_interval: :integer
        ]
      )

    case Config.load(Keyword.get(opts, :config)) do
      {:ok, config} ->
        run_logs(config, opts)

      {:error, reason} ->
        Mix.raise("Could not load config: #{inspect(reason)}")
    end
  end

  defp run_logs(config, opts) do
    target_name = Keyword.get(opts, :project) || Keyword.get(opts, :app)
    fetch_opts = [lines: Keyword.get(opts, :lines, 100)]

    if Keyword.get(opts, :follow, false) do
      case ApplicationLogs.follow(
             config,
             target_name,
             &print_log_line/1,
             fetch_opts ++ [poll_interval: Keyword.get(opts, :poll_interval, 2_000)]
           ) do
        :ok -> :ok
        {:error, reason} -> Mix.raise("Could not fetch application logs: #{inspect(reason)}")
      end
    else
      case ApplicationLogs.fetch(config, target_name, fetch_opts) do
        {:ok, application_logs} ->
          Enum.each(application_logs.logs, &print_log_line/1)

        {:error, reason} ->
          Mix.raise("Could not fetch application logs: #{inspect(reason)}")
      end
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
