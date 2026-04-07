# Manifest Format

This guide documents how `CoolifyEx` finds, evaluates, normalizes, and validates the deployment manifest in `0.5.1`.

The important `0.5.x` change is that a project no longer exposes one undifferentiated `smoke_checks` list. Each project now defines:

- a required `readiness` section
- an optional `verification` section

`CoolifyEx` always waits for readiness before it runs verification.

## File Discovery

When you do not pass `--config`, `CoolifyEx.Config.load/2` searches for these file names in this exact order:

1. `.coolify_ex.exs`
2. `.coolify.exs`
3. `coolify.exs`

It checks the current directory first, then walks upward one parent at a time until it reaches the filesystem root.

Every Mix task can override discovery with `--config PATH`:

```bash
mix coolify.deploy --config deploy/.coolify_ex.exs # replace this
```

If the explicit path does not exist, `CoolifyEx.Config.load/2` returns `{:error, {:manifest_not_found, absolute_path}}`.

## File Format

The manifest file is ordinary Elixir code evaluated with `Code.eval_file/1`. The evaluated result must be either:

- a map
- a keyword list

This means the file can resolve tuples, constants, helper functions, and comments exactly like any other Elixir source file. It also means the file can execute arbitrary code at load time, so only run manifests that you wrote or reviewed yourself.

An env-backed value uses the tuple form `{:env, "NAME"}`:

```elixir
%{
  base_url: {:env, "COOLIFY_BASE_URL"},
  token: {:env, "COOLIFY_TOKEN"}
}
```

`{:env, "NAME"}` works anywhere the loader calls `resolve_value/2`, including `base_url`, `token`, `app_uuid`, `public_base_url`, and each check `url`.

## Top-Level Manifest Keys

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `version` | integer | no | Informational in the shipped example. The loader currently ignores it. |
| `base_url` | string or `{:env, String.t()}` | yes | Coolify panel URL such as `https://coolify.example.com`. |
| `token` | string or `{:env, String.t()}` | yes | Coolify API token. |
| `default_project` | atom or string | no | Project name selected when you omit `--project`. |
| `projects` | map or keyword list | yes | Map of project name to project config. |

If `projects` is missing, the loader returns `{:error, :projects_not_configured}`.

## Normalized Config Struct

After loading succeeds, `CoolifyEx.Config` contains normalized fields that Mix tasks and library calls use internally.

| Field | Type | Description |
| --- | --- | --- |
| `base_url` | string | Resolved Coolify base URL. |
| `token` | string | Resolved Coolify API token. |
| `default_project` | string or `nil` | Normalized default project name. |
| `manifest_path` | path | Absolute path of the file that was loaded. |
| `repo_root` | path | Directory that contains `manifest_path`; Git pushes happen from here. |
| `projects` | map of string project name to `CoolifyEx.Config.App` | Normalized project entries keyed by string name. |

## Project Entry Keys

Each project entry is normalized into a `CoolifyEx.Config.App` struct.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `app_uuid` | string or `{:env, String.t()}` | yes | none | Coolify application UUID for this project. |
| `git_branch` | string | no | `"main"` | Branch that must be checked out locally before deploy unless `--no-push` is used. |
| `git_remote` | string | no | `"origin"` | Git remote used for the optional push step. |
| `project_path` | string | no | `"."` | Relative path to the project directory under the manifest root. |
| `public_base_url` | string or `{:env, String.t()}` | no | `nil` | Base URL used to expand relative readiness and verification paths. |
| `readiness` | map | yes | none | Required readiness policy for the project. |
| `verification` | map | no | `%{}` | Optional post-ready verification policy for the project. |

## Readiness Section

`readiness` is required for every project.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `initial_delay_ms` | non-negative integer | no | `0` | Delay before the first readiness poll. |
| `poll_interval_ms` | positive integer | no | `2000` | Delay between readiness attempts. |
| `timeout_ms` | positive integer | no | `120000` | Maximum time to keep polling readiness. |
| `checks` | list of check maps | yes | none | One or more HTTP checks that all must pass for readiness to succeed. |

If `readiness` is missing, or `readiness.checks` is empty, manifest loading fails.

## Verification Section

`verification` is optional.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `checks` | list of check maps | no | `[]` | HTTP checks that run once after readiness succeeds. |

## HTTP Check Keys

Both readiness and verification use the same HTTP check shape. Each one becomes a `CoolifyEx.HTTPCheck` struct.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | string | yes | none | Human-readable label printed in failures. |
| `url` | string or `{:env, String.t()}` | yes | none | Absolute URL or relative path. |
| `method` | `:get`, `:head`, `"GET"`, `"HEAD"`, `"get"`, or `"head"` | no | `:get` | HTTP method. |
| `expected_status` | positive integer | no | `200` | Expected HTTP status. |
| `expected_body_contains` | string or `nil` | no | `nil` | Optional body substring that must be present. |

## URL Expansion Rules

When a check `url` starts with `/` and `public_base_url` is a string, `CoolifyEx` trims the trailing slash from `public_base_url` and appends the path.

Examples:

```elixir
[
  %{public_base_url: "https://app.example.com", url: "/healthz"},
  %{public_base_url: "https://app.example.com/", url: "/api/targets"},
  %{public_base_url: nil, url: "https://status.example.com/ready"},
  %{public_base_url: nil, url: "/healthz"}
]
```

These normalize respectively to:

- `https://app.example.com/healthz`
- `https://app.example.com/api/targets`
- `https://status.example.com/ready`
- `/healthz`

That last case is legal at load time but will fail at request time because `Req` cannot send a request to a bare path without a scheme or host.

## Full Example

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

## Verifier Semantics

`CoolifyEx.Verifier.verify/3` now works in two phases:

1. Poll every readiness check until all of them pass or `timeout_ms` is reached.
2. Run the verification checks once.

In `0.5.1`, each readiness attempt corresponds to one real HTTP poll. Req transport retries are disabled inside the verifier so attempt counts stay accurate.

The returned `CoolifyEx.Verifier.Result` includes:

- `app`
- `readiness`, a `CoolifyEx.Verifier.PhaseResult`
- `verification`, a `CoolifyEx.Verifier.PhaseResult`

Each phase result includes:

- `name`
- `attempts`
- `duration_ms`
- `total`
- `passed`
- `failed`
- `checks`

Each check result includes:

- `phase`
- `name`
- `url`
- `status`
- `reason`
- `ok?`

## Common Loader And Verification Errors

| Problem | What happens | Fix |
| --- | --- | --- |
| Missing `readiness` section | `{:error, {:missing_required_value, {:projects, "web", :readiness}}}` | Add a readiness block to the project. |
| Empty `readiness.checks` | same shape as above | Add at least one readiness check. |
| Unsupported method | `** (ArgumentError) unsupported HTTP check method: ...` | Use `:get`, `:head`, `"GET"`, `"HEAD"`, `"get"`, or `"head"`. |
| Relative URL without usable `public_base_url` | request-time URL error during verification | Add `public_base_url` or use an absolute URL. |
| Readiness never passes | verifier returns an error result with readiness failures | Fix the app startup flow or increase `timeout_ms`. |
| Verification fails after readiness | verifier returns an error result with verification failures | Fix the app behavior or the expected status/body. |

## Related Guides

- [guides/getting-started.md](getting-started.md) for the first end-to-end deployment.
- [guides/mix-tasks.md](mix-tasks.md) for task flags and output examples.
- [guides/monorepos.md](monorepos.md) when one manifest needs multiple project entries with different UUIDs and URLs.
