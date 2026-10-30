#!/usr/bin/env bash
# ds.sh — run one DeepSeek Harness (DSH) headless job and print the final answer to stdout.
# Usage: ds.sh [-C <workdir>] [-m <provider>/<model>] "task prompt"    (use "-" to read the prompt from stdin)
# Without -m, the model comes from config/headless.patch.yml (if present) or DSH's own headless default.
# API keys (*_API_KEY refs) are read at runtime from ~/.dsh/.credentials.yaml and passed only via the child env.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
USAGE='ds.sh [-C dir] [-m provider/model] "prompt" | -'
[[ -f "$ROOT/local.env" ]] && source "$ROOT/local.env"
source "$HERE/_args.sh"
if [[ -n "$MODEL_ARG" ]]; then
  [[ "$MODEL_ARG" == */* ]] || die "-m needs provider/model, e.g. deepseek-official/deepseek-v4-pro"
  export DS_PROVIDER="${MODEL_ARG%%/*}" DS_MODEL="${MODEL_ARG#*/}"
fi
APP="${DSH_APP:-$(cygpath -u "${LOCALAPPDATA:-$HOME/AppData/Local}")/Programs/DeepSeek Harness}"
[[ -f "$APP/DeepSeek Harness.exe" ]] || { echo "ds.sh: DeepSeek Harness not found at $APP (set DSH_APP in local.env)" >&2; exit 1; }
# Call the Electron exe directly (same as resources/runtime/cli/bin/dsh.cmd); the .cmd mangles quoted args with spaces.
dsh() { ELECTRON_RUN_AS_NODE=1 "$APP/DeepSeek Harness.exe" --expose-internals "$APP/resources/app.asar/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js" "$@"; }
# The headless profile disables DSH's credential store, so pass stored keys through the environment.
CRED="$HOME/.dsh/.credentials.yaml"
if [[ -r "$CRED" ]]; then
  while IFS='=' read -r ref val; do
    [[ -n "$val" ]] && export "$ref=$val"
  done < <(sed -nE "s/^[[:space:]]+([A-Z0-9_]+_API_KEY):[[:space:]]*[\"']?([^\"' ]+).*/\1=\2/p" "$CRED")
fi
PATCH=()
if [[ -f "$ROOT/config/headless.patch.yml" ]]; then PATCH=(--patch "$(cygpath -w "$ROOT/config/headless.patch.yml")"); fi
cd "$WORKDIR"
dsh --profile headless "${PATCH[@]}" "$PROMPT"
