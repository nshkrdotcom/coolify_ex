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
      project_path: ".",
      public_base_url: {:env, "COOLIFY_PUBLIC_BASE_URL"},
      readiness: %{
        initial_delay_ms: 1_000,
        poll_interval_ms: 2_000,
        timeout_ms: 60_000,
        checks: [
          %{
            name: "Health",
            url: "/healthz",
            expected_status: 200,
            expected_body_contains: "healthy"
          }
        ]
      },
      verification: %{
        checks: [
          %{
            name: "Targets",
            url: "/api/targets",
            expected_status: 200,
            expected_body_contains: "\"data\""
          }
        ]
      }
    }
  }
}
