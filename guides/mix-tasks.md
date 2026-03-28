# Mix Tasks

`CoolifyEx` ships Mix tasks for the common operator workflows.

## `mix coolify.setup`

Checks the local environment and validates the manifest.

```bash
mix coolify.setup
mix coolify.setup --config deploy/coolify.exs
```

## `mix coolify.deploy`

Pushes Git, triggers a Coolify deployment, polls for completion, and optionally
verifies the live result.

```bash
mix coolify.deploy
mix coolify.deploy --app web
mix coolify.deploy --app api --no-push --force
mix coolify.deploy --config deploy/coolify.exs --skip-verify
mix coolify.deploy --timeout 1200000 --poll-interval 5000
```

## `mix coolify.status`

Fetches one deployment by UUID.

```bash
mix coolify.status DEPLOYMENT_UUID
mix coolify.status DEPLOYMENT_UUID --config deploy/coolify.exs
```

## `mix coolify.logs`

Prints normalized log lines for one deployment.

```bash
mix coolify.logs DEPLOYMENT_UUID
mix coolify.logs DEPLOYMENT_UUID --tail 50
```

## `mix coolify.verify`

Runs the configured smoke checks without triggering a new deployment.

```bash
mix coolify.verify
mix coolify.verify --app web
mix coolify.verify --config deploy/coolify.exs
```
