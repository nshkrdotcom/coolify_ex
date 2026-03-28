%{
  version: 1,
  base_url: {:env, "COOLIFY_BASE_URL"},
  token: {:env, "COOLIFY_TOKEN"},
  default_project: :web,
  projects: %{
    web: %{
      app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
      git_branch: "main",
      git_remote: "origin",
      # Use "." for a top-level app or a relative child path for monorepos.
      project_path: ".",
      public_base_url: "https://example.com",
      smoke_checks: [
        %{name: "Landing page", url: "/", expected_status: 200},
        %{name: "Health", url: "/healthz", expected_status: 200, expected_body_contains: "ok"}
      ]
    }
  }
}
