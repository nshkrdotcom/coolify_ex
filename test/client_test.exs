defmodule CoolifyEx.ClientTest do
  use ExUnit.Case, async: true

  alias CoolifyEx.ApplicationLogs
  alias CoolifyEx.Client
  alias CoolifyEx.Deployment

  setup do
    bypass = Bypass.open()
    %{base_url: "http://localhost:#{bypass.port}", bypass: bypass}
  end

  test "starts a deployment through the Coolify API", %{base_url: base_url, bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/v1/applications/app-123/start", fn conn ->
      assert ["Bearer token-123"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.query_string == "force=true&instant_deploy=false"
      Plug.Conn.resp(conn, 200, ~s({"deployment_uuid":"dep-123"}))
    end)

    assert {:ok, deployment} =
             Client.start_deployment(base_url, "token-123", "app-123",
               force: true,
               instant: false
             )

    assert deployment.uuid == "dep-123"
  end

  test "fetches deployment status and decodes log lines", %{base_url: base_url, bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/dep-123", fn conn ->
      assert ["Bearer token-123"] = Plug.Conn.get_req_header(conn, "authorization")

      Plug.Conn.resp(
        conn,
        200,
        ~s({
          "status":"finished",
          "deployment_url":"/project/demo/deployment/dep-123",
          "commit":"abc123",
          "logs":"[{\\"timestamp\\":\\"2026-03-27T00:00:00Z\\",\\"output\\":\\"done\\"}]"
        })
      )
    end)

    assert {:ok, deployment} = Client.fetch_deployment(base_url, "token-123", "dep-123")
    assert deployment.status == "finished"
    assert deployment.commit == "abc123"
    assert deployment.deployment_url == "/project/demo/deployment/dep-123"
    assert Enum.map(deployment.logs, & &1.output) == ["done"]
  end

  test "fetches application logs and splits runtime lines", %{base_url: base_url, bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/v1/applications/app-123/logs", fn conn ->
      assert ["Bearer token-123"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.query_string == "lines=250"
      Plug.Conn.resp(conn, 200, ~s({"logs":"booted\\nhandled request\\n"}))
    end)

    assert {:ok, %ApplicationLogs{} = application_logs} =
             Client.fetch_application_logs(base_url, "token-123", "app-123", lines: 250)

    assert application_logs.app_uuid == "app-123"
    assert application_logs.raw == "booted\nhandled request\n"
    assert Enum.map(application_logs.logs, & &1.output) == ["booted", "handled request"]
  end

  test "lists application deployments and parses deployment summaries", %{
    base_url: base_url,
    bypass: bypass
  } do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert ["Bearer token-123"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.query_string == "take=2&skip=1"

      Plug.Conn.resp(
        conn,
        200,
        ~s([
          {
            "uuid":"dep-456",
            "status":"finished",
            "commit":"abc123",
            "commit_message":"Add deployment lookup\\n\\nwith task support",
            "created_at":"2026-03-28T07:42:19Z",
            "finished_at":"2026-03-28T07:44:02Z",
            "deployment_url":"/project/demo/deployment/dep-456"
          },
          {
            "uuid":"dep-123",
            "status":"failed",
            "commit":"def456",
            "commit_message":"Broken rollout",
            "created_at":"2026-03-27T07:42:19Z",
            "finished_at":"2026-03-27T07:43:02Z",
            "deployment_url":"/project/demo/deployment/dep-123"
          }
        ])
      )
    end)

    assert {:ok, deployments} =
             Client.list_application_deployments(base_url, "token-123", "app-123",
               take: 2,
               skip: 1
             )

    assert [
             %Deployment{
               uuid: "dep-456",
               status: "finished",
               commit: "abc123",
               commit_message: "Add deployment lookup\n\nwith task support",
               created_at: "2026-03-28T07:42:19Z",
               finished_at: "2026-03-28T07:44:02Z",
               deployment_url: "/project/demo/deployment/dep-456"
             },
             %Deployment{
               uuid: "dep-123",
               status: "failed",
               commit: "def456",
               commit_message: "Broken rollout",
               created_at: "2026-03-27T07:42:19Z",
               finished_at: "2026-03-27T07:43:02Z",
               deployment_url: "/project/demo/deployment/dep-123"
             }
           ] = deployments
  end

  test "fetches the latest application deployment", %{base_url: base_url, bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert conn.query_string == "take=1"
      Plug.Conn.resp(conn, 200, ~s([{"uuid":"dep-456","status":"finished"}]))
    end)

    assert {:ok, %Deployment{uuid: "dep-456", status: "finished"}} =
             Client.fetch_latest_application_deployment(base_url, "token-123", "app-123")
  end

  test "returns a tagged error when an app has no deployments", %{
    base_url: base_url,
    bypass: bypass
  } do
    Bypass.expect(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      Plug.Conn.resp(conn, 200, "[]")
    end)

    assert {:ok, []} = Client.list_application_deployments(base_url, "token-123", "app-123")

    assert {:error, :empty_deployments} =
             Client.fetch_latest_application_deployment(base_url, "token-123", "app-123")
  end

  test "returns invalid json details for malformed deployment listings", %{
    base_url: base_url,
    bypass: bypass
  } do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      Plug.Conn.resp(conn, 200, "not-json")
    end)

    assert {:error, {:invalid_json_body, "not-json", _reason}} =
             Client.list_application_deployments(base_url, "token-123", "app-123")
  end

  test "returns http error details from coolify", %{base_url: base_url, bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"message":"unauthorized"}))
    end)

    assert {:error, {:http_error, 401, %{"message" => "unauthorized"}}} =
             Client.list_application_deployments(base_url, "token-123", "app-123")
  end

  test "normalizes latest deployments from deployment_uuid field", %{
    base_url: base_url,
    bypass: bypass
  } do
    Bypass.expect_once(bypass, "GET", "/api/v1/deployments/applications/app-123", fn conn ->
      assert conn.query_string == "take=1"
      Plug.Conn.resp(conn, 200, ~s([{"deployment_uuid":"dep-456","status":"finished"}]))
    end)

    assert {:ok, %Deployment{uuid: "dep-456", status: "finished"}} =
             Client.fetch_latest_application_deployment(base_url, "token-123", "app-123")
  end
end
