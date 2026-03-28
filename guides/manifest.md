# Manifest Format

This guide documents how `CoolifyEx` finds, evaluates, normalizes, and validates the deployment manifest.

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

This tells the loader to use one explicit file path instead of parent-directory discovery.

If the explicit path does not exist, `CoolifyEx.Config.load/2` returns `{:error, {:manifest_not_found, absolute_path}}`. If discovery fails with no explicit path, it returns `{:error, {:manifest_not_found, expanded_cwd, [".coolify_ex.exs", ".coolify.exs", "coolify.exs"]}}`.

## File Format

The manifest file is ordinary Elixir code evaluated with `Code.eval_file/1`. The evaluated result must be either:

- A map.
- A keyword list.

This means the file can resolve tuples, constants, helper functions, and comments exactly like any other Elixir source file. It also means the file can execute arbitrary code at load time, so only run manifests that you wrote or reviewed yourself.

An env-backed value uses the tuple form `{:env, "NAME"}`:

```elixir
%{
  base_url: {:env, "COOLIFY_BASE_URL"},
  token: {:env, "COOLIFY_TOKEN"}
}
```

This asks `CoolifyEx` to replace each tuple with the matching value from the current environment before it builds the normalized config struct.

`{:env, "NAME"}` works anywhere the loader calls `resolve_value/2`, including `base_url`, `token`, `app_uuid`, `public_base_url`, and smoke-check `url`.

## Manifest Keys

These are the top-level keys the loader understands in the manifest source.

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `version` | integer | none | no | Included in the shipped example and fixtures; the current loader does not read or validate it. |
| `base_url` | string or `{:env, String.t()}` | none | yes | Coolify panel URL such as `https://coolify.example.com`. |
| `token` | string or `{:env, String.t()}` | none | yes | Coolify API token. |
| `default_project` | atom or string | `nil` | no | Project name selected when you omit `--project`. |
| `projects` | map or keyword list | none | yes | Modern container for project entries. |

If `projects` is missing, the loader returns `{:error, :projects_not_configured}`.

## Normalized Config Struct

After loading succeeds, `CoolifyEx.Config` contains normalized fields that Mix tasks and library calls use internally.

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `base_url` | string | none | yes | Resolved Coolify base URL. |
| `token` | string | none | yes | Resolved Coolify API token. |
| `default_project` | string or `nil` | `nil` | no | Normalized default project name as a string. |
| `manifest_path` | path | none | yes | Absolute path of the file that was loaded. |
| `repo_root` | path | none | yes | Directory that contains `manifest_path`; Git pushes happen from here. |
| `projects` | map of project name to `CoolifyEx.Config.App` | `%{}` | yes | Normalized project entries keyed by string name. |

## Project Entry Keys

Each project entry is normalized into a `CoolifyEx.Config.App` struct.

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `app_uuid` | string or `{:env, String.t()}` | none | yes | Coolify application UUID for this project. |
| `git_branch` | string | `"main"` | no | Branch that must be checked out locally before the deploy task pushes. |
| `git_remote` | string | `"origin"` | no | Git remote used by the deploy task when push is enabled. |
| `project_path` | string | `"."` | no | Path expanded against `repo_root` and validated as an existing directory. |
| `public_base_url` | string or `{:env, String.t()}` | `nil` | no | Base URL used to expand smoke-check paths that start with `/`. |
| `smoke_checks` | list | `[]` | no | Smoke checks run by `CoolifyEx.Verifier.verify/3`. |

## Smoke Check Keys

Each smoke-check entry becomes a `CoolifyEx.SmokeCheck` struct.

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `name` | string | none | yes | Human-readable label shown in verification output. |
| `url` | string or `{:env, String.t()}` | none | yes | Absolute URL or a path beginning with `/`. |
| `method` | `:get`, `:head`, `"GET"`, `"HEAD"`, `"get"`, or `"head"` | `:get` | no | HTTP method used by the verifier. Any other value raises `ArgumentError`. |
| `expected_status` | positive integer | `200` | no | HTTP status the verifier expects. |
| `expected_body_contains` | string or `nil` | `nil` | no | Text that must appear in the response body after the status check passes. |

## Verifier Result Structs

The verification workflow also returns two structs that are useful when you call the library directly.

`CoolifyEx.Verifier.Result`:

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `app` | string | none | yes | Project name that was verified. |
| `total` | non-negative integer | `nil` | yes | Number of smoke checks that were evaluated. |
| `passed` | non-negative integer | `nil` | yes | Count of successful checks. |
| `failed` | non-negative integer | `nil` | yes | Count of failed checks. |
| `checks` | list of `CoolifyEx.Verifier.CheckResult` | `[]` | yes | Per-check outcomes in manifest order. |

`CoolifyEx.Verifier.CheckResult`:

| Field / Flag | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `name` | string | none | yes | Smoke-check name. |
| `url` | string | none | yes | Final URL that was requested. |
| `status` | non-negative integer or `nil` | `nil` | no | HTTP status returned by the request, when available. |
| `reason` | string or `nil` | `nil` | no | Failure reason such as `expected HTTP 200, got 500`. |
| `ok?` | boolean | `false` | yes | Whether the check passed. |

`CoolifyEx.Verifier.verify/3` evaluates each smoke check in manifest order, builds a `CheckResult` for each one, counts failures, and returns `{:ok, result}` when `failed == 0`; otherwise it returns `{:error, result}`.

## `project_path` Semantics

`project_path` matters at load time, not at push time.

- The loader expands `project_path` against `repo_root`.
- It validates that the expanded directory exists.
- If the directory does not exist, loading fails with `{:project_path_not_found, project_name, project_path}`.
- The deploy task still runs Git from `repo_root`, not from `project_path`.

This field still matters because it makes monorepo manifests explicit and catches stale paths before a deployment starts.

## URL Expansion Rules

URL normalization follows three rules:

1. If `url` starts with `/` and `public_base_url` is a string, `CoolifyEx` joins them by trimming the trailing slash from `public_base_url` and appending the path.
2. If `url` is already absolute, `CoolifyEx` leaves it unchanged.
3. If `url` starts with `/` and `public_base_url` is `nil`, `CoolifyEx` leaves the path unchanged.

Examples:

```elixir
[
  %{public_base_url: "https://app.example.com", url: "/"},
  %{public_base_url: "https://app.example.com/", url: "/healthz"},
  %{public_base_url: nil, url: "https://status.example.com/ready"},
  %{public_base_url: nil, url: "/healthz"}
]
```

These inputs normalize respectively to `https://app.example.com/`, `https://app.example.com/healthz`, `https://status.example.com/ready`, and `/healthz`.

That last case is important: the loader accepts it, but the verifier later raises `** (ArgumentError) scheme is required for url: /healthz` because `Req` cannot send a request to a bare path without a scheme or host.

## Full Annotated Example

```elixir
%{
  # Example metadata. The current loader ignores this field.
  version: 1,
  # Coolify panel URL, read from the machine that runs Mix.
  base_url: {:env, "COOLIFY_BASE_URL"},
  # Coolify API token, also read from the local environment.
  token: {:env, "COOLIFY_TOKEN"},
  # Default target when the task gets no --project flag.
  default_project: :web,
  projects: %{
    web: %{
      # UUID for the Coolify application behind the "web" project entry.
      app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
      # Local branch that must match before git push runs.
      git_branch: "main",
      # Git remote that receives the push.
      git_remote: "origin",
      # Existing directory checked relative to the manifest's repo root.
      project_path: ".",
      # Base URL used to expand relative smoke-check paths.
      public_base_url: "https://example.com", # replace this
      smoke_checks: [
        # GET https://example.com/ and require HTTP 200.
        %{name: "Landing page", url: "/", expected_status: 200},
        # GET https://example.com/healthz, require HTTP 200, and require "ok" in the body.
        %{name: "Health", url: "/healthz", expected_status: 200, expected_body_contains: "ok"}
      ]
    }
  }
}
```

This is the shipped example manifest with comments added to show how each field is consumed by the loader and verifier.

## What Can Go Wrong

| Problem | What you see | How to fix |
| --- | --- | --- |
| The loader cannot find a manifest file. | `{:manifest_not_found, path}` or `{:manifest_not_found, cwd, [".coolify_ex.exs", ".coolify.exs", "coolify.exs"]}`. | Create one of the supported files or pass `--config PATH`. |
| The manifest has a syntax error or raises while evaluating. | `{:manifest_eval_failed, path, error}` from `CoolifyEx.Config.load/2`, which Mix tasks then print with `inspect(reason)`. | Fix the syntax or the code that runs at evaluation time. |
| A required value resolves to `nil`. | `{:missing_required_value, :base_url}`, `{:missing_required_value, :token}`, or `{:missing_required_value, :app_uuid}`. | Export the missing env var or provide the value directly. |
| No `projects` container exists. | `{:projects_not_configured}`. | Add `projects: %{...}` to the manifest. |
| `project_path` points at a directory that does not exist. | `{:project_path_not_found, "web", "apps/missing"}`. | Fix the path relative to the manifest's repo root. |
| A smoke check uses an unsupported method. | `** (ArgumentError) unsupported smoke check method: :post`. | Use `:get`, `:head`, `"GET"`, `"HEAD"`, `"get"`, or `"head"`. |
| A smoke check uses a relative path without `public_base_url`. | `** (ArgumentError) scheme is required for url: /healthz` during verification. | Add `public_base_url` or change the smoke check to an absolute URL. |

## See Also

- [guides/getting-started.md](getting-started.md) when you want the first deploy workflow instead of the raw manifest reference.
- [guides/mix-tasks.md](mix-tasks.md) when you need the exact CLI flags that load this manifest and act on it.
- [guides/monorepos.md](monorepos.md) when one manifest needs multiple project entries with different UUIDs and smoke checks.
- [guides/remote-server.md](remote-server.md) when you want to keep the manifest and env vars on a dedicated deployment host.
