# Mix Tasks

This guide documents the Mix tasks that ship with `CoolifyEx 0.5.1`, including the flags that matter operationally, the success output shape, and the important failure cases.

## `mix coolify.setup`

Prints a local or remote-server onboarding checklist and tries to load the manifest.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--config` | string | discovered | Explicit manifest path. |

### Usage

```bash
mix coolify.setup
mix coolify.setup --config .coolify_ex.exs
```

### Success Output

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
```

## `mix coolify.deploy`

Pushes Git if needed, starts a deployment, waits for Coolify to mark it finished, waits for readiness, and then runs verification checks.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to deploy. |
| `--app` | string | `nil` | Alias for `--project`. |
| `--config` | string | discovered | Explicit manifest path. |
| `--force` | boolean | `false` | Pass `force=true` to Coolify. |
| `--instant` | boolean | `false` | Pass `instant_deploy=true` to Coolify. |
| `--no-push` | boolean | `false` | Skip `git push`. |
| `--poll-interval` | integer | `3000` | Milliseconds between deployment-status polls against Coolify. |
| `--skip-verify` | boolean | `false` | Skip readiness and verification after deploy. |
| `--timeout` | integer | `900000` | Maximum deploy wait time in milliseconds. |

### Usage

```bash
mix coolify.deploy
mix coolify.deploy --project web
mix coolify.deploy --project api --no-push --force --instant
```

### Success Output

```text
Deployment finished: dep-123
Readiness passed after 2 attempt(s)
Verification passed: 2/2 checks
```

### Failure Cases

- If Coolify reports a failed deployment status, the task raises before readiness begins.
- If readiness does not pass before the configured readiness timeout, the task raises `Verification failed during readiness ...`.
- If readiness passes but verification checks fail, the task raises `Verification failed with N failing checks`.
- Readiness attempt counts correspond to real HTTP polls. Transport-level retries are not hidden inside one reported attempt.

## `mix coolify.verify`

Runs the same readiness-plus-verification flow without starting a new deployment.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to verify. |
| `--app` | string | `nil` | Alias for `--project`. |
| `--config` | string | discovered | Explicit manifest path. |

### Usage

```bash
mix coolify.verify
mix coolify.verify --project web
```

### Success Output

```text
Readiness passed for web after 1 attempt(s)
Verification passed: 2/2 checks
```

## `mix coolify.deployments`

Lists recent deployments for a manifest project or a direct app UUID.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to inspect. |
| `--app-uuid` | string | `nil` | Explicit Coolify app UUID. |
| `--config` | string | discovered | Explicit manifest path. |
| `--take` | integer | `10` | Number of deployments to fetch. |
| `--skip` | integer | `0` | Number of deployments to skip. |
| `--json` | boolean | `false` | Print machine-readable JSON. |

### Usage

```bash
mix coolify.deployments --project web
mix coolify.deployments --project web --take 5
mix coolify.deployments --app-uuid app-123 --json
```

## `mix coolify.latest`

Fetches the newest deployment for a manifest project or direct app UUID.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to inspect. |
| `--app-uuid` | string | `nil` | Explicit Coolify app UUID. |
| `--config` | string | discovered | Explicit manifest path. |
| `--json` | boolean | `false` | Print machine-readable JSON. |

### Usage

```bash
mix coolify.latest --project web
mix coolify.latest --project web --json
mix coolify.latest --app-uuid app-123
```

## `mix coolify.status`

Fetches one deployment by UUID, or resolves `--project ... --latest` first and then fetches it.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to inspect. |
| `--app-uuid` | string | `nil` | Explicit Coolify app UUID for `--latest` lookup. |
| `--deployment` | string | `nil` | Explicit deployment UUID. |
| `--latest` | boolean | `false` | Resolve the newest deployment first. |
| `--config` | string | discovered | Explicit manifest path. |
| `--json` | boolean | `false` | Print machine-readable JSON. |

### Usage

```bash
mix coolify.status --deployment dep-123
mix coolify.status --project web --latest
```

## `mix coolify.logs`

Fetches one deployment's build/deployment logs by UUID, or resolves `--project ... --latest` first.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to inspect. |
| `--app-uuid` | string | `nil` | Explicit Coolify app UUID for `--latest` lookup. |
| `--deployment` | string | `nil` | Explicit deployment UUID. |
| `--latest` | boolean | `false` | Resolve the newest deployment first. |
| `--tail` | integer | `100` | Number of log lines to print. |
| `--config` | string | discovered | Explicit manifest path. |

### Usage

```bash
mix coolify.logs --deployment dep-123 --tail 200
mix coolify.logs --project web --latest --tail 50
```

## `mix coolify.app_logs`

Fetches runtime logs for the running application container and can follow for new lines.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to inspect. |
| `--app` | string | `nil` | Alias for `--project`. |
| `--config` | string | discovered | Explicit manifest path. |
| `--lines` | integer | `100` | Number of lines to fetch. |
| `--follow` | boolean | `false` | Continue polling for new lines. |
| `--poll-interval` | integer | `2000` | Milliseconds between follow polls. |
| `--max-polls` | integer | `nil` | Stop after this many polls when following. |

### Usage

```bash
mix coolify.app_logs --project web --lines 200
mix coolify.app_logs --project web --lines 200 --follow
```

## Operational Notes

- `mix coolify.deploy --no-push` is useful when another process already pushed the exact commit Coolify should build.
- The deploy task's `--timeout` governs deployment polling against Coolify, not the readiness timeout. Readiness timeout lives in the manifest.
- `mix coolify.verify` is useful after a rollout when you want to re-check the live app without triggering a second deployment.
- Runtime log inspection and deployment/build log inspection are intentionally separate commands because Coolify exposes them from different surfaces.
