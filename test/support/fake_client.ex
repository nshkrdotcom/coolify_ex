defmodule CoolifyEx.TestSupport.FakeClient do
  @moduledoc false

  @behaviour CoolifyEx.ClientBehaviour

  def set_start_response(response) do
    Process.put({__MODULE__, :start_response}, response)
  end

  def set_fetch_responses(responses) do
    Process.put({__MODULE__, :fetch_responses}, responses)
  end

  def set_fetch_application_log_responses(responses) do
    Process.put({__MODULE__, :fetch_application_log_responses}, responses)
  end

  def set_list_deployment_responses(responses) do
    Process.put({__MODULE__, :list_deployment_responses}, responses)
  end

  @impl true
  def start_deployment(_base_url, _token, _app_uuid, _opts) do
    Process.get({__MODULE__, :start_response}, {:error, :missing_start_response})
  end

  @impl true
  def fetch_deployment(_base_url, _token, _deployment_uuid) do
    case Process.get({__MODULE__, :fetch_responses}, []) do
      [response | rest] ->
        Process.put({__MODULE__, :fetch_responses}, rest)
        response

      [] ->
        {:error, :missing_fetch_response}
    end
  end

  @impl true
  def list_application_deployments(_base_url, _token, _app_uuid, _opts) do
    case Process.get({__MODULE__, :list_deployment_responses}, []) do
      [response | rest] ->
        Process.put({__MODULE__, :list_deployment_responses}, rest)
        response

      [] ->
        {:error, :missing_list_deployment_response}
    end
  end

  @impl true
  def fetch_latest_application_deployment(base_url, token, app_uuid, opts) do
    case list_application_deployments(base_url, token, app_uuid, Keyword.put_new(opts, :take, 1)) do
      {:ok, [deployment | _rest]} -> {:ok, deployment}
      {:ok, []} -> {:error, :empty_deployments}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def fetch_application_logs(_base_url, _token, _app_uuid, _opts) do
    case Process.get({__MODULE__, :fetch_application_log_responses}, []) do
      [response | rest] ->
        Process.put({__MODULE__, :fetch_application_log_responses}, rest)
        response

      [] ->
        {:error, :missing_fetch_application_log_response}
    end
  end
end
