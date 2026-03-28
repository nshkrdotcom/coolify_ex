# Monorepos And Phoenix Apps

Use this guide when one Git repository contains multiple deployable applications and each one needs its own Coolify application entry.

## How Multi-Project Manifests Work

`CoolifyEx` uses one manifest file with multiple entries under `:projects`:

- Each project entry has its own `app_uuid`.
- Each project entry has its own `project_path`.
- Each project entry has its own `public_base_url`.
- Each project entry has its own `smoke_checks`.
- `default_project` decides which entry runs when you omit `--project`.

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
      smoke_checks: [
        %{name: "Landing page", url: "/", expected_status: 200},
        %{name: "Web health", url: "/healthz", expected_status: 200, expected_body_contains: "ok"}
      ]
    },
    api: %{
      app_uuid: {:env, "COOLIFY_API_APP_UUID"},
      git_branch: "main",
      git_remote: "origin",
      project_path: "apps/api",
      public_base_url: "https://api.example.com", # replace this
      smoke_checks: [
        %{name: "API health", url: "/healthz", expected_status: 200},
        %{name: "OpenAPI", url: "/openapi.json", expected_status: 200}
      ]
    }
  }
}
```

This single manifest can trigger either app while keeping UUIDs, URLs, and smoke checks isolated per project.

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

This is the correct behavior for monorepos because Coolify still needs the repository's actual branch tip, not a subtree-only push that Git does not support.

## Smoke Check Isolation

Run verification for just one project entry:

```bash
mix coolify.verify --project api
```

This runs only the `api` smoke checks from the manifest, not the `web` checks.

The verifier builds the result from the selected project's `smoke_checks` list only, so `web` failures do not affect `api` verification unless you selected `web`.

## Non-Phoenix Use Cases

`CoolifyEx` does not care whether `apps/web` and `apps/api` are Phoenix applications. The same pattern works for:

- A Phoenix frontend plus a Plug API.
- A worker or queue processor that exposes an admin or readiness endpoint.
- A mixed repository where only some children are web-facing.
- A Phoenix umbrella or non-umbrella repo that still wants separate Coolify applications.

The only requirement for smoke checks is that each project entry has a real HTTP endpoint worth verifying.

## What Can Go Wrong

| Problem | What you see | How to fix |
| --- | --- | --- |
| You deploy the wrong project because you forgot `--project`. | The deploy task uses `default_project`, or the library returns `{:error, :default_project_not_configured}` if no default exists. | Set `default_project` deliberately and use `--project` for non-default apps. |
| One project's UUID env var is missing. | Manifest load fails before deployment with `{:missing_required_value, :app_uuid}`. | Export every required UUID env var in the manifest, even if you only plan to deploy one project this time. |
| `project_path` points at a directory that no longer exists. | `** (Mix) Coolify deploy failed: {:project_path_not_found, "api", "apps/api"}` or the same pattern for another project. | Update the path to match the current repository layout. |
| The selected project's `git_branch` does not match the current checkout. | `** (Mix) Coolify deploy failed: {:branch_mismatch, "main", "release"}`. | Check out the expected branch or use `--no-push` if the branch is already pushed and you only want to trigger Coolify. |
| A project entry uses relative smoke-check URLs without `public_base_url`. | `** (ArgumentError) scheme is required for url: /healthz` during verification. | Add `public_base_url` for that project or switch the smoke checks to absolute URLs. |

## See Also

- [guides/getting-started.md](getting-started.md) when you want the first deploy flow before introducing multiple projects.
- [guides/manifest.md](manifest.md) when you need the exact meaning of `projects`, `default_project`, `project_path`, and smoke-check expansion.
- [guides/mix-tasks.md](mix-tasks.md) when you need the exact `--project`, timeout, polling, and verification behavior for the CLI tasks.
- [guides/remote-server.md](remote-server.md) when you want to run monorepo deploys from a dedicated server with local secrets.
