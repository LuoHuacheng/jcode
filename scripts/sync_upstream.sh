#!/usr/bin/env bash
# Update official/master then merge it into main.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sync_upstream.sh [--dry-run]

Fetches upstream/master, fast-forwards official/master, then merges it into
main. Uncommitted files are never included. Conflicts remain on main for manual
resolution.
EOF
}

dry_run=0
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

run() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  [[ "$dry_run" -eq 1 ]] || "$@"
}

[[ "$(git -C "$repo_root" branch --show-current)" == 'main' ]] || {
  echo "error: run from main so script can restore your local branch" >&2; exit 1;
}

if [[ -n "$(git -C "$repo_root" status --porcelain)" ]]; then
  echo "error: repository is dirty; commit, stash, or discard changes before syncing." >&2
  exit 1
fi

if [[ "$dry_run" -eq 1 ]]; then
  echo
  echo 'Would fetch upstream/master, fast-forward official/master, then merge it into main:'
  echo 'Official commits that would be merged:'
  git -C "$repo_root" log --oneline main..official/master
  echo
  echo 'Dry run makes no Git changes or network requests. Re-run without --dry-run to sync.'
  exit 0
fi

run git -C "$repo_root" fetch upstream master
run git -C "$repo_root" branch -f official/master upstream/master

if ! git -C "$repo_root" merge --no-ff official/master -m 'Merge official/master into main'; then
  cat <<EOF

Official merge conflict remains on main.
Resolve, then run:
  git add <resolved-files>
  git commit
EOF
  exit 1
fi

echo "Synced upstream/master into main: $(git -C "$repo_root" rev-parse --short HEAD)"
