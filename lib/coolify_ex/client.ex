defmodule CoolifyEx.Client do
  @moduledoc """
  Req-based client for the Coolify API.
  """

  @behaviour CoolifyEx.ClientBehaviour

  alias CoolifyEx.ApplicationLogs
  alias CoolifyEx.Deployment
  alias CoolifyEx.LogLine

  @impl true
  def start_deployment(base_url, token, app_uuid, opts \\ []) do
    request(base_url, token)
    |> Req.get(
      url: "/applications/#{app_uuid}/start",
      params: [
        force: Keyword.get(opts, :force, false),
        instant_deploy: Keyword.get(opts, :instant, false)
      ]
    )
    |> decode_response(:map)
    |> case do
      {:ok, body} ->
        case Map.get(body, "deployment_uuid") do
          deployment_uuid when is_binary(deployment_uuid) ->
            {:ok, %Deployment{uuid: deployment_uuid}}

          _other ->
            {:error, {:unexpected_response, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def fetch_deployment(base_url, token, deployment_uuid) do
    request(base_url, token)
    |> Req.get(url: "/deployments/#{deployment_uuid}")
    |> decode_response(:map)
    |> case do
      {:ok, body} -> {:ok, normalize_deployment(body, deployment_uuid)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def list_application_deployments(base_url, token, app_uuid, opts \\ []) do
    request(base_url, token)
    |> Req.get(
      url: "/deployments/applications/#{app_uuid}",
      params: build_deployment_list_params(opts)
    )
    |> decode_response(:list)
    |> case do
      {:ok, deployments} ->
        {:ok, Enum.map(deployments, &normalize_deployment/1)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def fetch_latest_application_deployment(base_url, token, app_uuid, opts \\ []) do
    case list_application_deployments(base_url, token, app_uuid, Keyword.put_new(opts, :take, 1)) do
      {:ok, [deployment | _rest]} -> {:ok, deployment}
      {:ok, []} -> {:error, :empty_deployments}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def fetch_application_logs(base_url, token, app_uuid, opts \\ []) do
    request(base_url, token)
    |> Req.get(
      url: "/applications/#{app_uuid}/logs",
      params: [lines: Keyword.get(opts, :lines, 100)]
    )
    |> decode_response(:map)
    |> case do
      {:ok, body} ->
        logs = Map.get(body, "logs")

        {:ok,
         %ApplicationLogs{
           app_uuid: app_uuid,
           raw: normalize_raw_logs(logs),
           logs: normalize_application_logs(logs)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request(base_url, token) do
    Req.new(
      base_url: "#{String.trim_trailing(base_url, "/")}/api/v1",
      retry: false,
      auth: {:bearer, token},
      headers: [
        {"accept", "application/json"},
        {"user-agent", "coolify_ex/#{Application.spec(:coolify_ex, :vsn)}"}
      ]
    )
  end

  defp build_deployment_list_params(opts) do
    opts
    |> Keyword.take([:take, :skip, :status, :branch, :commit])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp decode_response({:error, exception}, _shape), do: {:error, exception}

  defp decode_response({:ok, %{status: status, body: body}}, shape) when status in 200..299 do
    normalize_response_body(body, shape)
  end

  defp decode_response({:ok, %{status: status, body: body}}, _shape) do
    {:error, {:http_error, status, normalize_error_body(body)}}
  end

  defp normalize_logs(nil), do: []

  defp normalize_logs(logs) when is_binary(logs) do
    case Jason.decode(logs) do
      {:ok, decoded} -> normalize_logs(decoded)
      {:error, _reason} -> [%LogLine{output: logs}]
    end
  end

  defp normalize_logs(logs) when is_list(logs) do
    Enum.map(logs, &normalize_log_line/1)
  end

  defp normalize_logs(other), do: [%LogLine{output: inspect(other)}]

  defp normalize_application_logs(nil), do: []

  defp normalize_application_logs(logs) when is_binary(logs) do
    logs
    |> split_log_lines()
    |> Enum.map(&%LogLine{output: &1})
  end

  defp normalize_application_logs(logs) when is_list(logs) do
    Enum.map(logs, fn line ->
      %LogLine{output: to_string(line)}
    end)
  end

  defp normalize_application_logs(other), do: [%LogLine{output: inspect(other)}]

  defp normalize_raw_logs(nil), do: nil
  defp normalize_raw_logs(logs) when is_binary(logs), do: logs

  defp normalize_raw_logs(logs) when is_list(logs),
    do: Enum.map_join(logs, "\n", &to_string/1)

  defp normalize_raw_logs(other), do: inspect(other)

  defp normalize_response_body(body, :map), do: normalize_json_map_body(body)
  defp normalize_response_body(body, :list), do: normalize_json_list_body(body)

  defp normalize_json_map_body(body) when is_map(body), do: {:ok, body}

  defp normalize_json_map_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, decoded} -> {:error, {:invalid_json_body, body, {:unexpected_shape, decoded}}}
      {:error, reason} -> {:error, {:invalid_json_body, body, reason}}
    end
  end

  defp normalize_json_map_body(body),
    do: {:error, {:invalid_json_body, body, :unsupported_body_type}}

  defp normalize_json_list_body(body) when is_list(body), do: {:ok, body}
  defp normalize_json_list_body(%{"data" => data}) when is_list(data), do: {:ok, data}
  defp normalize_json_list_body(%{data: data}) when is_list(data), do: {:ok, data}

  defp normalize_json_list_body(%{"deployments" => deployments}) when is_list(deployments),
    do: {:ok, deployments}

  defp normalize_json_list_body(%{deployments: deployments}) when is_list(deployments),
    do: {:ok, deployments}

  defp normalize_json_list_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> normalize_json_list_body(decoded)
      {:error, reason} -> {:error, {:invalid_json_body, body, reason}}
    end
  end

  defp normalize_json_list_body(body),
    do: {:error, {:invalid_json_body, body, :unsupported_body_type}}

  defp normalize_error_body(body) when is_map(body), do: body
  defp normalize_error_body(body) when is_list(body), do: body

  defp normalize_error_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _reason} -> body
    end
  end

  defp normalize_error_body(body), do: inspect(body)

  defp normalize_deployment(body, uuid_override \\ nil) do
    %Deployment{
      uuid: deployment_field(body, :uuid, uuid_override),
      status: deployment_field(body, :status),
      deployment_url: deployment_field(body, :deployment_url),
      commit: deployment_field(body, :commit),
      commit_message: deployment_field(body, :commit_message),
      created_at: deployment_field(body, :created_at),
      finished_at: deployment_field(body, :finished_at),
      logs: body |> deployment_field(:logs) |> normalize_logs()
    }
  end

  defp deployment_field(body, key, default \\ nil) do
    Map.get(body, Atom.to_string(key)) || Map.get(body, key) || default
  end

  defp normalize_log_line(%{"timestamp" => timestamp, "output" => output}) do
    %LogLine{timestamp: timestamp, output: output}
  end

  defp normalize_log_line(%{timestamp: timestamp, output: output}) do
    %LogLine{timestamp: timestamp, output: output}
  end

  defp normalize_log_line(other), do: %LogLine{output: inspect(other)}

  defp split_log_lines(logs) do
    logs
    |> String.split(~r/\r?\n/, trim: false)
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == ""))
    |> Enum.reverse()
  end
end
