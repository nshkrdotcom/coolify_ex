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
    response =
      request(base_url, token)
      |> Req.get(
        url: "/applications/#{app_uuid}/start",
        params: [
          force: Keyword.get(opts, :force, false),
          instant_deploy: Keyword.get(opts, :instant, false)
        ]
      )

    with {:ok, %{body: body}} <- response,
         {:ok, body} <- normalize_json_body(body),
         deployment_uuid when is_binary(deployment_uuid) <- Map.get(body, "deployment_uuid") do
      {:ok, %Deployment{uuid: deployment_uuid}}
    else
      {:ok, %{body: body}} -> {:error, {:unexpected_response, body}}
      {:error, {:invalid_json_body, body, reason}} -> {:error, {:invalid_json_body, body, reason}}
      {:error, exception} -> {:error, exception}
    end
  end

  @impl true
  def fetch_deployment(base_url, token, deployment_uuid) do
    response = Req.get(request(base_url, token), url: "/deployments/#{deployment_uuid}")

    with {:ok, %{body: body}} <- response,
         {:ok, body} <- normalize_json_body(body) do
      {:ok,
       %Deployment{
         uuid: deployment_uuid,
         status: Map.get(body, "status"),
         deployment_url: Map.get(body, "deployment_url"),
         commit: Map.get(body, "commit"),
         logs: normalize_logs(Map.get(body, "logs"))
       }}
    else
      {:error, exception} -> {:error, exception}
    end
  end

  @impl true
  def fetch_application_logs(base_url, token, app_uuid, opts \\ []) do
    response =
      Req.get(request(base_url, token),
        url: "/applications/#{app_uuid}/logs",
        params: [lines: Keyword.get(opts, :lines, 100)]
      )

    with {:ok, %{body: body}} <- response,
         {:ok, body} <- normalize_json_body(body) do
      logs = Map.get(body, "logs")

      {:ok,
       %ApplicationLogs{
         app_uuid: app_uuid,
         raw: normalize_raw_logs(logs),
         logs: normalize_application_logs(logs)
       }}
    else
      {:error, {:invalid_json_body, body, reason}} -> {:error, {:invalid_json_body, body, reason}}
      {:error, exception} -> {:error, exception}
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

  defp normalize_json_body(body) when is_map(body), do: {:ok, body}

  defp normalize_json_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, decoded} -> {:error, {:invalid_json_body, body, {:unexpected_shape, decoded}}}
      {:error, reason} -> {:error, {:invalid_json_body, body, reason}}
    end
  end

  defp normalize_json_body(body), do: {:error, {:invalid_json_body, body, :unsupported_body_type}}

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
