defmodule CoolifyEx.DeployerTest do
  use ExUnit.Case, async: true

  alias CoolifyEx.Config
  alias CoolifyEx.Config.App
  alias CoolifyEx.Deployer
  alias CoolifyEx.Deployment
  alias CoolifyEx.TestSupport.FakeClient
  alias CoolifyEx.TestSupport.FakeGit

  test "pushes and polls until deployment finishes" do
    FakeGit.set_current_branch("main")
    FakeGit.allow_push()

    FakeClient.set_start_response({:ok, %Deployment{uuid: "dep-123"}})

    FakeClient.set_fetch_responses([
      {:ok, %Deployment{uuid: "dep-123", status: "in_progress"}},
      {:ok, %Deployment{uuid: "dep-123", status: "finished"}}
    ])

    assert {:ok, %Deployment{uuid: "dep-123", status: "finished"}} =
             Deployer.deploy(config(), "web",
               client: FakeClient,
               git: FakeGit,
               sleep: fn _ms -> :ok end,
               poll_interval: 0,
               timeout: 1_000
             )
  end

  test "returns a branch mismatch error before pushing" do
    FakeGit.set_current_branch("feature/demo")

    assert {:error, {:branch_mismatch, "feature/demo", "main"}} =
             Deployer.deploy(config(), "web",
               client: FakeClient,
               git: FakeGit,
               sleep: fn _ms -> :ok end,
               poll_interval: 0,
               timeout: 1_000
             )
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
          smoke_checks: []
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
          smoke_checks: []
        }
      }
    }
  end
end
