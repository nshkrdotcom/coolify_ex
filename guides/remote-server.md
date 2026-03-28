# Remote Server Setup

Many teams prefer to deploy from a trusted remote server or operator box rather
than from GitHub Actions. `CoolifyEx` supports that model directly.

## Recommended Layout

On the server:

1. Clone the repository that contains `CoolifyEx`.
2. Keep a local `.coolify_ex.exs` file that is not committed if it contains
   host-specific overrides.
3. Store `COOLIFY_*` values in local shell startup or secrets files.
4. Trigger deployments with Mix tasks from that machine.

## Bootstrap

Run:

```bash
./scripts/setup_remote.sh
```

If you want a different manifest path:

```bash
./scripts/setup_remote.sh deploy/.coolify_ex.exs
```

## Environment Variables

Typical shell setup:

```bash
export COOLIFY_BASE_URL="https://coolify.example.com"
export COOLIFY_TOKEN="your-api-token"
export COOLIFY_WEB_APP_UUID="your-app-uuid"
```

You can place these in:

- `~/.bashrc`
- `~/.zshrc`
- a sourced secrets file such as `~/.config/coolify_ex/secrets`

## Typical Deploy Flow

From the server:

```bash
git pull --ff-only
mix coolify.deploy
```

If the branch is already pushed and you only want to trigger Coolify:

```bash
mix coolify.deploy --no-push
```

## Why This Approach Works Well

- deploy credentials stay on a machine you control
- the flow is easy to audit because it is just Git plus the Coolify API
- the same server can deploy top-level apps, Phoenix apps, and monorepos
- you can wrap the Mix tasks with shell scripts, cron jobs, or systemd units
