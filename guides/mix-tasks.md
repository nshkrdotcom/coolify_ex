# Mix Tasks

This guide documents the five Mix tasks that ship with `CoolifyEx`, including every accepted flag, the exact success output shape, and the task-specific failure behavior.

## `mix coolify.setup`

Prints a local or remote-server onboarding checklist and tries to load the manifest.

### Flags

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `--config` | string | `nil` | no | Explicit manifest path. When omitted, the loader uses parent-directory discovery. |

### Usage Examples

```bash
mix coolify.setup
mix coolify.setup --config .coolify_ex.exs
mix coolify.setup --config deploy/.coolify_ex.exs # replace this
```

These examples run the checklist with discovery, with the default file name, and with an explicit custom manifest path.

### What It Prints On Success

```text
CoolifyEx remote setup
=======================
tool git: ok
tool curl: ok
tool mix: ok
manifest: ok (/path/to/.coolify_ex.exs)
base url: https://coolify.example.com
projects: web
env COOLIFY_BASE_URL: set
env COOLIFY_TOKEN: set

Next steps:
1. Edit .coolify_ex.exs with your project UUIDs, branches, and smoke checks.
2. Export COOLIFY_BASE_URL and COOLIFY_TOKEN on this server.
3. Run mix coolify.deploy to push, deploy, and verify.
```

This is the actual output shape from a successful `mix coolify.setup` run.

### What It Raises

- No manifest-related exception is raised by the task itself. If manifest loading fails for any reason, the task prints either `manifest: missing or invalid (looked for ...)` or `manifest: missing or invalid (expected ABSOLUTE_PATH)` and continues printing the checklist.
- The task explicitly checks only whether `git`, `curl`, and `mix` exist on `PATH`, whether the manifest loads, and whether `COOLIFY_BASE_URL` and `COOLIFY_TOKEN` are set.

## `mix coolify.deploy`

Optionally pushes Git, starts a Coolify deployment, waits for completion, and then optionally runs smoke checks.

### Flags

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `--project` | string | `nil` | no | Project to deploy. Uses `default_project` when omitted. |
| `--config` | string | `nil` | no | Explicit manifest path. |
| `--force` | boolean | `false` | no | Passes `force: true` to the Coolify start-deployment request. |
| `--instant` | boolean | `false` | no | Passes `instant: true`, which becomes `instant_deploy=true` in the Coolify API request. |
| `--no-push` | boolean | `false` | no | Skips `git push`. |
| `--poll-interval` | integer | `3_000` | no | Milliseconds to sleep between status polls. |
| `--skip-verify` | boolean | `false` | no | Skips the smoke-check phase after a successful deployment. |
| `--timeout` | integer | `900_000` | no | Maximum time in milliseconds to wait for a terminal deployment state. |

### Usage Examples

```bash
mix coolify.deploy
mix coolify.deploy --project web
mix coolify.deploy --project api --no-push --force --instant
mix coolify.deploy --config deploy/.coolify_ex.exs --timeout 1200000 --poll-interval 5000 # replace this
```

These cover the default project, an explicit project, a deploy with push disabled plus Coolify force/instant flags, and a run with a custom config path and custom polling settings.

### What It Prints On Success

```text
Deployment finished: dep-123
Verification passed: 2/2 checks
```

The first line is always printed after a successful deployment; the second line appears only when verification is enabled and all smoke checks pass.

### What It Raises

- Config load failure: `** (Mix) Coolify deploy failed: {:missing_required_value, :token}` and similar `inspect(reason)` output for manifest errors such as `:projects_not_configured`, `{:manifest_not_found, ...}`, `{:project_path_not_found, ...}`, `{:unknown_project, ...}`, or `:default_project_not_configured`.
- Deployment failure: `** (Mix) Deployment failed with status failed: DEPLOYMENT_UUID` and the same pattern for terminal statuses such as `canceled`, `cancelled`, or `error`.
- Deployment timeout: `** (Mix) Deployment timed out while waiting for DEPLOYMENT_UUID`.
- Verification failure after a successful deployment: `** (Mix) Verification failed with N failing checks`.

## `mix coolify.status`

Fetches one deployment by UUID and prints the current status plus the Coolify logs URL when Coolify supplies one.

### Flags

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `--config` | string | `nil` | no | Explicit manifest path. |

### Usage Examples

```bash
mix coolify.status DEPLOYMENT_UUID # replace this
mix coolify.status DEPLOYMENT_UUID --config .coolify_ex.exs # replace this
mix coolify.status DEPLOYMENT_UUID --config deploy/.coolify_ex.exs # replace this
```

These fetch status with discovery, with the default manifest path, and with an explicit custom manifest path.

### What It Prints On Success

```text
Status: finished
Logs: /project/demo/deployment/dep-123
```

The `Logs:` line is printed only when the deployment has a non-`nil` `deployment_url`.

### What It Raises

- Missing positional argument: `** (Mix) Usage: mix coolify.status DEPLOYMENT_UUID [--config path]`.
- Config load failure: `** (Mix) Could not fetch deployment status: {:manifest_not_found, ...}` or another `inspect(reason)` value from `CoolifyEx.Config.load/2`.
- Coolify fetch failure: `** (Mix) Could not fetch deployment status: REASON`.

## `mix coolify.logs`

Fetches one deployment by UUID and prints each normalized log line.

### Flags

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `--config` | string | `nil` | no | Explicit manifest path. |
| `--tail` | integer | `100` | no | Number of lines from the end of the log list to print. |

### Usage Examples

```bash
mix coolify.logs DEPLOYMENT_UUID # replace this
mix coolify.logs DEPLOYMENT_UUID --tail 50 # replace this
mix coolify.logs DEPLOYMENT_UUID --tail 0 --config .coolify_ex.exs # replace this
```

These fetch the default tail length, a shorter tail, and all lines from a specific manifest path.

### What It Prints On Success

```text
[2026-03-27T00:00:00Z] done
build complete
```

Each line is printed as `[timestamp] output` when a timestamp exists, or as just `output` when it does not.

### What It Raises

- Missing positional argument: `** (Mix) Usage: mix coolify.logs DEPLOYMENT_UUID [--config path] [--tail 100]`.
- Config load failure: `** (Mix) Could not fetch deployment logs: {:manifest_not_found, ...}` or another `inspect(reason)` value from `CoolifyEx.Config.load/2`.
- Coolify fetch failure: `** (Mix) Could not fetch deployment logs: REASON`.

## `mix coolify.verify`

Runs the configured smoke checks without triggering a new deployment.

### Flags

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `--project` | string | `nil` | no | Project to verify. Uses `default_project` when omitted. |
| `--config` | string | `nil` | no | Explicit manifest path. |

### Usage Examples

```bash
mix coolify.verify
mix coolify.verify --project web
mix coolify.verify --project web --config .coolify_ex.exs
```

These verify the default project, an explicit project, and an explicit project with an explicit manifest path.

### What It Prints On Success

```text
All 2 checks passed for web
```

This is the exact success line from the task when every smoke check passes.

### What It Raises

- Config load failure: `** (Mix) Could not load config: {:missing_required_value, :token}` and similar `inspect(reason)` output for other manifest load failures.
- Smoke-check failure: the task first prints one line per failing check such as `Health: expected HTTP 200, got 500`, then raises `** (Mix) Verification failed for web`.
- Relative smoke-check path with no `public_base_url`: `** (ArgumentError) scheme is required for url: /healthz`.
- Unknown project name currently crashes the task with `** (KeyError) key :checks not found in: {:unknown_project, "missing"}` even though the library itself returns `{:error, {:unknown_project, "missing"}}`.
- Missing `default_project` currently crashes the task with `** (UndefinedFunctionError) function :default_project_not_configured.checks/0 is undefined` when you omit `--project`, even though the library itself returns `{:error, :default_project_not_configured}`.

## Deployment And Log Structs

`mix coolify.deploy`, `mix coolify.status`, and `mix coolify.logs` all work with the normalized deployment and log structs returned by `CoolifyEx.Client`.

`CoolifyEx.Deployment`:

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `uuid` | string | none | yes | Deployment UUID returned by Coolify. |
| `status` | string or `nil` | `nil` | no | Deployment status fetched from Coolify. |
| `deployment_url` | string or `nil` | `nil` | no | Coolify URL for the deployment details page; the status task prints it as `Logs:` when present. |
| `commit` | string or `nil` | `nil` | no | Commit identifier returned by Coolify, when present. |
| `logs` | list of `CoolifyEx.LogLine` | `[]` | no | Normalized deployment log lines. |

`CoolifyEx.LogLine`:

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `timestamp` | string or `nil` | `nil` | no | Timestamp from Coolify, if provided. |
| `output` | string | none | yes | Log line body that `mix coolify.logs` prints. |

## Composing Tasks

Standard deploy-and-verify flow:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /srv/coolify/my-app # replace this
git pull --ff-only
mix deps.get
# replace this project name if your manifest uses a different key
mix coolify.deploy --config .coolify_ex.exs --project web
```

This script updates the checkout, installs dependencies, and then lets `mix coolify.deploy` handle the deployment and built-in smoke checks.

Deploy-only flow with manual log inspection afterward:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /srv/coolify/my-app # replace this
git pull --ff-only

# replace this project name if your manifest uses a different key
output=$(mix coolify.deploy --config .coolify_ex.exs --project web --skip-verify --no-push)
printf '%s\n' "$output"

deployment_uuid=$(printf '%s\n' "$output" | sed -n 's/^Deployment finished: //p' | tail -n 1)

mix coolify.status "$deployment_uuid" --config .coolify_ex.exs
mix coolify.logs "$deployment_uuid" --config .coolify_ex.exs --tail 200
```

This script captures the deployment UUID from the task output and then uses the status and logs tasks for manual inspection.

## See Also

- [guides/getting-started.md](getting-started.md) when you want the first end-to-end deploy flow rather than the raw CLI reference.
- [guides/manifest.md](manifest.md) when you need to understand how `--config` interacts with discovery, env tuples, and project selection.
- [guides/monorepos.md](monorepos.md) when you want to combine these tasks with multiple project entries in one repository.
- [guides/remote-server.md](remote-server.md) when you want to wrap these tasks in remote-host workflows, cron, or systemd.
