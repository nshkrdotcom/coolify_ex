defmodule Mix.Tasks.Coolify.LogsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Coolify.Logs, as: LogsTask

  setup do
    Mix.Task.reenable("coolify.logs")

    System.put_env("COOLIFY_BASE_URL", "https://coolify.example.com")
    System.put_env("COOLIFY_TOKEN", "token-123")
    System.put_env("COOLIFY_WEB_APP_UUID", "app-123")

    on_exit(fn ->
      System.delete_env("COOLIFY_BASE_URL")
      System.delete_env("COOLIFY_TOKEN")
      System.delete_env("COOLIFY_WEB_APP_UUID")
    end)

    bypass = Bypass.open()
    %{base_url: "http://localhost:#{bypass.port}", bypass: bypass}
  end

  test "prints logs for the latest deployment of a configured project", %{
    base_url: base_url,
    bypass: bypass
  } do
    System.put_env("COOLIFY_BASE_URL", base_url)

    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert conn.query_string == "take=1"
      Plug.Conn.resp(conn, 200, ~s([{"uuid":"dep-123","status":"finished"}]))
    end)

    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/dep-123", fn conn ->
      Plug.Conn.resp(
        conn,
        200,
        ~s({"status":"finished","logs":"[{\\"timestamp\\":\\"2026-03-28T07:42:19Z\\",\\"output\\":\\"build start\\"},{\\"timestamp\\":\\"2026-03-28T07:44:02Z\\",\\"output\\":\\"build done\\"}]"})
      )
    end)

    output =
      capture_io(fn ->
        LogsTask.run([
          "--config",
          fixture_path("coolify_manifest.exs"),
          "--project",
          "web",
          "--latest",
          "--tail",
          "1"
        ])
      end)

    refute output =~ "build start"
    assert output =~ "build done"
  end

  test "raises a usage error when uuid and --latest are both missing" do
    assert_raise Mix.Error, ~r/Usage: mix coolify.logs DEPLOYMENT_UUID/, fn ->
      capture_io(fn ->
        LogsTask.run(["--config", fixture_path("coolify_manifest.exs")])
      end)
    end
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "..", "..", "fixtures", name])
  end
end
