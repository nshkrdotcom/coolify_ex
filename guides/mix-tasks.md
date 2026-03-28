# Mix Tasks

This guide documents the eight Mix tasks that ship with `CoolifyEx`, including
the flags that matter operationally, the success output shape, and the
important failure cases.

## `mix coolify.setup`

Prints a local or remote-server onboarding checklist and tries to load the
manifest.

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

Pushes Git if needed, starts a deployment, waits for completion, and optionally
verifies smoke checks.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to deploy. |
| `--app` | string | `nil` | Alias for `--project`. |
| `--config` | string | discovered | Explicit manifest path. |
| `--force` | boolean | `false` | Pass `force=true` to Coolify. |
| `--instant` | boolean | `false` | Pass `instant_deploy=true` to Coolify. |
| `--no-push` | boolean | `false` | Skip `git push`. |
| `--poll-interval` | integer | `3000` | Milliseconds between deployment polls. |
| `--skip-verify` | boolean | `false` | Skip smoke checks after deploy. |
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
Verification passed: 2/2 checks
```

## `mix coolify.deployments`

Lists recent deployments for a manifest project or a direct app UUID.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to inspect. |
| `--app-uuid` | string | `nil` | Direct Coolify app UUID. |
| `--app` | string | `nil` | Alias for `--app-uuid`. |
| `--config` | string | discovered | Explicit manifest path. |
| `--take` | integer | `1` | Number of deployments to fetch. |
| `--skip` | integer | `0` | Number of deployments to skip. |
| `--json` | boolean | `false` | Print machine-readable JSON. |

### Usage

```bash
mix coolify.deployments --project web
mix coolify.deployments --project web --take 5
mix coolify.deployments --app-uuid app-123 --json
```

### Human Output

```text
Project: web
dep-123 | finished | abc123 | 2026-03-28T07:42:19Z | 2026-03-28T07:44:02Z | Add deployment lookup
```

### JSON Output

```json
{
  "project": "web",
  "app_uuid": "app-123",
  "deployments": [
    {
      "uuid": "dep-123",
      "status": "finished",
      "commit": "abc123",
      "commit_message": "Add deployment lookup",
      "created_at": "2026-03-28T07:42:19Z",
      "finished_at": "2026-03-28T07:44:02Z",
      "deployment_url": null,
      "logs": []
    }
  ]
}
```

## `mix coolify.latest`

Fetches the newest deployment for a manifest project or a direct app UUID.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to inspect. |
| `--app-uuid` | string | `nil` | Direct Coolify app UUID. |
| `--app` | string | `nil` | Alias for `--app-uuid`. |
| `--config` | string | discovered | Explicit manifest path. |
| `--json` | boolean | `false` | Print machine-readable JSON. |

### Usage

```bash
mix coolify.latest --project web
mix coolify.latest --project web --json
```

### Human Output

```text
Project: web
App UUID: app-123
Latest deployment: dep-123
Status: finished
Commit: abc123
Created at: 2026-03-28T07:42:19Z
Finished at: 2026-03-28T07:44:02Z
Commit message: Add deployment lookup
```

## `mix coolify.status`

Fetches one deployment by UUID, or resolves the latest deployment for a project
first.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `nil` | Manifest project to inspect when combined with `--latest`. |
| `--app-uuid` | string | `nil` | Direct app UUID when combined with `--latest`. |
| `--app` | string | `nil` | Alias for `--app-uuid`. |
| `--config` | string | discovered | Explicit manifest path. |
| `--latest` | boolean | `false` | Resolve latest deployment first. |

### Usage

```bash
mix coolify.status DEPLOYMENT_UUID
mix coolify.status --project web --latest
```

### Human Output

```text
Project: web
Latest deployment: dep-123
Status: finished
Commit: abc123
Created at: 2026-03-28T07:42:19Z
Finished at: 2026-03-28T07:44:02Z
Commit message: Add deployment lookup
Logs: /project/demo/deployment/dep-123
```

## `mix coolify.logs`

Fetches one deployment log by UUID, or resolves the latest deployment for a
project first.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `nil` | Manifest project to inspect when combined with `--latest`. |
| `--app-uuid` | string | `nil` | Direct app UUID when combined with `--latest`. |
| `--app` | string | `nil` | Alias for `--app-uuid`. |
| `--config` | string | discovered | Explicit manifest path. |
| `--latest` | boolean | `false` | Resolve latest deployment first. |
| `--tail` | integer | `100` | Number of lines from the end of the deployment log. |

### Usage

```bash
mix coolify.logs DEPLOYMENT_UUID
mix coolify.logs --project web --latest --tail 200
```

### Human Output

```text
[2026-03-28T07:42:19Z] build start
[2026-03-28T07:44:02Z] build done
```

## `mix coolify.app_logs`

Fetches runtime logs for the running application by resolving a manifest
project to its `app_uuid`.

### Flags

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--project` | string | `default_project` | Manifest project to inspect. |
| `--app` | string | `nil` | Alias for `--project`. |
| `--config` | string | discovered | Explicit manifest path. |
| `--lines` | integer | `100` | Number of runtime log lines to request. |
| `--follow` | boolean | `false` | Poll continuously and print only new lines. |
| `--poll-interval` | integer | `2000` | Milliseconds between follow polls. |

### Usage

```bash
mix coolify.app_logs --project web --lines 200
mix coolify.app_logs --project web --lines 200 --follow
```

## `mix coolify.verify`

Runs smoke checks from the manifest without starting a new deployment.

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

## Common Failure Cases

- `No deployments found for project web`
  This means the app lookup succeeded but Coolify returned an empty deployment
  history.

- `Could not fetch deployments: 401 unauthorized`
  This means Coolify returned an HTTP error response, usually because the token
  is missing or invalid.

- `Project web does not define an app_uuid`
  This is the explicit task-level error when project resolution succeeds but no
  target app UUID is available.

- `Usage: mix coolify.status DEPLOYMENT_UUID ...`
  This means you did not provide either a deployment UUID or `--latest`.

## Structs

`CoolifyEx.Deployment` includes:

| Field | Type | Description |
| --- | --- | --- |
| `uuid` | string | Deployment UUID. |
| `status` | string or `nil` | Coolify deployment status. |
| `commit` | string or `nil` | Commit SHA or other revision identifier. |
| `commit_message` | string or `nil` | Commit message when Coolify returns it. |
| `created_at` | string or `nil` | Deployment creation timestamp. |
| `finished_at` | string or `nil` | Deployment completion timestamp. |
| `deployment_url` | string or `nil` | Coolify logs/details URL. |
| `logs` | list of `CoolifyEx.LogLine` | Normalized deployment log lines. |

`CoolifyEx.ApplicationLogs` includes:

| Field | Type | Description |
| --- | --- | --- |
| `app_name` | string or `nil` | Manifest project name when resolved. |
| `app_uuid` | string | Coolify application UUID. |
| `raw` | string or `nil` | Raw body returned by Coolify. |
| `logs` | list of `CoolifyEx.LogLine` | Runtime log lines. |

## Canonical Operator Flow

```bash
mix coolify.deploy --project web
mix coolify.latest --project web
mix coolify.logs --project web --latest --tail 200
mix coolify.app_logs --project web --lines 200 --follow
```

Use `mix coolify.logs` for deployment/build logs and `mix coolify.app_logs` for
runtime application logs. They are not the same surface.
