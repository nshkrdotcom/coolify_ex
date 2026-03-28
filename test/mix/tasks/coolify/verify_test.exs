defmodule Mix.Tasks.Coolify.VerifyTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Coolify.Verify, as: VerifyTask

  setup do
    Mix.Task.reenable("coolify.verify")

    System.put_env("COOLIFY_BASE_URL", "https://coolify.example.com")
    System.put_env("COOLIFY_TOKEN", "token-123")
    System.put_env("COOLIFY_WEB_APP_UUID", "app-123")

    on_exit(fn ->
      System.delete_env("COOLIFY_BASE_URL")
      System.delete_env("COOLIFY_TOKEN")
      System.delete_env("COOLIFY_WEB_APP_UUID")
    end)
  end

  test "raises a clean error when the selected project does not exist" do
    assert_raise Mix.Error, ~r/Could not verify app: \{:unknown_project, "missing"\}/, fn ->
      capture_io(fn ->
        VerifyTask.run(["--config", fixture_path("coolify_manifest.exs"), "--project", "missing"])
      end)
    end
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "..", "..", "fixtures", name])
  end
end
