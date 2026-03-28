defmodule CoolifyEx.MixTaskSupport do
  @moduledoc false

  alias CoolifyEx.Config
  alias CoolifyEx.Deployment

  def ensure_started! do
    case Application.ensure_all_started(:req) do
      {:ok, _started} -> :ok
      {:error, reason} -> Mix.raise("Could not start CoolifyEx task runtime: #{inspect(reason)}")
    end
  end

  def load_config!(opts, error_prefix) do
    case Config.load(Keyword.get(opts, :config)) do
      {:ok, config} -> config
      {:error, reason} -> Mix.raise("#{error_prefix}: #{inspect(reason)}")
    end
  end

  def print_json!(value) do
    Mix.shell().info(Jason.encode!(value))
  end

  def deployment_to_map(%Deployment{} = deployment) do
    %{
      uuid: deployment.uuid,
      status: deployment.status,
      commit: deployment.commit,
      commit_message: deployment.commit_message,
      created_at: deployment.created_at,
      finished_at: deployment.finished_at,
      deployment_url: deployment.deployment_url,
      logs: Enum.map(deployment.logs, &log_line_to_map/1)
    }
  end

  def latest_target_opts(opts) do
    opts
    |> Keyword.take([:take, :skip, :status, :branch, :commit])
    |> Keyword.merge(app_uuid_opt(opts))
  end

  def format_http_error({:http_error, status, body}) do
    "#{status} #{http_error_detail(body)}"
  end

  def format_lookup_error({:empty_deployments, %{project_name: project_name}})
      when is_binary(project_name) do
    "No deployments found for project #{project_name}"
  end

  def format_lookup_error({:empty_deployments, %{app_uuid: app_uuid}})
      when is_binary(app_uuid) do
    "No deployments found for app #{app_uuid}"
  end

  def format_lookup_error({:missing_app_uuid, project_name}) do
    "Project #{project_name} does not define an app_uuid"
  end

  def format_lookup_error({:ambiguous_target, project_name, app_uuid}) do
    "Specify either a project or an app UUID, not both (#{project_name}, #{app_uuid})"
  end

  def format_lookup_error({:http_error, _status, _body} = reason), do: format_http_error(reason)
  def format_lookup_error(reason), do: inspect(reason)

  def target_display_name(nil, opts), do: app_uuid_value(opts)
  def target_display_name(project_name, _opts), do: project_name

  def app_uuid_value(opts) do
    Keyword.get(opts, :app_uuid) || Keyword.get(opts, :app)
  end

  def log_line_prefix(nil), do: ""
  def log_line_prefix(timestamp), do: "[#{timestamp}] "

  def first_line(nil), do: nil

  def first_line(text) when is_binary(text) do
    text
    |> String.split(~r/\r?\n/, parts: 2)
    |> List.first()
  end

  defp app_uuid_opt(opts) do
    case app_uuid_value(opts) do
      nil -> []
      app_uuid -> [app_uuid: app_uuid]
    end
  end

  defp http_error_detail(%{"message" => message}) when is_binary(message), do: message
  defp http_error_detail(%{message: message}) when is_binary(message), do: message
  defp http_error_detail(body) when is_binary(body), do: body
  defp http_error_detail(body), do: inspect(body)

  defp log_line_to_map(line) do
    %{
      timestamp: line.timestamp,
      output: line.output
    }
  end
end
