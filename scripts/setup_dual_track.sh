#!/usr/bin/env bash
# Create isolated worktrees for upstream, local customizations, and their merge.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/setup_dual_track.sh [--base-dir DIR] [--dry-run]

Creates sibling worktrees:
  DIR/jcode-official     official/master, fast-forward only from upstream/master
  DIR/jcode-integration  integration/master, starts from local/main

Current checkout remains local development worktree on main. local/main is a
stable local branch name pointing at its initial HEAD. Existing worktrees and
branches are never replaced.
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

git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null
git -C "$repo_root" remote get-url upstream >/dev/null || {
  echo 'error: remote "upstream" is required (official repository).' >&2
  exit 1
}

official_dir="$base_dir/jcode-official"
integration_dir="$base_dir/jcode-integration"

if [[ -e "$official_dir" || -e "$integration_dir" ]]; then
  echo "error: worktree destination already exists: $official_dir or $integration_dir" >&2
  echo 'Refusing to reuse or overwrite an existing directory.' >&2
  exit 1
fi

if git -C "$repo_root" show-ref --verify --quiet refs/heads/official/master \
  || git -C "$repo_root" show-ref --verify --quiet refs/heads/local/main \
  || git -C "$repo_root" show-ref --verify --quiet refs/heads/integration/master; then
  echo 'error: one or more dual-track branches already exist.' >&2
  echo 'Inspect `git worktree list` and use the existing worktrees instead.' >&2
  exit 1
fi

run git -C "$repo_root" fetch upstream master
run git -C "$repo_root" branch official/master upstream/master
run git -C "$repo_root" branch local/main main
run git -C "$repo_root" branch integration/master local/main
run git -C "$repo_root" worktree add "$official_dir" official/master
run git -C "$repo_root" worktree add "$integration_dir" integration/master

cat <<EOF

Dual-track worktrees ready.
  Local:       $repo_root (main, local/main)
  Official:    $official_dir (official/master)
  Integration: $integration_dir (integration/master)

Next: run scripts/sync_upstream.sh --dry-run, then scripts/sync_upstream.sh.
EOF
