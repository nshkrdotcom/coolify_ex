# Getting Started

`CoolifyEx` is a generic Elixir deployment helper for teams that want to keep
deployment control on a workstation or remote server while using Coolify as the
deployment target.

It is intentionally not tied to Phoenix, LiveView, umbrella apps, or a single
repository layout. If Coolify can already build and run your application,
`CoolifyEx` can trigger deployments and verify the live result.

## Prerequisites

Before using `CoolifyEx`, make sure:

- your application already exists in Coolify
- Coolify can already build or pull that application successfully
- the machine running `CoolifyEx` can reach both your Git remote and the
  Coolify panel URL
- Elixir, Mix, Git, and curl are installed on that machine

## Manual Coolify Setup

Do these steps once in the Coolify UI:

1. Enable API access.
   Go to `Settings -> Configuration -> Advanced` and enable API access.
2. Create a deployment token.
   Go to `Keys & Tokens -> API Tokens`, create a token, and include deploy
   permission.
3. Capture each application UUID.
   You need one Coolify application UUID per project entry in your manifest.
4. Confirm the public URL you want to verify after deployment.
   This becomes `public_base_url` in the manifest.

## Remote Server Setup

Clone the repository that contains `CoolifyEx` onto the server or workstation
you want to deploy from, then run:

```bash
./scripts/setup_remote.sh
```

That script:

- checks for the required tools
- installs Mix dependencies
- creates `.coolify_ex.exs` from `coolify.example.exs` if needed
- runs `mix coolify.setup`

## Local Environment Variables

Store your secrets in the local shell environment of the machine that runs
deployments:

```bash
export COOLIFY_BASE_URL="https://coolify.example.com"
export COOLIFY_TOKEN="your-api-token"
export COOLIFY_WEB_APP_UUID="your-app-uuid"
```

You can load them from your normal shell startup files or a secrets file that
you source before deploying.

## First Deployment

1. Copy and edit `.coolify_ex.exs`.
2. Confirm the project name and smoke checks.
3. Push your branch or let `mix coolify.deploy` push it for you.
4. Trigger and verify:

```bash
mix coolify.deploy
```

Useful variants:

```bash
mix coolify.deploy --project web
mix coolify.deploy --no-push
mix coolify.deploy --force --instant
mix coolify.verify --project web
```

## What CoolifyEx Does

- loads a local deployment manifest
- optionally pushes the configured Git branch
- triggers a Coolify deployment through the API
- polls until the deployment succeeds or fails
- runs smoke checks against the live URL

## What CoolifyEx Does Not Do

- create applications in Coolify
- replace your Dockerfile or build strategy
- install Elixir or Git for you
- manage your runtime secrets inside Coolify
