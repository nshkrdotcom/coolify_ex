defmodule CoolifyEx.ConfigTest do
  use ExUnit.Case, async: true

  alias CoolifyEx.Config

  test "loads a manifest and resolves environment-backed secrets" do
    path = fixture_path("coolify_manifest.exs")

    env = %{
      "COOLIFY_BASE_URL" => "https://coolify.example.com",
      "COOLIFY_TOKEN" => "secret-token",
      "COOLIFY_WEB_APP_UUID" => "app-uuid-123"
    }

    assert {:ok, config} = Config.load(path, env: env)
    assert config.base_url == "https://coolify.example.com"
    assert config.token == "secret-token"
    assert config.default_app == "web"

    assert {:ok, web} = Config.fetch_app(config, "web")
    assert web.app_uuid == "app-uuid-123"
    assert web.project_path == "."
    assert length(web.smoke_checks) == 2
    assert Enum.at(web.smoke_checks, 0).url == "https://app.example.com/"
    assert Enum.at(web.smoke_checks, 1).url == "https://app.example.com/healthz"
  end

  test "returns an error when the manifest file is missing" do
    assert {:error, {:manifest_not_found, _path}} = Config.load("does-not-exist.exs", env: %{})
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "fixtures", name])
  end
end
