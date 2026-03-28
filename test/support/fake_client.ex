defmodule CoolifyEx.TestSupport.FakeClient do
  @moduledoc false

  @behaviour CoolifyEx.ClientBehaviour

  def set_start_response(response) do
    Process.put({__MODULE__, :start_response}, response)
  end

  def set_fetch_responses(responses) do
    Process.put({__MODULE__, :fetch_responses}, responses)
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
end
