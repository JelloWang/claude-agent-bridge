#!/usr/bin/env bash
# dispatch.sh — run one agent job inside a run directory and keep a full trace.
# Usage: dispatch.sh <run-dir> <ds|cb> <job-name> [-m model]
# Reads  <run-dir>/<job-name>.task.md
# Writes <run-dir>/<job-name>.out.md (agent answer) and <job-name>.log (metadata + stderr).
# The agent's working directory is <run-dir>, so it should only read <run-dir>/snapshot.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="${1:?run-dir}"; AGENT="${2:?ds|cb}"; JOB="${3:?job-name}"; shift 3
case "$AGENT" in ds|cb) ;; *) echo "dispatch.sh: agent must be ds or cb" >&2; exit 2 ;; esac
TASK="$RUN/$JOB.task.md"; OUT="$RUN/$JOB.out.md"; LOG="$RUN/$JOB.log"
[[ -f "$TASK" ]] || { echo "dispatch.sh: missing $TASK" >&2; exit 2; }
start=$(date +%s)
{ echo "agent=$AGENT job=$JOB args=$* "; echo "start=$(date '+%F %T')"; echo "--- stderr"; } > "$LOG"
"$HERE/$AGENT.sh" -C "$RUN" "$@" - < "$TASK" > "$OUT" 2>> "$LOG"
rc=$?
{ echo "---"; echo "end=$(date '+%F %T') elapsed=$(( $(date +%s) - start ))s rc=$rc"; } >> "$LOG"
exit $rc
