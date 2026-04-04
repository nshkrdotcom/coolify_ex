defmodule Mix.Tasks.Coolify.StatusTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Coolify.Status, as: StatusTask

  setup do
    Mix.Task.reenable("coolify.status")

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

  test "prints status for the latest deployment of a configured project", %{
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
        ~s({
          "status":"finished",
          "deployment_url":"/project/demo/deployment/dep-123",
          "commit":"abc123",
          "commit_message":"Add deployment lookup",
          "created_at":"2026-03-28T07:42:19Z",
          "finished_at":"2026-03-28T07:44:02Z"
        })
      )
    end)

    output =
      capture_io(fn ->
        StatusTask.run([
          "--config",
          fixture_path("coolify_manifest.exs"),
          "--project",
          "web",
          "--latest"
        ])
      end)

    assert output =~ "Project: web"
    assert output =~ "Latest deployment: dep-123"
    assert output =~ "Status: finished"
    assert output =~ "Logs: /project/demo/deployment/dep-123"
  end

  test "prints status when latest deployment uses deployment_uuid", %{
    base_url: base_url,
    bypass: bypass
  } do
    System.put_env("COOLIFY_BASE_URL", base_url)

    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert conn.query_string == "take=1"
      Plug.Conn.resp(conn, 200, ~s([{"deployment_uuid":"dep-456","status":"finished"}]))
    end)

    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/dep-456", fn conn ->
      Plug.Conn.resp(
        conn,
        200,
        ~s({
          "deployment_uuid":"dep-456",
          "status":"finished",
          "deployment_url":"/project/demo/deployment/dep-456",
          "commit":"abc123",
          "commit_message":"Add deployment lookup",
          "created_at":"2026-03-28T07:42:19Z",
          "finished_at":"2026-03-28T07:44:02Z"
        })
      )
    end)

    output =
      capture_io(fn ->
        StatusTask.run([
          "--config",
          fixture_path("coolify_manifest.exs"),
          "--project",
          "web",
          "--latest"
        ])
      end)

    assert output =~ "Project: web"
    assert output =~ "Latest deployment: dep-456"
    assert output =~ "Status: finished"
    assert output =~ "Logs: /project/demo/deployment/dep-456"
  end

  test "raises a usage error when uuid and --latest are both missing" do
    assert_raise Mix.Error, ~r/Usage: mix coolify.status DEPLOYMENT_UUID/, fn ->
      capture_io(fn ->
        StatusTask.run(["--config", fixture_path("coolify_manifest.exs")])
      end)
    end
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "..", "..", "fixtures", name])
  end
end
