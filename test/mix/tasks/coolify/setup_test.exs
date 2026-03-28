defmodule Mix.Tasks.Coolify.SetupTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Coolify.Setup, as: SetupTask

  test "prints a useful onboarding summary" do
    System.put_env("COOLIFY_BASE_URL", "https://coolify.example.com")
    System.put_env("COOLIFY_TOKEN", "token-123")
    System.put_env("COOLIFY_WEB_APP_UUID", "app-123")

    on_exit(fn ->
      System.delete_env("COOLIFY_BASE_URL")
      System.delete_env("COOLIFY_TOKEN")
      System.delete_env("COOLIFY_WEB_APP_UUID")
    end)

    output =
      capture_io(fn ->
        SetupTask.run(["--config", fixture_path("coolify_manifest.exs")])
      end)

    assert output =~ "CoolifyEx remote setup"
    assert output =~ "manifest: ok"
    assert output =~ "Next steps:"
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "..", "..", "fixtures", name])
  end
end
