# Monorepos and Phoenix Apps

`CoolifyEx` is generic by design. It does not assume Phoenix, but Phoenix and
other Mix applications are a common fit.

## Top-Level Mix App

For a normal repository with a single application at the root:

```elixir
%{
  default_project: :web,
  projects: %{
    web: %{
      app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
      project_path: ".",
      public_base_url: "https://example.com",
      smoke_checks: [%{name: "Health", url: "/healthz", expected_status: 200}]
    }
  }
}
```

## Monorepo

For a repository with multiple deployable applications:

```elixir
%{
  default_project: :web,
  projects: %{
    web: %{
      app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
      project_path: "apps/web",
      public_base_url: "https://web.example.com",
      smoke_checks: [%{name: "Web health", url: "/healthz", expected_status: 200}]
    },
    api: %{
      app_uuid: {:env, "COOLIFY_API_APP_UUID"},
      project_path: "apps/api",
      public_base_url: "https://api.example.com",
      smoke_checks: [%{name: "API health", url: "/healthz", expected_status: 200}]
    }
  }
}
```

## How This Works

- one manifest can define many Coolify projects
- each entry has its own UUID, public URL, and smoke checks
- Git still pushes once from the repository root
- verification runs against the project you selected with `--project`

## Phoenix-Specific Advice

`CoolifyEx` does not care whether the target app is Phoenix, a worker, or a
plain HTTP service. For Phoenix apps, keep the smoke checks honest:

- use a real health endpoint if you have one
- if `/` intentionally returns `404`, do not pretend it is a health check
- verify a route that matches the behavior you expect in production

## Non-Phoenix Elixir Apps

The same flow works for:

- Plug services
- GenServer or worker images that expose an HTTP admin endpoint
- mixed repos where only some children are web-facing

As long as you can identify the live URL you want to verify, `CoolifyEx` stays
useful.
