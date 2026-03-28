defmodule CoolifyEx.DeploymentsTest do
  use ExUnit.Case, async: true

  alias CoolifyEx.Config
  alias CoolifyEx.Deployment

  setup do
    bypass = Bypass.open()

    env = %{
      "COOLIFY_BASE_URL" => "http://localhost:#{bypass.port}",
      "COOLIFY_TOKEN" => "token-123",
      "COOLIFY_WEB_APP_UUID" => "app-123"
    }

    {:ok, config} = Config.load(fixture_path("coolify_manifest.exs"), env: env)

    %{base_url: env["COOLIFY_BASE_URL"], bypass: bypass, config: config}
  end

  test "lists deployments for the manifest project", %{
    base_url: _base_url,
    bypass: bypass,
    config: config
  } do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert conn.query_string == "take=2"
      Plug.Conn.resp(conn, 200, ~s([{"uuid":"dep-123","status":"finished"}]))
    end)

    assert {:ok, [%Deployment{uuid: "dep-123", status: "finished"}]} =
             CoolifyEx.list_application_deployments(config, "web", take: 2)
  end

  test "fetches the latest deployment for an explicit app uuid", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-999", fn conn ->
      assert conn.query_string == "take=1"
      Plug.Conn.resp(conn, 200, ~s([{"uuid":"dep-999","status":"queued"}]))
    end)

    assert {:ok, %Deployment{uuid: "dep-999", status: "queued"}} =
             CoolifyEx.fetch_latest_application_deployment(config, nil, app_uuid: "app-999")
  end

  test "returns a target-aware empty deployment error", %{bypass: bypass, config: config} do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      Plug.Conn.resp(conn, 200, "[]")
    end)

    assert {:error, {:empty_deployments, %{app_uuid: "app-123", project_name: "web"}}} =
             CoolifyEx.fetch_latest_application_deployment(config, "web")
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "fixtures", name])
  end
end
