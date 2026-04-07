defmodule CoolifyEx.Verifier do
  @moduledoc """
  Waits for a deployed app to become ready, then runs post-ready verification checks.
  """

  alias CoolifyEx.Config
  alias CoolifyEx.Verifier.CheckResult
  alias CoolifyEx.Verifier.PhaseResult
  alias CoolifyEx.Verifier.Result

  @spec verify(Config.t(), String.t() | atom(), keyword()) ::
          {:ok, Result.t()} | {:error, Result.t() | term()}
  def verify(%Config{} = config, app_name, opts \\ []) do
    request = Keyword.get(opts, :request, &default_request/2)
    sleep_fun = Keyword.get(opts, :sleep, &:timer.sleep/1)
    now_ms = Keyword.get(opts, :now_ms, fn -> System.monotonic_time(:millisecond) end)

    with {:ok, app} <- Config.fetch_app(config, app_name),
         {:ok, readiness} <- await_readiness(app, request, sleep_fun, now_ms) do
      verification = run_phase(:verification, app.verification_checks, request)
      result = %Result{app: app.name, readiness: readiness, verification: verification}

      if verification.failed == 0 do
        {:ok, result}
      else
        {:error, result}
      end
    else
      {:error, %PhaseResult{} = readiness} ->
        {:error,
         %Result{
           app: normalize_app_name(config, app_name),
           readiness: readiness,
           verification: empty_phase(:verification)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp await_readiness(app, request, sleep_fun, now_ms) do
    started_at = now_ms.()

    if app.readiness_initial_delay_ms > 0 do
      sleep_fun.(app.readiness_initial_delay_ms)
    end

    do_await_readiness(app, request, sleep_fun, now_ms, started_at, 1)
  end

  defp do_await_readiness(app, request, sleep_fun, now_ms, started_at, attempts) do
    phase = run_phase(:readiness, app.readiness_checks, request)
    duration_ms = max(now_ms.() - started_at, 0)
    phase = %{phase | attempts: attempts, duration_ms: duration_ms}

    cond do
      phase.failed == 0 ->
        {:ok, phase}

      duration_ms >= app.readiness_timeout_ms ->
        {:error, phase}

      true ->
        sleep_fun.(app.readiness_poll_interval_ms)
        do_await_readiness(app, request, sleep_fun, now_ms, started_at, attempts + 1)
    end
  end

  defp run_phase(name, checks, request) do
    checks = Enum.map(checks, &run_check(name, &1, request))
    build_phase(name, checks)
  end

  defp run_check(phase, check, request) do
    case request.(check.method, check.url) do
      {:ok, %{status: status, body: body}} ->
        evaluate_response(phase, check, status, body)

      {:error, reason} ->
        %CheckResult{
          phase: phase,
          name: check.name,
          url: check.url,
          reason: format_reason(reason),
          ok?: false
        }
    end
  end

  defp evaluate_response(phase, check, status, body) do
    body = body || ""

    cond do
      status != check.expected_status ->
        %CheckResult{
          phase: phase,
          name: check.name,
          url: check.url,
          status: status,
          reason: "expected HTTP #{check.expected_status}, got #{status}",
          ok?: false
        }

      is_binary(check.expected_body_contains) and
          not String.contains?(body, check.expected_body_contains) ->
        %CheckResult{
          phase: phase,
          name: check.name,
          url: check.url,
          status: status,
          reason: "response body did not include expected text",
          ok?: false
        }

      true ->
        %CheckResult{phase: phase, name: check.name, url: check.url, status: status, ok?: true}
    end
  end

  defp build_phase(name, checks) do
    failed = Enum.count(checks, &(!&1.ok?))
    total = length(checks)

    %PhaseResult{
      name: name,
      attempts: 1,
      duration_ms: 0,
      total: total,
      passed: total - failed,
      failed: failed,
      checks: checks
    }
  end

  defp empty_phase(name) do
    %PhaseResult{
      name: name,
      attempts: 0,
      duration_ms: 0,
      total: 0,
      passed: 0,
      failed: 0,
      checks: []
    }
  end

  defp normalize_app_name(config, app_name) do
    case Config.fetch_app(config, app_name) do
      {:ok, app} -> app.name
      {:error, _reason} -> to_string(app_name)
    end
  end

  defp default_request(method, url) do
    case Req.request(method: method, url: url, retry: false) do
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
