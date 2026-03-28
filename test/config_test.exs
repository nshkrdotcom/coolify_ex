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
    assert config.default_project == "web"
    assert config.default_app == "web"

    assert {:ok, web} = Config.fetch_project(config, "web")
    assert web.app_uuid == "app-uuid-123"
    assert web.project_path == "."
    assert length(web.smoke_checks) == 2
    assert Enum.at(web.smoke_checks, 0).url == "https://app.example.com/"
    assert Enum.at(web.smoke_checks, 1).url == "https://app.example.com/healthz"
  end

  test "supports legacy apps/default_app manifest keys" do
    path = fixture_path("legacy_coolify_manifest.exs")

    env = %{
      "COOLIFY_BASE_URL" => "https://coolify.example.com",
      "COOLIFY_TOKEN" => "secret-token",
      "COOLIFY_WEB_APP_UUID" => "app-uuid-123"
    }

    assert {:ok, config} = Config.load(path, env: env)
    assert config.default_project == "web"
    assert config.projects["web"].app_uuid == "app-uuid-123"
  end

  test "returns an error when the manifest file is missing" do
    assert {:error, {:manifest_not_found, _path}} = Config.load("does-not-exist.exs", env: %{})
  end

  test "discovers the manifest in a parent directory using root dotfile names" do
    root =
      Path.join(System.tmp_dir!(), "coolify_ex_config_test_#{System.unique_integer([:positive])}")

    nested = Path.join(root, "apps/server")
    File.mkdir_p!(nested)

    on_exit(fn -> File.rm_rf(root) end)

    File.write!(
      Path.join(root, ".coolify_ex.exs"),
      """
      %{
        base_url: {:env, "COOLIFY_BASE_URL"},
        token: {:env, "COOLIFY_TOKEN"},
        default_project: :web,
        projects: %{
          web: %{
            app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
            project_path: "apps/server"
          }
        }
      }
      """
    )

    env = %{
      "COOLIFY_BASE_URL" => "https://coolify.example.com",
      "COOLIFY_TOKEN" => "secret-token",
      "COOLIFY_WEB_APP_UUID" => "app-uuid-123"
    }

    assert {:ok, config} = Config.load(nil, cwd: nested, env: env)
    assert config.manifest_path == Path.join(root, ".coolify_ex.exs")
    assert {:ok, _project} = Config.fetch_project(config, "web")
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "fixtures", name])
  end
end
