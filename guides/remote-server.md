# Remote Server Setup

Deploying from a remote server keeps Coolify credentials off GitHub, leaves an auditable shell history on a machine you control, and avoids depending on external CI runners for routine deploys.

## Recommended Directory Layout

Keep one working checkout per deployable repository on the server:

```text
/srv/coolify-ex/
└── my-app/
    ├── .coolify_ex.exs
    ├── mix.exs
    ├── mix.lock
    ├── lib/
    ├── guides/
    └── scripts/
```

This layout keeps the manifest, Git checkout, and Mix tasks together in one predictable location for the deploy user.

## Bootstrap

After cloning the repository, run:

```bash
./scripts/setup_remote.sh
```

You can target a different manifest path:

```bash
mkdir -p deploy
./scripts/setup_remote.sh deploy/.coolify_ex.exs
```

The bootstrap script checks for `git`, `curl`, and `mix`, copies `coolify.example.exs` to the manifest path if needed, runs `mix deps.get`, and then runs `mix coolify.setup`.

## Secrets Management

Prefer environment variables over literal secrets in the manifest:

```elixir
%{
  base_url: {:env, "COOLIFY_BASE_URL"},
  token: {:env, "COOLIFY_TOKEN"},
  projects: %{
    web: %{
      app_uuid: {:env, "COOLIFY_WEB_APP_UUID"},
      public_base_url: {:env, "COOLIFY_PUBLIC_BASE_URL"},
      project_path: ".",
      readiness: %{checks: [%{name: "HTTP ready", url: "/healthz", expected_status: 200}]}
    }
  }
}
```

One common pattern is a sourced env file owned by the deploy user:

```bash
export COOLIFY_BASE_URL="https://coolify.example.com" # replace this
export COOLIFY_TOKEN="coolify-api-token" # replace this
export COOLIFY_WEB_APP_UUID="00000000-0000-0000-0000-000000000000" # replace this
export COOLIFY_PUBLIC_BASE_URL="https://app.example.com" # replace this
```

Load it before deploying:

```bash
set -a
. /etc/coolify-ex/my-app.env # replace this
set +a
```

## Daily Operator Flow

For a routine deployment:

```bash
git pull --ff-only
mix coolify.deploy --config .coolify_ex.exs
mix coolify.logs --config .coolify_ex.exs --project web --latest --tail 200
mix coolify.app_logs --config .coolify_ex.exs --project web --lines 200
```

If you only want the deploy task's built-in verification, stop after `mix coolify.deploy`. That task already waits for readiness and runs verification unless you pass `--skip-verify`.

If you want to re-check the running app without triggering a new deployment, run:

```bash
mix coolify.verify --config .coolify_ex.exs --project web
```

## Cron Example

```cron
0 * * * * . /etc/coolify-ex/my-app.env && cd /srv/coolify-ex/my-app && git pull --ff-only && mix coolify.deploy --config .coolify_ex.exs >> /var/log/coolify-ex-web.log 2>&1
```

## systemd Example

```ini
[Unit]
Description=Deploy my Coolify app with CoolifyEx
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/srv/coolify-ex/my-app
EnvironmentFile=/etc/coolify-ex/my-app.env
ExecStart=/usr/bin/env bash -lc 'git pull --ff-only && mix coolify.deploy --config .coolify_ex.exs'

[Install]
WantedBy=multi-user.target
```

## Troubleshooting

| Problem | What to check |
| --- | --- |
| `mix coolify.setup` says the manifest is invalid. | Run `mix coolify.verify --config PATH --project NAME` or inspect the exact loader error from the task output. |
| Deployment succeeds in Coolify but the task fails during readiness. | Inspect the app's boot path, the chosen readiness endpoint, and the configured readiness timeout. |
| Runtime logs look fine but verification fails. | Compare the verification checks with the live routes the deployment should expose. |
