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

`CoolifyEx` is an Elixir library and set of Mix tasks for operating existing Coolify applications from a manifest in your repository. It can trigger deployments, list recent deployments for an app, resolve the latest deployment by manifest project name, inspect deployment logs and runtime application logs, and run smoke checks against the live app. It does not create applications in Coolify, replace your Dockerfile or build strategy, or act as a CI/CD system; the main use case is an operator-driven workflow from a trusted workstation or remote server that already has Git, Mix, and the right credentials.

## How It Fits in Your Stack

Your Git repository stays the source of truth. A local manifest tells `CoolifyEx` which Coolify application UUID to deploy, which branch must be current, which smoke checks to run, and which values to resolve from the environment. `CoolifyEx` can then push Git, call the Coolify API, resolve the latest deployment for the manifest project, inspect deployment logs and runtime logs for the same app, and finally verify the live URL that Coolify is serving.

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
  | list deployments for app_uuid
  | resolve latest deployment UUID
  v
Deployment inspection
  |
  | build/deployment logs
  v
Running application
  |
  | fetch runtime logs by manifest project
  v
Runtime log inspection
  |
  | GET/HEAD smoke checks
  v
Verification result
```

This flow keeps deployment intent in your repository while leaving the actual build and runtime environment under Coolify's control.

## Prerequisites

- A running Coolify instance that you can reach from the deployment machine.
- An application that already exists in Coolify; `CoolifyEx` does not create it.
- API access enabled in Coolify.
- A Coolify API token with permission to start deployments.
- The application UUID for each Coolify app you want to trigger.
- Elixir `~> 1.18`, Mix, Git, and `curl` on the machine that will run the Mix tasks.
- Network access from that machine to the Coolify panel, the Git remote, and each public URL you plan to smoke-check.

## Installation

Add `coolify_ex` to your dependencies:

```elixir
def deps do
  [
    {:coolify_ex, "~> 0.4.0", runtime: false}
  ]
end
```

This adds `CoolifyEx` as an operator tool instead of a runtime application process, which matches how the library is used by Mix tasks and deploy scripts.

`CoolifyEx` targets Elixir `~> 1.18`; its runtime dependencies are `Req` and `Jason`, and its dev/test dependencies are `credo`, `dialyxir`, `ex_doc`, and `bypass`.

## Quick Start

1. Enable API access in the Coolify UI.

```bash
# Coolify UI
# Settings -> Configuration -> Advanced
# Enable API access, then save the change.
```

This turns on the API endpoints that `CoolifyEx` calls during deploy and status checks.

2. Create a token with deployment access.

```bash
# Coolify UI
# Keys & Tokens -> API Tokens
# Create a token that can start deployments, then copy it somewhere safe.
```

This gives the deployment machine a bearer token for the Coolify API.

3. Copy the application UUID from Coolify.

```bash
# Coolify UI
# Open the application you want to deploy.
# Copy the application UUID that identifies this app in the API.
```

You need one UUID per manifest project entry.

4. Add the dependency and fetch it locally.

```elixir
def deps do
  [
    {:coolify_ex, "~> 0.4.0", runtime: false}
  ]
end
```

This makes the Mix tasks and library code available in your project.

```bash
mix deps.get
```

This installs `CoolifyEx` and its dependencies into the current project.

5. Run the bootstrap script from the repository root.

```bash
./scripts/setup_remote.sh
```

This checks for `git`, `curl`, and `mix`, copies `coolify.example.exs` to `.coolify_ex.exs` if that file does not exist yet, runs `mix deps.get`, and then runs `mix coolify.setup --config .coolify_ex.exs`.

6. Export the environment variables that the manifest will resolve.

```bash
export COOLIFY_BASE_URL="https://coolify.example.com" # replace this
export COOLIFY_TOKEN="coolify-api-token" # replace this
export COOLIFY_WEB_APP_UUID="00000000-0000-0000-0000-000000000000" # replace this
```

These values stay on the trusted machine and are read at manifest load time through `{:env, "NAME"}` tuples.

7. Copy the shipped example manifest if you did not use the bootstrap script.

```bash
cp coolify.example.exs .coolify_ex.exs
```

This creates the default manifest file name that `CoolifyEx` will discover first.

8. Edit the manifest with the real UUIDs, branch, and smoke-check URLs.

```bash
${EDITOR:-vi} .coolify_ex.exs
```

This is where you bind your local repository to one or more Coolify applications.

9. Trigger the first deployment.

```bash
mix coolify.deploy
```

On success, the task prints `Deployment finished: DEPLOYMENT_UUID` and then `Verification passed: PASSED/TOTAL checks` unless you used `--skip-verify`.

10. Inspect the latest deployment and its logs, then inspect runtime logs.

```bash
mix coolify.latest --project web
mix coolify.logs --project web --latest --tail 200
mix coolify.app_logs --project web --lines 200
```

These commands cover the full operator path after a deploy: latest deployment summary by project, deployment/build logs for that deployment, and runtime application logs for the running app.

## Operator Flow

The canonical operator flow for one manifest project is:

```bash
mix coolify.deploy --project web
mix coolify.latest --project web
mix coolify.logs --project web --latest --tail 200
mix coolify.app_logs --project web --lines 200 --follow
```

`mix coolify.latest` and `mix coolify.logs --latest` remove the old need to run a manual `curl` just to discover the newest deployment UUID.

The same lookup is available in the library API:

```elixir
{:ok, deployments} = CoolifyEx.list_application_deployments(config, :web, take: 5)
{:ok, latest} = CoolifyEx.fetch_latest_application_deployment(config, :web)
{:ok, latest_for_uuid} =
  CoolifyEx.fetch_latest_application_deployment(config, nil, app_uuid: "app-123")
```

## Example Manifest

```elixir
%{
  # Present in the shipped example; the loader currently ignores this key.
  version: 1,
  # Coolify panel URL, resolved from the local shell environment.
  base_url: {:env, "COOLIFY_BASE_URL"},
  # Coolify API token, also resolved from the local shell environment.
  token: {:env, "COOLIFY_TOKEN"},
  # Project selected when you omit --project.
  default_project: :web,
  projects: %{
    web: %{
      # The Coolify application UUID for this project entry.
      app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
      # Branch that must be checked out locally before deploy unless you use --no-push.
      git_branch: "main",
      # Git remote used for the optional push step.
      git_remote: "origin",
      # Use "." for a top-level app or a relative child path for a monorepo app.
      project_path: ".",
      # Public URL used to expand smoke-check paths such as "/healthz".
      public_base_url: "https://example.com", # replace this
      smoke_checks: [
        # GET https://example.com/ and expect HTTP 200.
        %{name: "Landing page", url: "/", expected_status: 200},
        # GET https://example.com/healthz, expect HTTP 200, and require "ok" in the body.
        %{name: "Health", url: "/healthz", expected_status: 200, expected_body_contains: "ok"}
      ]
    }
  }
}
```

This is the shipped `coolify.example.exs` with inline comments describing how each field affects loading, deployment, and verification.

## Mix Tasks At A Glance

| Task | What it does | Example |
| --- | --- | --- |
| `mix coolify.setup` | Prints a local or remote-server checklist, checks for `git`, `curl`, and `mix`, and tries to load the manifest. | `mix coolify.setup --config .coolify_ex.exs` |
| `mix coolify.deploy` | Optionally pushes Git, starts a Coolify deployment, waits for completion, and optionally verifies smoke checks. | `mix coolify.deploy --project web --force` |
| `mix coolify.deployments` | Lists recent deployments for a manifest project or explicit app UUID. | `mix coolify.deployments --project web --take 5` |
| `mix coolify.latest` | Fetches the newest deployment for a manifest project or explicit app UUID. | `mix coolify.latest --project web --json` |
| `mix coolify.status` | Fetches one deployment by UUID, or resolves `--project ... --latest` first, then prints status and logs URL. | `mix coolify.status --project web --latest` |
| `mix coolify.logs` | Fetches one deployment by UUID, or resolves `--project ... --latest` first, then prints normalized log lines. | `mix coolify.logs --project web --latest --tail 50` |
| `mix coolify.app_logs` | Fetches runtime logs for one manifest project and can poll for new lines. | `mix coolify.app_logs --project web --lines 200 --follow` |
| `mix coolify.verify` | Runs the manifest's smoke checks without starting a new deployment. | `mix coolify.verify --project web` |

## Key Behaviors

- Relative smoke-check URLs are expanded only when the URL starts with `/` and `public_base_url` is a string. Otherwise the URL is kept exactly as written.
- `mix coolify.deploy --no-push` skips the Git push step but still loads the manifest, starts the deployment, waits for Coolify, and verifies unless you also pass `--skip-verify`.
- `mix coolify.deployments`, `mix coolify.latest`, `mix coolify.status --latest`, and `mix coolify.logs --latest` all resolve the manifest project to its `app_uuid` before calling Coolify, so normal inspection does not require manual API calls.
- `mix coolify.app_logs` resolves a manifest project to its `app_uuid` and calls Coolify's application-logs endpoint; `--follow` re-polls that endpoint and prints only newly observed lines.
- Deployment/build logs and runtime application logs are different surfaces in Coolify. Use `mix coolify.logs` for one deployment record and `mix coolify.app_logs` for the running app container.
- `project_path` must point to an existing directory when the manifest loads, but Git pushes always happen from `repo_root`, which is the directory that contains the manifest.
- If the Coolify deployment succeeds and a smoke check fails afterward, `mix coolify.deploy` raises `Verification failed with N failing checks`; it does not roll back or mark the deployment itself as failed in Coolify.
- Manifest loading is eager. If any `{:env, "NAME"}` tuple resolves to `nil` for a required field, the whole load fails before any task-specific work begins.

## Documentation

- [Getting Started](guides/getting-started.md) for the first end-to-end deploy from a trusted machine.
- [Manifest Format](guides/manifest.md) for file discovery, env tuples, path validation, and smoke-check rules.
- [Mix Tasks](guides/mix-tasks.md) for every CLI flag, success message, and failure mode.
- [Monorepos and Phoenix Apps](guides/monorepos.md) for one manifest that targets multiple deployable applications.
- [Remote Server Setup](guides/remote-server.md) for keeping credentials off developer laptops and CI.

## License

`CoolifyEx` is released under the MIT License. See [LICENSE](LICENSE).
