defmodule Mix.Tasks.Coolify.LatestTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Coolify.Latest, as: LatestTask

  setup do
    Mix.Task.reenable("coolify.latest")

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

  test "prints the latest deployment in json mode", %{base_url: base_url, bypass: bypass} do
    System.put_env("COOLIFY_BASE_URL", base_url)

    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert conn.query_string == "take=1"

      Plug.Conn.resp(
        conn,
        200,
        ~s([
          {
            "uuid":"dep-123",
            "status":"finished",
            "commit":"abc123",
            "commit_message":"Add deployment lookup",
            "created_at":"2026-03-28T07:42:19Z",
            "finished_at":"2026-03-28T07:44:02Z"
          }
        ])
      )
    end)

    output =
      capture_io(fn ->
        LatestTask.run(["--config", fixture_path("coolify_manifest.exs"), "--json"])
      end)

    assert {:ok,
            %{
              "project" => "web",
              "app_uuid" => "app-123",
              "deployment" => %{
                "uuid" => "dep-123",
                "status" => "finished",
                "commit" => "abc123",
                "commit_message" => "Add deployment lookup",
                "created_at" => "2026-03-28T07:42:19Z",
                "finished_at" => "2026-03-28T07:44:02Z"
              }
            }} = Jason.decode(output)
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "..", "..", "fixtures", name])
  end
end
