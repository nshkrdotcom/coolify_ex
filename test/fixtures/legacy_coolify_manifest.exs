%{
  version: 1,
  base_url: {:env, "COOLIFY_BASE_URL"},
  token: {:env, "COOLIFY_TOKEN"},
  default_app: :web,
  apps: %{
    web: %{
      app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
      git_branch: "main",
      git_remote: "origin",
      project_path: ".",
      public_base_url: "https://app.example.com",
      smoke_checks: [
        %{name: "Root", url: "/", expected_status: 200}
      ]
    }
  }
}
