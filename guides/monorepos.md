# Monorepos And Phoenix Apps

Use this guide when one Git repository contains multiple deployable applications and each one needs its own Coolify application entry.

## How Multi-Project Manifests Work

`CoolifyEx` uses one manifest file with multiple entries under `:projects`.

Each project entry has its own:

- `app_uuid`
- `project_path`
- `public_base_url`
- `readiness`
- `verification`

`default_project` decides which entry runs when you omit `--project`.

The loader normalizes every project entry up front. That means a missing env var in one project can stop the whole manifest from loading, even if you only plan to deploy a different project.

## Full Two-App Monorepo Manifest Example

```elixir
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
      project_path: "apps/web",
      public_base_url: "https://web.example.com", # replace this
      readiness: %{
        checks: [
          %{name: "Web ready", url: "/healthz", expected_status: 200, expected_body_contains: "ok"}
        ]
      },
      verification: %{
        checks: [
          %{name: "Landing page", url: "/", expected_status: 200}
        ]
      }
    },
    api: %{
      app_uuid: {:env, "COOLIFY_API_APP_UUID"},
      git_branch: "main",
      git_remote: "origin",
      project_path: "apps/api",
      public_base_url: "https://api.example.com", # replace this
      readiness: %{
        checks: [
          %{name: "API ready", url: "/healthz", expected_status: 200}
        ]
      },
      verification: %{
        checks: [
          %{name: "OpenAPI", url: "/openapi.json", expected_status: 200}
        ]
      }
    }
  }
}
```

This single manifest can trigger either app while keeping UUIDs, URLs, readiness policies, and verification checks isolated per project.

## Selecting A Project At Deploy Time

Deploy the non-default project explicitly:

```bash
mix coolify.deploy --project api
```

This loads the same manifest but targets the `api` entry instead of `default_project`.

Verify only the default project:

```bash
mix coolify.verify
```

This targets `default_project`, which is `web` in the example manifest above.

If you omit `--project` and the manifest has no `default_project`, the library returns `{:error, :default_project_not_configured}`.

## Git Push Behavior

`CoolifyEx.Deployer.deploy/3` always pushes from `repo_root`, which is the directory that contains the manifest file.

That is the correct behavior for monorepos because Coolify still needs the repository's real branch tip, not a subtree-only push that Git does not support.

## Readiness And Verification Isolation

When you verify `api`, `CoolifyEx` only reads:

- `projects.api.readiness`
- `projects.api.verification`

`web` checks do not affect `api` verification unless you selected `web`.

That isolation is important in monorepos because different apps often expose different health endpoints, different boot times, and different verification surfaces.

## Phoenix-Specific Advice

For Phoenix apps inside a monorepo:

- point `project_path` at the Phoenix app directory
- use a narrow readiness endpoint such as `/healthz` or `/up`
- keep verification checks focused on user-visible or API-visible routes
- avoid using the homepage as readiness unless the homepage is cheap and authoritative

## Common Failure Cases

| Problem | What happens | Fix |
| --- | --- | --- |
| You deploy the wrong project because you forgot `--project`. | The deploy task uses `default_project`. | Set `default_project` deliberately and use `--project` for non-default apps. |
| One project entry is missing an env-backed UUID. | Manifest loading fails before any deployment starts. | Export all required env vars for every project in the manifest. |
| A project entry uses relative check URLs without a usable `public_base_url`. | Readiness or verification requests fail at runtime. | Add `public_base_url` for that project or use absolute URLs. |
| One app has a much slower boot than another. | Verification times out only for the slow app. | Increase that project's `readiness.timeout_ms`; do not inflate the timeout for unrelated projects. |

## Related Guides

- [guides/manifest.md](manifest.md) when you need the exact meaning of `projects`, `default_project`, `project_path`, and URL expansion.
- [guides/mix-tasks.md](mix-tasks.md) for task flags and examples.
