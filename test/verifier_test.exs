defmodule CoolifyEx.VerifierTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Bypass
  alias CoolifyEx.Config
  alias CoolifyEx.Config.App
  alias CoolifyEx.HTTPCheck
  alias CoolifyEx.Verifier

  test "waits for readiness before running verification checks" do
    request = fn
      :get, "https://app.example.com/healthz" ->
        case Process.get(:readiness_calls, 0) do
          0 ->
            Process.put(:readiness_calls, 1)
            {:ok, %{status: 502, body: "bad gateway"}}

          1 ->
            Process.put(:readiness_calls, 2)
            {:ok, %{status: 200, body: "healthy"}}
        end

      :get, "https://app.example.com/api/targets" ->
        Process.put(:verification_calls, Process.get(:verification_calls, 0) + 1)
        {:ok, %{status: 200, body: ~s({"data":[]})}}
    end

    assert {:ok, result} =
             Verifier.verify(config(), "web",
               request: request,
               sleep: fn _ms -> :ok end
             )

    assert result.readiness.attempts == 2
    assert result.readiness.failed == 0
    assert result.verification.total == 1
    assert result.verification.failed == 0
    assert Process.get(:verification_calls) == 1
  end

  test "returns a readiness failure when the app never becomes ready" do
    request = fn
      :get, "https://app.example.com/healthz" ->
        {:ok, %{status: 502, body: "bad gateway"}}

      :get, "https://app.example.com/api/targets" ->
        flunk("verification should not run before readiness succeeds")
    end

    now_ms = sequence([0, 50, 120, 120])

    assert {:error, result} =
             Verifier.verify(config(), "web",
               request: request,
               sleep: fn _ms -> :ok end,
               now_ms: now_ms
             )

    assert result.readiness.failed == 1
    assert result.readiness.attempts == 2

    assert result.readiness.checks == [
             %CoolifyEx.Verifier.CheckResult{
               phase: :readiness,
               name: "Health",
               url: "https://app.example.com/healthz",
               status: 502,
               reason: "expected HTTP 200, got 502",
               ok?: false
             }
           ]

    assert result.verification.total == 0
    assert result.verification.failed == 0
  end

  test "returns verification failures after readiness succeeds" do
    request = fn
      :get, "https://app.example.com/healthz" ->
        {:ok, %{status: 200, body: "healthy"}}

      :get, "https://app.example.com/api/targets" ->
        {:ok, %{status: 500, body: "nope"}}
    end

    assert {:error, result} = Verifier.verify(config(), "web", request: request)
    assert result.readiness.failed == 0
    assert result.verification.total == 1
    assert result.verification.failed == 1
    assert Enum.any?(result.verification.checks, &(&1.reason == "expected HTTP 200, got 500"))
  end

  test "default HTTP requests do not hide failed readiness polls behind Req retries" do
    bypass = Bypass.open()
    counter = start_supervised!({Agent, fn -> 0 end})
    config = config("http://localhost:#{bypass.port}")

    Bypass.expect(bypass, "GET", "/healthz", fn conn ->
      call_number =
        Agent.get_and_update(counter, fn current ->
          next = current + 1
          {next, next}
        end)

      case call_number do
        1 -> Plug.Conn.resp(conn, 502, "bad gateway")
        2 -> Plug.Conn.resp(conn, 200, "healthy")
      end
    end)

    Bypass.expect_once(bypass, "GET", "/api/targets", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"data":[]}))
    end)

    log =
      capture_log(fn ->
        assert {:ok, result} =
                 Verifier.verify(config, "web", sleep: fn _ms -> :ok end)

        assert result.readiness.attempts == 2
        assert result.readiness.duration_ms >= 0
        assert result.verification.passed == 1
      end)

    refute log =~ "retry: got response with status 502"
  end

  defp config(public_base_url \\ "https://app.example.com") do
    app = %App{
      name: "web",
      app_uuid: "app-123",
      git_branch: "main",
      git_remote: "origin",
      project_path: ".",
      public_base_url: public_base_url,
      readiness_initial_delay_ms: 0,
      readiness_poll_interval_ms: 10,
      readiness_timeout_ms: 100,
      readiness_checks: [
        %HTTPCheck{name: "Health", url: "#{public_base_url}/healthz", expected_status: 200}
      ],
      verification_checks: [
        %HTTPCheck{
          name: "Targets",
          url: "#{public_base_url}/api/targets",
          expected_status: 200,
          expected_body_contains: "\"data\""
        }
      ]
    }

    %Config{
      base_url: "https://coolify.example.com",
      token: "secret",
      default_project: "web",
      manifest_path: "/repo/coolify.exs",
      repo_root: "/repo",
      projects: %{"web" => app}
    }
  end

  defp sequence(values) do
    parent = self()
    counter = :erlang.unique_integer([:positive])

    fn ->
      index = Process.get({parent, counter}, 0)
      Process.put({parent, counter}, index + 1)
      Enum.at(values, index, List.last(values))
    end
  end
end
