defmodule CoolifyEx.Verifier do
  @moduledoc """
  Runs live-app smoke checks defined in the local manifest.
  """

  alias CoolifyEx.Config
  alias CoolifyEx.Verifier.CheckResult
  alias CoolifyEx.Verifier.Result

  @spec verify(Config.t(), String.t() | atom(), keyword()) ::
          {:ok, Result.t()} | {:error, Result.t()}
  def verify(%Config{} = config, app_name, opts \\ []) do
    request = Keyword.get(opts, :request, &default_request/2)

    with {:ok, app} <- Config.fetch_app(config, app_name) do
      checks = Enum.map(app.smoke_checks, &run_check(&1, request))
      result = build_result(app.name, checks)

      if result.failed == 0 do
        {:ok, result}
      else
        {:error, result}
      end
    end
  end

  defp run_check(check, request) do
    case request.(check.method, check.url) do
      {:ok, %{status: status, body: body}} ->
        evaluate_response(check, status, body)

      {:error, reason} ->
        %CheckResult{
          name: check.name,
          url: check.url,
          reason: format_reason(reason),
          ok?: false
        }
    end
  end

  defp evaluate_response(check, status, body) do
    body = body || ""

    cond do
      status != check.expected_status ->
        %CheckResult{
          name: check.name,
          url: check.url,
          status: status,
          reason: "expected HTTP #{check.expected_status}, got #{status}",
          ok?: false
        }

      is_binary(check.expected_body_contains) and
          not String.contains?(body, check.expected_body_contains) ->
        %CheckResult{
          name: check.name,
          url: check.url,
          status: status,
          reason: "response body did not include expected text",
          ok?: false
        }

      true ->
        %CheckResult{name: check.name, url: check.url, status: status, ok?: true}
    end
  end

  defp build_result(app_name, checks) do
    failed = Enum.count(checks, &(!&1.ok?))
    total = length(checks)

    %Result{
      app: app_name,
      total: total,
      passed: total - failed,
      failed: failed,
      checks: checks
    }
  end

  defp default_request(method, url) do
    case Req.request(method: method, url: url) do
      {:ok, response} -> {:ok, %{status: response.status, body: normalize_body(response.body)}}
      {:error, exception} -> {:error, exception}
    end
  end

  defp normalize_body(nil), do: ""
  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body) when is_list(body), do: IO.iodata_to_binary(body)

  defp normalize_body(body) do
    case Jason.encode(body) do
      {:ok, encoded} -> encoded
      {:error, _reason} -> inspect(body)
    end
  end

  defp format_reason(%_{} = exception), do: Exception.message(exception)
  defp format_reason(reason), do: inspect(reason)
end
