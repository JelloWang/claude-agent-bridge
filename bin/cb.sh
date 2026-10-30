#!/usr/bin/env bash
# cb.sh — run one CodeBuddy Code job non-interactively and print the result.
# Usage: cb.sh [-C <workdir>] [-m <model>] "task prompt"     (use "-" to read the prompt from stdin)
# Install: npm i -g @tencent-ai/codebuddy-code, then run `codebuddy` once and /login.
# Exit codes: 2 = bad usage, 3 = not logged in.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
USAGE='cb.sh [-C dir] [-m model] "prompt" | -'
[[ -f "$ROOT/local.env" ]] && source "$ROOT/local.env"
source "$HERE/_args.sh"
# Prefer node + the package entry directly: the npm .cmd shim mangles quoted args with spaces.
# WorkBuddy users: CodeBuddy may live under WorkBuddy's bundled node (version dir changes on upgrade).
ENTRY=""; NODE=""
for d in $(ls -d "$HOME"/.workbuddy/binaries/node/versions/*/ 2>/dev/null | sort -rV) "$(dirname "$(command -v node 2>/dev/null || echo /x/x)")/"; do
  for m in "$d/node_modules" "$d/../lib/node_modules"; do
    if [[ -f "$m/@tencent-ai/codebuddy-code/bin/codebuddy" ]]; then
      ENTRY="$m/@tencent-ai/codebuddy-code/bin/codebuddy"; NODE="$d/node.exe"; [[ -f "$NODE" ]] || NODE="$(command -v node)"; break 2
    fi
  done
done
[[ -n "$ENTRY" ]] || { echo "cb.sh: CodeBuddy not found; run: npm i -g @tencent-ai/codebuddy-code" >&2; exit 1; }
cb() { "$(cygpath -w "$NODE")" "$(cygpath -w "$ENTRY")" "$@"; }   # Windows paths: MSYS path conversion is off (see _args.sh)
MODEL=(); [[ -n "$MODEL_ARG" ]] && MODEL=(--model "$MODEL_ARG")
cd "$WORKDIR"
# --allowedTools is variadic: use = form and "--" so it does not swallow the prompt.
OUT="$(cb -p "${MODEL[@]}" --permission-mode acceptEdits --allowedTools=Read,Edit,Write,Glob,Grep,Bash -- "$PROMPT")"
printf '%s\n' "$OUT"
if grep -q "Authentication required" <<<"$OUT"; then exit 3; fi
