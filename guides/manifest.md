# Manifest Format

`CoolifyEx` reads a local `coolify.exs` file. The file is normal Elixir and
should evaluate to a map or keyword list.

## Example

```elixir
%{
  version: 1,
  base_url: {:env, "COOLIFY_BASE_URL"},
  token: {:env, "COOLIFY_TOKEN"},
  default_app: :web,
  apps: %{
    web: %{
      app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
      git_branch: "main",
      git_remote: "origin",
      project_path: ".",
      public_base_url: "https://example.com",
      smoke_checks: [
        %{name: "Landing page", url: "/", expected_status: 200},
        %{name: "Health", url: "/healthz", expected_status: 200, expected_body_contains: "ok"}
      ]
    }
  }
}
```

## Top-Level Keys

| Key | Required | Description |
| --- | --- | --- |
| `:base_url` | yes | Coolify base URL such as `https://coolify.example.com` |
| `:token` | yes | Coolify API token |
| `:default_app` | no | App name used when a Mix task does not receive `--app` |
| `:apps` | yes | Map of app names to app configuration |

`{:env, "NAME"}` tuples are resolved against the local shell environment.

## App Keys

| Key | Required | Description |
| --- | --- | --- |
| `:app_uuid` | yes | Coolify application UUID |
| `:git_branch` | no | Branch that must be checked out before deploy; defaults to `main` |
| `:git_remote` | no | Git remote used for push; defaults to `origin` |
| `:project_path` | no | Relative path inside the repo for the app entry; defaults to `.` |
| `:public_base_url` | no | Base URL used to expand relative smoke-check URLs |
| `:smoke_checks` | no | List of verification checks to run after deployment |

## Smoke Checks

Each smoke check supports:

| Key | Required | Description |
| --- | --- | --- |
| `:name` | yes | Human-friendly name shown in output |
| `:url` | yes | Absolute URL or a path relative to `public_base_url` |
| `:method` | no | `:get` or `:head`; defaults to `:get` |
| `:expected_status` | no | Expected HTTP status; defaults to `200` |
| `:expected_body_contains` | no | Text that must appear in the response body |

## Notes on `project_path`

`CoolifyEx` pushes Git from the repository root because that is how a normal
Git checkout works for top-level repos and monorepos alike.

`project_path` is still important:

- it documents which subtree the app entry represents
- it is validated when the manifest loads
- it keeps multi-app manifests readable and explicit
