defmodule CoolifyEx.VerifierTest do
  use ExUnit.Case, async: true

  alias CoolifyEx.Config
  alias CoolifyEx.Config.App
  alias CoolifyEx.SmokeCheck
  alias CoolifyEx.Verifier

  test "returns ok when all smoke checks pass" do
    request = fn
      :get, "https://app.example.com/" -> {:ok, %{status: 200, body: "<html>ok</html>"}}
      :get, "https://app.example.com/healthz" -> {:ok, %{status: 200, body: "healthy"}}
    end

    assert {:ok, result} = Verifier.verify(config(), "web", request: request)
    assert result.total == 2
    assert result.failed == 0
    assert result.passed == 2
  end

  test "returns error when a smoke check fails" do
    request = fn
      :get, "https://app.example.com/" -> {:ok, %{status: 500, body: "nope"}}
      :get, "https://app.example.com/healthz" -> {:ok, %{status: 200, body: "healthy"}}
    end

    assert {:error, result} = Verifier.verify(config(), "web", request: request)
    assert result.total == 2
    assert result.failed == 1
    assert Enum.any?(result.checks, &(&1.reason == "expected HTTP 200, got 500"))
  end

  defp config do
    %Config{
      base_url: "https://coolify.example.com",
      token: "secret",
      default_project: "web",
      default_app: "web",
      manifest_path: "/repo/coolify.exs",
      repo_root: "/repo",
      projects: %{
        "web" => %App{
          name: "web",
          app_uuid: "app-123",
          git_branch: "main",
          git_remote: "origin",
          project_path: ".",
          public_base_url: "https://app.example.com",
          smoke_checks: [
            %SmokeCheck{name: "root", url: "https://app.example.com/", expected_status: 200},
            %SmokeCheck{
              name: "health",
              url: "https://app.example.com/healthz",
              expected_status: 200
            }
          ]
        }
      },
      apps: %{
        "web" => %App{
          name: "web",
          app_uuid: "app-123",
          git_branch: "main",
          git_remote: "origin",
          project_path: ".",
          public_base_url: "https://app.example.com",
          smoke_checks: [
            %SmokeCheck{name: "root", url: "https://app.example.com/", expected_status: 200},
            %SmokeCheck{
              name: "health",
              url: "https://app.example.com/healthz",
              expected_status: 200
            }
          ]
        }
      }
    }
  end
end
