# Getting Started

## What This Guide Covers

This guide walks through the first end-to-end `CoolifyEx` deployment from a trusted workstation or remote server.

## Prerequisites

Before you open Coolify for this workflow, make sure you already have:

- A running Coolify instance and its URL, such as `https://coolify.example.com`.
- Elixir `>= 1.18`.
- Mix.
- Git.
- `curl`.
- Network access from the deployment machine to the Coolify panel.
- Network access from the deployment machine to the Git remote that Coolify will build from.

## One-Time Coolify Setup

1. Enable API access.

   In Coolify, open `Settings`, then `Configuration`, then `Advanced`. Turn on API access and save the change.

   You now have API access enabled for the Coolify instance.

2. Create a deploy token.

   Open `Keys & Tokens`, then `API Tokens`. Create a token with permission to start deployments, then copy the value immediately. Coolify shows the token value once.

   You now have a deploy token for the Coolify API.

3. Copy the application UUID.

   Open the application that `CoolifyEx` will deploy. Copy the UUID that Coolify shows for that application.

   You now have the application UUID that will go into the manifest.

4. Confirm the public base URL.

   Decide which public URL should own the smoke-check paths for this application, such as `https://app.example.com` for `/` and `/healthz`.

   You now have the public base URL that the manifest will use for smoke-check URL expansion.

## Install CoolifyEx

Add `coolify_ex` to `mix.exs`:

```elixir
def deps do
  [
    {:coolify_ex, "~> 0.1.0", runtime: false}
  ]
end
```

This adds `CoolifyEx` as an operations dependency rather than a runtime application dependency.

Fetch dependencies:

```bash
mix deps.get
```

This downloads `CoolifyEx` and its dependency tree into the current project.

## Bootstrap The Remote Server

Run the shipped bootstrap script from the repository root:

```bash
./scripts/setup_remote.sh
```

This runs the repository's built-in bootstrap sequence for a deployment host.

If you want to write the manifest to a different path, pass that path as the first argument:

```bash
./scripts/setup_remote.sh deploy/.coolify_ex.exs # replace this
```

This tells the script to use a custom manifest path instead of `.coolify_ex.exs`.

Here is what the script does, in order:

- It calculates `ROOT_DIR` as the repository root that contains the script.
- It sets `CONFIG_PATH` to `.coolify_ex.exs` unless you passed a different first argument.
- It points `EXAMPLE_PATH` at `coolify.example.exs` in the repository root.
- It changes into `ROOT_DIR` with `cd "${ROOT_DIR}"`.
- It checks that `git`, `curl`, and `mix` exist on `PATH`.
- It copies `coolify.example.exs` to `CONFIG_PATH` if that file does not already exist.
- It runs `mix deps.get`.
- It runs `mix coolify.setup --config "${CONFIG_PATH}"`.
- It prints a short next-steps summary.

If you pass a custom path such as `deploy/.coolify_ex.exs`, create the parent directory first because the script does not do that for you.

## Configure Environment Variables

Set the values that the manifest will resolve through `{:env, "NAME"}` tuples. A common place is a deploy user's shell profile such as `~/.bashrc`, `~/.zshrc`, or a sourced env file that your deploy scripts load before running Mix.

```bash
export COOLIFY_BASE_URL="https://coolify.example.com" # replace this
export COOLIFY_TOKEN="coolify-api-token" # replace this
export COOLIFY_WEB_APP_UUID="00000000-0000-0000-0000-000000000000" # replace this
```

This exports the Coolify panel URL, deploy token, and application UUID into the shell that will run `mix`.

Verify that the current shell can see them:

```bash
printenv COOLIFY_BASE_URL COOLIFY_TOKEN COOLIFY_WEB_APP_UUID
```

This prints the current values so you can confirm that the deployment shell has the required variables.

If `COOLIFY_TOKEN` is missing, manifest loading fails and `mix coolify.deploy` raises:

```text
** (Mix) Coolify deploy failed: {:missing_required_value, :token}
```

This is the exact terminal error for a missing deploy token.

## Create And Edit The Manifest

Copy the shipped example manifest:

```bash
cp coolify.example.exs .coolify_ex.exs
```

This creates the default manifest file name that `CoolifyEx` discovers first.

Open the manifest in an editor:

```bash
${EDITOR:-vi} .coolify_ex.exs
```

This opens the manifest so you can replace the example values with the token-backed and UUID-backed values you collected earlier.

Update at least these parts of the example file:

- `base_url` should keep pointing at `{:env, "COOLIFY_BASE_URL"}`.
- `token` should keep pointing at `{:env, "COOLIFY_TOKEN"}`.
- `projects.web.app_uuid` should keep pointing at `{:env, "COOLIFY_WEB_APP_UUID"}` unless you rename the project entry.
- `projects.web.public_base_url` should use the public URL you confirmed in Coolify.
- `projects.web.git_branch` should match the branch you intend to deploy.
- `projects.web.smoke_checks` should match real endpoints that the live app should answer successfully.

Verify the manifest:

```bash
mix coolify.setup
```

This checks for `git`, `curl`, and `mix`, then loads the manifest and prints the resolved base URL and project names if the file is valid.

## First Deployment

Trigger the deployment:

```bash
mix coolify.deploy
```

This optionally pushes Git, starts the Coolify deployment, waits for it to finish, and then runs the configured smoke checks.

A successful run ends with output in this shape:

```text
Deployment finished: dep-123
Verification passed: 2/2 checks
```

This means Coolify reported a successful deployment and every configured smoke check passed.

## What Can Go Wrong

| Problem | What you see | How to fix |
| --- | --- | --- |
| The manifest file does not exist at the requested or discovered path. | `** (Mix) Coolify deploy failed: {:manifest_not_found, ...}` | Create `.coolify_ex.exs`, `.coolify.exs`, or `coolify.exs`, or pass `--config PATH`. |
| The deploy token is missing from the environment. | `** (Mix) Coolify deploy failed: {:missing_required_value, :token}` | Export `COOLIFY_TOKEN` in the shell that runs `mix`, then verify it with `printenv`. |
| The current Git branch does not match `git_branch` in the manifest. | `** (Mix) Coolify deploy failed: {:branch_mismatch, "main", "release"}` | Check out the branch named in the manifest, or change `git_branch` to match the branch you actually deploy. |
| `project_path` points at a directory that does not exist. | `** (Mix) Coolify deploy failed: {:project_path_not_found, "web", "apps/missing"}` | Fix the path so it points at a real directory relative to the manifest's repo root. |
| Coolify reports a terminal failure status for the deployment. | `** (Mix) Deployment failed with status failed: DEPLOYMENT_UUID` | Inspect the deployment in Coolify and fetch logs with `mix coolify.logs DEPLOYMENT_UUID`. |
| A smoke check fails after the deployment itself succeeded. | `** (Mix) Verification failed with 1 failing checks` during `mix coolify.deploy` | Fix the live app or correct the smoke-check expectations in the manifest. |

## Next Steps

- Read [manifest.md](manifest.md) for the complete manifest key reference, discovery rules, and smoke-check URL behavior.
- Read [mix-tasks.md](mix-tasks.md) for the full flag list, success output, and failure behavior for each Mix task.
