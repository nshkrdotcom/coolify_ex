# CoolifyEx

<p align="center">
  <img src="assets/coolify_ex.svg" alt="CoolifyEx logo" width="200" />
</p>

<p align="center">
  <a href="https://hex.pm/packages/coolify_ex"><img src="https://img.shields.io/hexpm/v/coolify_ex.svg" alt="Hex.pm Version" /></a>
  <a href="https://hexdocs.pm/coolify_ex/"><img src="https://img.shields.io/badge/docs-hexdocs-2563eb.svg" alt="HexDocs" /></a>
  <a href="https://github.com/nshkrdotcom/coolify_ex"><img src="https://img.shields.io/badge/license-MIT-111827.svg" alt="MIT License" /></a>
  <a href="https://github.com/nshkrdotcom/coolify_ex"><img src="https://img.shields.io/badge/github-nshkrdotcom%2Fcoolify__ex-24292f?style=flat&logo=github" alt="GitHub" /></a>
</p>

`CoolifyEx` is an Elixir library and set of Mix tasks for operating existing Coolify applications from a manifest in your repository. It can trigger deployments, list recent deployments for an app, resolve the latest deployment by manifest project name, inspect deployment logs and runtime application logs, and verify the live app through an explicit two-phase contract:

- readiness checks answer "is the app actually serving yet?"
- verification checks answer "did the deployment come up in the state I expect?"

That distinction is the core change in `0.5.0`. Coolify can mark a deployment finished before the public app is ready to answer HTTP traffic. `CoolifyEx` now models that directly instead of treating every post-deploy request as the same kind of check.

## How It Fits in Your Stack

Your Git repository stays the source of truth. A local manifest tells `CoolifyEx` which Coolify application UUID to deploy, which branch must be current, which public base URL should own relative check paths, which readiness checks must pass before the app is considered up, and which verification checks should run only after readiness succeeds.

```text
Git repo on trusted host
  |
  | load manifest + resolve {:env, "NAME"} tuples
  v
CoolifyEx (Mix task or library call)
  |
  | optional git push remote branch
  | start deployment via Coolify API
  v
Coolify deployment
  |
  | wait for Coolify deployment status to finish
  v
Running application
  |
  | poll readiness checks until the app serves real traffic
  v
Ready application
  |
  | run post-ready verification checks once
  v
Verification result
```

This keeps deployment intent in your repository while leaving build and runtime ownership in Coolify.

## Prerequisites

- A running Coolify instance that you can reach from the deployment machine.
- An application that already exists in Coolify. `CoolifyEx` does not create it.
- API access enabled in Coolify.
- A Coolify API token with permission to start deployments.
- The application UUID for each Coolify app you want to trigger.
- Elixir `~> 1.18`, Mix, Git, and `curl` on the machine that will run the Mix tasks.
- Network access from that machine to the Coolify panel, the Git remote, and each public URL you plan to check.

## Installation

Add `coolify_ex` to your dependencies:

```elixir
def deps do
  [
    {:coolify_ex, "~> 0.5.0", runtime: false}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

`CoolifyEx` is an operator tool, not a runtime application dependency. It targets Elixir `~> 1.18` and depends on `Req` and `Jason`.

## Quick Start

1. Enable API access in the Coolify UI.
2. Create a token with deployment access.
3. Copy the application UUID from Coolify.
4. Add the dependency and run `mix deps.get`.
5. Copy the shipped example manifest or run `./scripts/setup_remote.sh`.
6. Export the env vars the manifest will resolve:

```bash
export COOLIFY_BASE_URL="https://coolify.example.com" # replace this
export COOLIFY_TOKEN="coolify-api-token" # replace this
export COOLIFY_WEB_APP_UUID="00000000-0000-0000-0000-000000000000" # replace this
export COOLIFY_PUBLIC_BASE_URL="https://app.example.com" # replace this
```

7. Edit `.coolify_ex.exs` with the real UUIDs, branch, readiness checks, and verification checks.
8. Deploy:

```bash
mix coolify.deploy
```

On success the task prints the deployment UUID, then a readiness summary, then the verification summary. A typical successful run now looks like:

```text
Deployment finished: dep-123
Readiness passed after 3 attempt(s)
Verification passed: 2/2 checks
```

If readiness never succeeds, the task fails before verification checks run.

## Example Manifest

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
      project_path: ".",
      public_base_url: {:env, "COOLIFY_PUBLIC_BASE_URL"},
      readiness: %{
        initial_delay_ms: 0,
        poll_interval_ms: 2_000,
        timeout_ms: 120_000,
        checks: [
          %{
            name: "HTTP ready",
            url: "/healthz",
            expected_status: 200,
            expected_body_contains: "ok"
          }
        ]
      },
      verification: %{
        checks: [
          %{name: "Landing page", url: "/", expected_status: 200},
          %{name: "Targets API", url: "/api/targets", expected_status: 200}
        ]
      }
    }
  }
}
```

The manifest is deliberately explicit:

- `readiness` is required for each project.
- readiness is polled until it passes or times out.
- `verification.checks` run once, only after readiness succeeds.
- relative URLs are expanded against `public_base_url` when it is present.

## Operator Flow

The canonical operator flow for one manifest project is:

```bash
mix coolify.deploy --project web
mix coolify.latest --project web
mix coolify.logs --project web --latest --tail 200
mix coolify.app_logs --project web --lines 200 --follow
```

`mix coolify.latest` and `mix coolify.logs --latest` remove the need for manual `curl` calls just to discover the newest deployment UUID.

The same lookup is available from the library API:

```elixir
{:ok, deployments} = CoolifyEx.list_application_deployments(config, :web, take: 5)
{:ok, latest} = CoolifyEx.fetch_latest_application_deployment(config, :web)
{:ok, result} = CoolifyEx.verify(config, :web)
```

`CoolifyEx.verify/3` now returns a structured readiness phase result and a structured verification phase result.

## Mix Tasks At A Glance

| Task | What it does | Example |
| --- | --- | --- |
| `mix coolify.setup` | Prints a local or remote-server checklist, checks for `git`, `curl`, and `mix`, and tries to load the manifest. | `mix coolify.setup --config .coolify_ex.exs` |
| `mix coolify.deploy` | Optionally pushes Git, starts a Coolify deployment, waits for completion, waits for readiness, and then runs verification checks. | `mix coolify.deploy --project web --force` |
| `mix coolify.deployments` | Lists recent deployments for a manifest project or explicit app UUID. | `mix coolify.deployments --project web --take 5` |
| `mix coolify.latest` | Fetches the newest deployment for a manifest project or explicit app UUID. | `mix coolify.latest --project web --json` |
| `mix coolify.status` | Fetches one deployment by UUID, or resolves `--project ... --latest` first, then prints status and logs URL. | `mix coolify.status --project web --latest` |
| `mix coolify.logs` | Fetches one deployment by UUID, or resolves `--project ... --latest` first, then prints normalized log lines. | `mix coolify.logs --project web --latest --tail 50` |
| `mix coolify.app_logs` | Fetches runtime logs for one manifest project and can poll for new lines. | `mix coolify.app_logs --project web --lines 200 --follow` |
| `mix coolify.verify` | Waits for readiness and runs verification without starting a new deployment. | `mix coolify.verify --project web` |

## Key Behaviors

- Relative readiness and verification URLs are expanded only when the URL starts with `/` and `public_base_url` is a string.
- `mix coolify.deploy --no-push` skips the Git push step but still loads the manifest, starts the deployment, waits for Coolify, and verifies unless you also pass `--skip-verify`.
- `mix coolify.deployments`, `mix coolify.latest`, `mix coolify.status --latest`, and `mix coolify.logs --latest` all resolve the manifest project to its `app_uuid` before calling Coolify.
- `mix coolify.app_logs` resolves a manifest project to its `app_uuid` and calls Coolify's application-logs endpoint. `--follow` re-polls that endpoint and prints only newly observed lines.
- Deployment/build logs and runtime application logs are different Coolify surfaces. Use `mix coolify.logs` for one deployment record and `mix coolify.app_logs` for the running app container.
- `project_path` must point to an existing directory when the manifest loads, but Git pushes always happen from `repo_root`, which is the directory that contains the manifest.
- Manifest loading is eager. If any required `{:env, "NAME"}` tuple resolves to `nil`, the whole load fails before task-specific work begins.

## Documentation

- [Getting Started](guides/getting-started.md) for the first end-to-end deploy from a trusted machine.
- [Manifest Format](guides/manifest.md) for file discovery, env tuples, project fields, readiness, and verification semantics.
- [Mix Tasks](guides/mix-tasks.md) for every CLI flag, success message, and failure mode.
- [Monorepos and Phoenix Apps](guides/monorepos.md) for one manifest that targets multiple deployable applications.
- [Remote Server Setup](guides/remote-server.md) for keeping credentials off developer laptops and CI.

## License

`CoolifyEx` is released under the MIT License. See [LICENSE](LICENSE).
