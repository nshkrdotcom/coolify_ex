# CoolifyEx

<p align="center">
  <img src="assets/coolify_ex.svg" alt="CoolifyEx logo" width="200" />
</p>

<p align="center">
  <a href="https://github.com/nshkrdotcom/coolify_ex"><img src="https://img.shields.io/badge/release-0.1.0-0f766e.svg" alt="Release 0.1.0" /></a>
  <a href="https://hexdocs.pm/coolify_ex/"><img src="https://img.shields.io/badge/docs-hexdocs-2563eb.svg" alt="HexDocs" /></a>
  <a href="https://github.com/nshkrdotcom/coolify_ex"><img src="https://img.shields.io/badge/license-MIT-111827.svg" alt="MIT License" /></a>
  <a href="https://github.com/nshkrdotcom/coolify_ex"><img src="https://img.shields.io/badge/github-nshkrdotcom%2Fcoolify__ex-24292f?style=flat&logo=github" alt="GitHub" /></a>
</p>

Generic Elixir tooling for triggering, monitoring, and verifying Coolify
deployments from a local workstation or a remote server.

`CoolifyEx` is deliberately generic:

- it is not tied to Phoenix or a specific framework
- it supports top-level Mix apps and monorepos
- it keeps deployment orchestration in Elixir instead of hiding it in ad hoc
  shell scripts
- it works well for operator-driven deployments from a trusted host

## Features

- Manifest-driven deployment config in a repo-root `.coolify_ex.exs` file
- Coolify API client built on `Req`
- Optional Git push before deployment
- Deployment polling with normalized status and logs
- Smoke-check verification against live URLs
- Mix tasks for setup, deploy, status, logs, and verify
- Support for both single-app repos and multi-app monorepos

## Installation

Add `coolify_ex` to your dependencies:

```elixir
def deps do
  [
    {:coolify_ex, "~> 0.1.0", runtime: false}
  ]
end
```

Use `runtime: false` when `CoolifyEx` powers deployment tooling rather than
your runtime supervision tree.

## Quick Start

1. In Coolify, enable API access.
2. Create an API token with deploy permission.
3. Capture the Coolify application UUID for each app you want to drive.
4. Clone the repo that contains `CoolifyEx` onto the machine that will trigger
   deployments.
5. Run the remote bootstrap script:

```bash
./scripts/setup_remote.sh
```

6. Export your local deployment environment variables:

```bash
export COOLIFY_BASE_URL="https://coolify.example.com"
export COOLIFY_TOKEN="your-api-token"
export COOLIFY_WEB_APP_UUID="your-app-uuid"
```

7. Copy `coolify.example.exs` to `.coolify_ex.exs`, edit it, then deploy:

```bash
mix coolify.deploy
```

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
      public_base_url: "https://example.com",
      smoke_checks: [
        %{name: "Landing page", url: "/", expected_status: 200},
        %{name: "Health", url: "/healthz", expected_status: 200, expected_body_contains: "ok"}
      ]
    }
  }
}
```

Relative smoke-check URLs are expanded against `public_base_url`.

## Remote-Server Flow

`CoolifyEx` is especially useful when you do not want a GitHub Actions-based
deployment pipeline and instead prefer to deploy from a server you control.

Typical flow:

1. Keep the deployment credentials on the remote server.
2. Run `./scripts/setup_remote.sh` once after cloning.
3. Edit the local `.coolify_ex.exs`.
4. Trigger deploys with:

```bash
mix coolify.deploy
```

Useful variants:

```bash
mix coolify.deploy --project web
mix coolify.deploy --no-push
mix coolify.deploy --force --instant
mix coolify.verify --project web
mix coolify.logs DEPLOYMENT_UUID --tail 50
```

## Monorepos

`CoolifyEx` supports monorepos by letting one manifest describe many Coolify
applications.

Each project entry can point at its own:

- Coolify application UUID
- `project_path`
- public verification URL
- smoke-check set

Git still pushes from the repository root, which matches how normal monorepo
checkouts behave.

## Documentation

- [Getting Started](guides/getting-started.md)
- [Manifest Format](guides/manifest.md)
- [Monorepos and Phoenix Apps](guides/monorepos.md)
- [Remote Server Setup](guides/remote-server.md)
- [Mix Tasks](guides/mix-tasks.md)

## License

`CoolifyEx` is released under the MIT License. See [LICENSE](LICENSE).
