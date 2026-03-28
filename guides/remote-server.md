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

If you manage multiple repositories, give each one its own checkout and its own env file instead of sharing a single working tree.

## Bootstrap

After cloning the repository, run:

```bash
./scripts/setup_remote.sh
```

This checks for `git`, `curl`, and `mix`, copies `coolify.example.exs` to `.coolify_ex.exs` if needed, runs `mix deps.get`, and then runs `mix coolify.setup --config .coolify_ex.exs`.

You can target a different manifest path:

```bash
mkdir -p deploy
./scripts/setup_remote.sh deploy/.coolify_ex.exs
```

This creates the parent directory first and then asks the bootstrap script to use a custom manifest path relative to the repository root.

## Secrets Management

Prefer environment variables over literal secrets in the manifest:

```elixir
%{
  base_url: {:env, "COOLIFY_BASE_URL"},
  token: {:env, "COOLIFY_TOKEN"},
  projects: %{
    web: %{app_uuid: {:env, "COOLIFY_WEB_APP_UUID"}, project_path: "."}
  }
}
```

This keeps the manifest safe to commit because the actual secrets live outside the repository.

One common pattern is a sourced env file owned by the deploy user:

```bash
export COOLIFY_BASE_URL="https://coolify.example.com" # replace this
export COOLIFY_TOKEN="coolify-api-token" # replace this
export COOLIFY_WEB_APP_UUID="00000000-0000-0000-0000-000000000000" # replace this
```

This file can live at a path such as `/etc/coolify-ex/my-app.env` or `$HOME/.config/coolify-ex/my-app.env`.

Load it before deploying:

```bash
set -a
. /etc/coolify-ex/my-app.env # replace this
set +a
```

This exports every variable from the env file into the current shell before Mix loads the manifest.

Do not commit `.coolify_ex.exs` if it contains literal token values. Prefer `{:env, "NAME"}` tuples so the manifest can stay in version control without embedding secrets.

## Typical Deploy Flow

From the server checkout, the normal sequence is:

```bash
git pull --ff-only
mix coolify.deploy
mix coolify.verify
```

This updates the checkout, performs the deployment, and then reruns smoke checks on demand if you want a separate verification pass.

If you only want the deploy task's built-in verification, stop after `mix coolify.deploy`. That task already runs smoke checks unless you pass `--skip-verify`.

## Using `--no-push`

Use `--no-push` when you already pushed the branch from another machine and only want this server to trigger Coolify:

```bash
# replace this project name if your manifest default is not the target you want
mix coolify.deploy --project web --no-push
```

This skips the local `git push` step but still starts the Coolify deployment and verifies the selected project unless you also pass `--skip-verify`.

`--no-push` does not bypass manifest loading, project selection, or verification. It only disables the Git push step.

## Automating With Cron Or systemd

Minimal cron entry:

```bash
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
# replace this env path, checkout path, and log path
0 * * * * . /etc/coolify-ex/my-app.env && cd /srv/coolify-ex/my-app && git pull --ff-only && mix coolify.deploy --config .coolify_ex.exs >> /var/log/coolify-ex-web.log 2>&1
```

This cron job sources the env file in a non-interactive shell, updates the checkout, and records deploy output in a log file.

Minimal oneshot unit:

```ini
[Unit]
Description=CoolifyEx deploy for my-app
After=network-online.target

[Service]
Type=oneshot
User=deploy # replace this
WorkingDirectory=/srv/coolify-ex/my-app # replace this
EnvironmentFile=/etc/coolify-ex/my-app.env # replace this
# replace this command if you need a non-default project name
ExecStart=/usr/bin/env bash -lc 'git pull --ff-only && mix coolify.deploy --config .coolify_ex.exs'
```

This unit runs the same update-and-deploy flow under a dedicated user with an explicit environment file.

## What Can Go Wrong

| Problem | What you see | How to fix |
| --- | --- | --- |
| The deploy user cannot authenticate to the Git remote. | `** (Mix) Coolify deploy failed: {:git_command_failed, code, output}` and the `output` text usually contains the SSH or remote error. | Make sure the deploy user has the right SSH key, agent setup, or HTTPS credentials for the repository remote. |
| Env vars are present in your interactive shell but not in cron or systemd. | Manifest loading fails with messages such as `** (Mix) Coolify deploy failed: {:missing_required_value, :token}`. | Source an env file in cron and use `EnvironmentFile=` or equivalent for systemd. Do not rely on an interactive shell profile for non-interactive jobs. |
| The Git remote is reachable, but the current branch does not match the manifest. | `** (Mix) Coolify deploy failed: {:branch_mismatch, "main", "release"}`. | Check out the branch named by `git_branch`, change the manifest, or use `--no-push` if the branch is already pushed. |
| The bootstrap script uses a custom path whose parent directory does not exist. | `cp` fails before `mix coolify.setup` runs. | Create the directory first with `mkdir -p` before calling `./scripts/setup_remote.sh CUSTOM_PATH`. |
| `mix coolify.setup` says the manifest is invalid but does not explain why. | `manifest: missing or invalid (...)` with no tuple details. | Run `mix coolify.deploy --config PATH --no-push --skip-verify` or `mix coolify.verify --config PATH --project NAME` to surface the exact loader error. |

## See Also

- [guides/getting-started.md](getting-started.md) when you want the first deploy walkthrough before automating it on a server.
- [guides/manifest.md](manifest.md) when you need the exact env tuple behavior and manifest discovery rules that matter on a remote host.
- [guides/mix-tasks.md](mix-tasks.md) when you need the exact flags for `--no-push`, `--config`, and verification behavior.
- [guides/monorepos.md](monorepos.md) when the remote server needs to deploy multiple applications from one repository.
