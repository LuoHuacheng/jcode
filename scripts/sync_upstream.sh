#!/usr/bin/env bash
# Update official/master then merge it into integration/master without touching local/main.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sync_upstream.sh [--base-dir DIR] [--dry-run]

Fetches upstream/master, fast-forwards official/master in jcode-official, then
merges official/master into integration/master in jcode-integration. It never
changes local/main or current development worktree. Conflicts stop the merge
in integration worktree for manual resolution.
EOF
}

dry_run=0
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_dir="$(dirname "$repo_root")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir) [[ $# -ge 2 ]] || { echo 'error: --base-dir needs a path' >&2; exit 2; }; base_dir="$2"; shift 2 ;;
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

official_dir="$base_dir/jcode-official"
integration_dir="$base_dir/jcode-integration"
for path in "$official_dir" "$integration_dir"; do
  git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "error: missing dual-track worktree: $path" >&2
    echo 'Run scripts/setup_dual_track.sh first.' >&2
    exit 1
  }
done

[[ "$(git -C "$official_dir" branch --show-current)" == 'official/master' ]] || {
  echo "error: $official_dir must check out official/master" >&2; exit 1;
}
[[ "$(git -C "$integration_dir" branch --show-current)" == 'integration/master' ]] || {
  echo "error: $integration_dir must check out integration/master" >&2; exit 1;
}

for path in "$official_dir" "$integration_dir"; do
  if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
    echo "error: worktree is dirty: $path" >&2
    echo 'Commit, stash, or discard its changes before syncing.' >&2
    exit 1
  fi
done

run git -C "$repo_root" fetch upstream master
run git -C "$official_dir" merge --ff-only upstream/master

if [[ "$dry_run" -eq 1 ]]; then
  echo
  echo 'Integration commits that would be merged:'
  git -C "$integration_dir" log --oneline HEAD..official/master
  echo
  echo 'Dry run makes no Git changes. Re-run without --dry-run to merge.'
  exit 0
fi

if ! git -C "$integration_dir" merge --no-ff official/master -m 'Merge upstream/master into integration/master'; then
  cat <<EOF

Merge conflict left only in: $integration_dir
Resolve there, then run:
  git -C "$integration_dir" add <resolved-files>
  git -C "$integration_dir" commit
EOF
  exit 1
fi

echo "Synced upstream/master into integration/master: $(git -C "$integration_dir" rev-parse --short HEAD)"
