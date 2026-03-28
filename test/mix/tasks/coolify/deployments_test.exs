defmodule Mix.Tasks.Coolify.DeploymentsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Coolify.Deployments, as: DeploymentsTask

  setup do
    Mix.Task.reenable("coolify.deployments")

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

  test "prints recent deployments for the configured project", %{
    base_url: base_url,
    bypass: bypass
  } do
    System.put_env("COOLIFY_BASE_URL", base_url)

    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert conn.query_string == "take=2"

      Plug.Conn.resp(
        conn,
        200,
        ~s([
          {
            "uuid":"dep-123",
            "status":"finished",
            "commit":"abc123",
            "commit_message":"Add deployment lookup\\n\\nwith tests",
            "created_at":"2026-03-28T07:42:19Z",
            "finished_at":"2026-03-28T07:44:02Z"
          }
        ])
      )
    end)

    output =
      capture_io(fn ->
        DeploymentsTask.run(["--config", fixture_path("coolify_manifest.exs"), "--take", "2"])
      end)

    assert output =~ "Project: web"
    assert output =~ "dep-123"
    assert output =~ "abc123"
    assert output =~ "Add deployment lookup"
  end

  test "prints json output for scripts", %{base_url: base_url, bypass: bypass} do
    System.put_env("COOLIFY_BASE_URL", base_url)

    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert conn.query_string == "take=1"
      Plug.Conn.resp(conn, 200, ~s([{"uuid":"dep-123","status":"finished"}]))
    end)

    output =
      capture_io(fn ->
        DeploymentsTask.run(["--config", fixture_path("coolify_manifest.exs"), "--json"])
      end)

    assert {:ok,
            %{
              "project" => "web",
              "app_uuid" => "app-123",
              "deployments" => [%{"uuid" => "dep-123", "status" => "finished"}]
            }} = Jason.decode(output)
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "..", "..", "fixtures", name])
  end
end
