# _args.sh — shared argument parsing for ds.sh / cb.sh (sourced).
# Sets WORKDIR, MODEL_ARG, PROMPT. Usage text comes from $USAGE.
die() { echo "$(basename "$0"): $*" >&2; echo "usage: $USAGE" >&2; exit 2; }
WORKDIR="$PWD"; MODEL_ARG=""; PROMPT=""
while (( $# )); do
  case "$1" in
    -C|-m) [[ $# -ge 2 && -n "$2" && "$2" != -?* ]] || die "$1 needs a value"
           if [[ "$1" == -C ]]; then WORKDIR="$(cygpath -u "$2" 2>/dev/null || printf '%s' "$2")"; else MODEL_ARG="$2"; fi
           shift 2 ;;
    --) shift; [[ $# -eq 1 ]] || die "expected exactly one prompt after --"; PROMPT="$1"; shift ;;
    -)  PROMPT="$(cat)"; shift ;;
    -?*) die "unknown option $1" ;;
    *)  [[ -z "$PROMPT" ]] || die "more than one prompt given"; PROMPT="$1"; shift ;;
  esac
done
[[ -n "$PROMPT" ]] || die "missing prompt"
[[ -d "$WORKDIR" ]] || die "workdir not found: $WORKDIR"
# Git Bash rewrites POSIX-looking args (e.g. /d/foo) for native exes; keep prompts verbatim.
export MSYS2_ARG_CONV_EXCL='*'
