# Getting Started

## What This Guide Covers

This guide walks through the first end-to-end `CoolifyEx 0.5.1` deployment from a trusted workstation or remote server.

The key idea in `0.5.x` is that deployment verification is split into two phases:

- readiness checks: polled until the app is actually serving traffic
- verification checks: run once after readiness succeeds

That prevents the classic post-deploy race where Coolify reports a deployment finished but the public app is still warming up.

## Prerequisites

Before you open Coolify for this workflow, make sure you already have:

- A running Coolify instance and its URL, such as `https://coolify.example.com`.
- Elixir `>= 1.18`.
- Mix.
- Git.
- `curl`.
- Network access from the deployment machine to the Coolify panel.
- Network access from the deployment machine to the Git remote that Coolify will build from.
- Network access from the deployment machine to the public application URL that readiness and verification will hit.

## One-Time Coolify Setup

1. Enable API access.

   In Coolify, open `Settings`, then `Configuration`, then `Advanced`. Turn on API access and save the change.

2. Create a deploy token.

   Open `Keys & Tokens`, then `API Tokens`. Create a token with permission to start deployments, then copy the value immediately. Coolify shows the token value once.

3. Copy the application UUID.

   Open the application that `CoolifyEx` will deploy. Copy the UUID that Coolify shows for that application.

4. Confirm the public base URL.

   Decide which public URL should own the readiness and verification paths for this application, such as `https://app.example.com`.

5. Choose a readiness endpoint.

   Pick the endpoint that should define "the app is really up". This should usually be a narrow health endpoint such as `/healthz`, not a heavier route.

6. Choose verification endpoints.

   Pick the routes that prove the deployment is behaving correctly after readiness, such as `/`, `/api/targets`, or `/openapi.json`.

## Install CoolifyEx

Add `coolify_ex` to `mix.exs`:

```elixir
def deps do
  [
    {:coolify_ex, "~> 0.5.1", runtime: false}
  ]
end
```

Fetch dependencies:

```bash
mix deps.get
```

## Bootstrap The Remote Server

Run the shipped bootstrap script from the repository root:

```bash
./scripts/setup_remote.sh
```

If you want to write the manifest to a different path, pass that path as the first argument:

```bash
./scripts/setup_remote.sh deploy/.coolify_ex.exs # replace this
```

The bootstrap script checks for `git`, `curl`, and `mix`, copies `coolify.example.exs` to the manifest path if needed, runs `mix deps.get`, and then runs `mix coolify.setup`.

## Export The Required Environment Variables

```bash
export COOLIFY_BASE_URL="https://coolify.example.com" # replace this
export COOLIFY_TOKEN="coolify-api-token" # replace this
export COOLIFY_WEB_APP_UUID="00000000-0000-0000-0000-000000000000" # replace this
export COOLIFY_PUBLIC_BASE_URL="https://app.example.com" # replace this
```

These values stay on the trusted machine and are read by the manifest through `{:env, "NAME"}` tuples.

## Write The Manifest

Start from the shipped example:

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

Before you deploy, confirm:

- `projects.web.public_base_url` points at the public URL you will actually verify.
- `projects.web.readiness.checks` use the endpoint that defines "the app is serving".
- `projects.web.verification.checks` cover the routes that should work after readiness.

## Deploy

Run:

```bash
mix coolify.deploy
```

The task flow is:

1. load the manifest
2. optionally push Git
3. start the Coolify deployment
4. wait for Coolify to report deployment completion
5. poll readiness until success or timeout
6. run verification checks once

A typical success looks like:

```text
Deployment finished: dep-123
Readiness passed after 2 attempt(s)
Verification passed: 2/2 checks
```

This means:

- Coolify accepted and finished the deployment
- the live app eventually answered the readiness contract
- every verification check passed after the app became ready

In `0.5.1`, the readiness attempt count now reflects real HTTP polls rather than hidden transport retries inside Req.

## Inspect The Result

After deployment, the normal operator path is:

```bash
mix coolify.latest --project web
mix coolify.logs --project web --latest --tail 200
mix coolify.app_logs --project web --lines 200
```

This covers the newest deployment summary, deployment/build logs, and runtime application logs.

## Common Failure Cases

| Problem | What you see | What to do |
| --- | --- | --- |
| `COOLIFY_TOKEN` is missing | `** (Mix) Coolify deploy failed: {:missing_required_value, :token}` | Export the token before running the task. |
| Readiness never succeeds | `** (Mix) Verification failed during readiness ...` | Fix the app boot sequence, increase the readiness timeout, or use a better readiness endpoint. |
| Verification fails after readiness | `** (Mix) Verification failed with N failing checks` | Fix the application behavior or correct the verification expectations in the manifest. |
| Relative check URL without a usable `public_base_url` | request errors against `/healthz` or similar | Set `public_base_url` or switch the check to an absolute URL. |
| The current Git branch is not the branch in the manifest | `** (Mix) Coolify deploy failed: {:branch_mismatch, ...}` | Check out the configured branch or deploy with `--no-push` if you already pushed from elsewhere. |

## What To Read Next

- Read [manifest.md](manifest.md) for the full manifest key reference and the exact readiness/verification contract.
- Read [mix-tasks.md](mix-tasks.md) for task flags and output details.
- Read [remote-server.md](remote-server.md) if you want to keep deploy credentials on a dedicated server instead of a developer laptop.
