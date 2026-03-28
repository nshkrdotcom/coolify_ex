defmodule Mix.Tasks.Coolify.AppLogsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Coolify.AppLogs, as: AppLogsTask

  setup do
    Mix.Task.reenable("coolify.app_logs")

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

  test "prints runtime app logs for the configured project", %{base_url: base_url, bypass: bypass} do
    System.put_env("COOLIFY_BASE_URL", base_url)

    Bypass.expect_once(bypass, "GET", "/api/v1/applications/app-123/logs", fn conn ->
      assert conn.query_string == "lines=2"
      Plug.Conn.resp(conn, 200, ~s({"logs":"booted\\nhandled request"}))
    end)

    output =
      capture_io(fn ->
        AppLogsTask.run(["--config", fixture_path("coolify_manifest.exs"), "--lines", "2"])
      end)

    assert output =~ "booted"
    assert output =~ "handled request"
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "..", "..", "fixtures", name])
  end
end
