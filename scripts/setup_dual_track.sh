#!/usr/bin/env bash
# Initialize official/master in the current checkout; never creates a worktree.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
remote="${1:-upstream}"

[[ "$(git -C "$repo_root" branch --show-current)" == main ]] || {
  echo 'error: switch to main before initializing dual-track branches.' >&2
  exit 1
}
git -C "$repo_root" remote get-url "$remote" >/dev/null 2>&1 || {
  echo "error: remote \"$remote\" is required (official repository)." >&2
  exit 1
}
[[ -z "$(git -C "$repo_root" status --porcelain)" ]] || {
  echo 'error: repository is dirty; commit, stash, or discard changes before initialization.' >&2
  exit 1
}

git -C "$repo_root" fetch "$remote" master
git -C "$repo_root" branch -f official/master "$remote/master"
printf 'Initialized official/master from %s/master.\n' "$remote"
