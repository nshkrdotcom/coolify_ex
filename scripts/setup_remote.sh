#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${1:-.coolify_ex.exs}"
EXAMPLE_PATH="${ROOT_DIR}/coolify.example.exs"

cd "${ROOT_DIR}"

for tool in git curl mix; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "missing required tool: ${tool}" >&2
    exit 1
  fi
done

if [ ! -f "${CONFIG_PATH}" ]; then
  cp "${EXAMPLE_PATH}" "${CONFIG_PATH}"
  echo "created ${CONFIG_PATH} from coolify.example.exs"
fi

mix deps.get
mix coolify.setup --config "${CONFIG_PATH}"

cat <<EOF

Remote setup complete.

Next steps:
1. Edit ${CONFIG_PATH}.
2. Export COOLIFY_BASE_URL, COOLIFY_TOKEN, and any project UUID env vars.
3. Run mix coolify.deploy --config ${CONFIG_PATH}
EOF
