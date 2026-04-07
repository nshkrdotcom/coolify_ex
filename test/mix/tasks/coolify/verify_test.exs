defmodule Mix.Tasks.Coolify.VerifyTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Coolify.Verify, as: VerifyTask

  setup do
    Mix.Task.reenable("coolify.verify")

    System.put_env("COOLIFY_BASE_URL", "https://coolify.example.com")
    System.put_env("COOLIFY_TOKEN", "token-123")
    System.put_env("COOLIFY_WEB_APP_UUID", "app-123")
    System.put_env("COOLIFY_PUBLIC_BASE_URL", "https://app.example.com")

    on_exit(fn ->
      System.delete_env("COOLIFY_BASE_URL")
      System.delete_env("COOLIFY_TOKEN")
      System.delete_env("COOLIFY_WEB_APP_UUID")
      System.delete_env("COOLIFY_PUBLIC_BASE_URL")
    end)

    bypass = Bypass.open()
    %{base_url: "http://localhost:#{bypass.port}", bypass: bypass}
  end

  test "raises a clean error when the selected project does not exist" do
    assert_raise Mix.Error, ~r/Could not verify app: \{:unknown_project, "missing"\}/, fn ->
      capture_io(fn ->
        VerifyTask.run(["--config", fixture_path("coolify_manifest.exs"), "--project", "missing"])
      end)
    end
  end

  test "prints readiness and verification success output", %{base_url: base_url, bypass: bypass} do
    System.put_env("COOLIFY_PUBLIC_BASE_URL", base_url)

    Bypass.expect_once(bypass, "GET", "/healthz", fn conn ->
      Plug.Conn.resp(conn, 200, "healthy")
    end)

    Bypass.expect_once(bypass, "GET", "/api/targets", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"data":[]}))
    end)

    output =
      capture_io(fn ->
        VerifyTask.run(["--config", fixture_path("coolify_manifest.exs")])
      end)

    assert output =~ "Readiness passed for web after 1 attempt(s)"
    assert output =~ "Verification passed: 1/1 checks"
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "..", "..", "fixtures", name])
  end
end
