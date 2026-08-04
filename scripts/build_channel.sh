#!/usr/bin/env bash
# Build or run branch channels from one checkout with isolated runtime artifacts.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build_channel.sh <official|local> <build|run|path> [-- args...]

Each channel uses one source checkout and isolated runtime artifacts:
  ~/.jcode/channels/<channel>/home    runtime state, sessions, server data
  ~/.jcode/channels/<channel>/runtime daemon lock and Unix sockets
  ~/.jcode/channels/<channel>/target  Cargo artifacts
  ~/.jcode/channels/<channel>/jcode.sock

`build` temporarily switches to channel branch, compiles TUI binary, copies it
into channel home, then restores original branch. Repository must be clean.
`run` builds when needed, then executes `jcode run --no-update --socket
<channel socket>` with any trailing arguments. `path` prints paths.
EOF
}

[[ $# -ge 2 ]] || { usage >&2; exit 2; }
channel="$1"
action="$2"
shift 2
[[ "${1:-}" != '--' ]] || shift

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$channel" in
  local) branch="main" ;;
  official) branch="official/master" ;;
  *) echo "error: unsupported channel: $channel" >&2; usage >&2; exit 2 ;;
esac

git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch" || {
  echo "error: missing branch: $branch" >&2; exit 1;
}

channel_root="${JCODE_CHANNEL_ROOT:-$HOME/.jcode/channels}/$channel"
channel_home="$channel_root/home"
runtime_dir="$channel_root/runtime"
target_dir="$channel_root/target"
binary="$channel_root/bin/jcode"
socket="$channel_root/jcode.sock"

print_paths() {
  printf 'channel=%s\nsource=%s\nhome=%s\nruntime=%s\ntarget=%s\nbinary=%s\nsocket=%s\n' \
    "$channel" "$repo_root@$branch" "$channel_home" "$runtime_dir" "$target_dir" "$binary" "$socket"
}

build() {
  mkdir -p "$(dirname "$binary")" "$channel_home" "$runtime_dir" "$target_dir"
  [[ -z "$(git -C "$repo_root" status --porcelain)" ]] || {
    echo 'error: repository is dirty; commit, stash, or discard changes before building another branch.' >&2
    exit 1
  }
  original_branch="$(git -C "$repo_root" branch --show-current)"
  [[ -n "$original_branch" ]] || { echo 'error: detached HEAD is unsupported.' >&2; exit 1; }
  if [[ "$original_branch" != "$branch" ]]; then
    git -C "$repo_root" switch "$branch"
  fi
  restore_branch() {
    if [[ "$(git -C "$repo_root" branch --show-current)" != "$original_branch" ]]; then
      git -C "$repo_root" switch "$original_branch"
    fi
  }
  trap restore_branch RETURN
  (
    cd "$repo_root"
    JCODE_HOME="$channel_home" JCODE_RUNTIME_DIR="$runtime_dir" CARGO_TARGET_DIR="$target_dir" \
      ./scripts/dev_cargo.sh build --profile selfdev -p jcode --bin jcode
  )
  install -m 755 "$target_dir/selfdev/jcode" "$binary"
  trap - RETURN
  restore_branch
  printf 'Built %s channel: %s\n' "$channel" "$binary"
}

case "$action" in
  path) [[ $# -eq 0 ]] || { echo 'error: path accepts no extra arguments' >&2; exit 2; }; print_paths ;;
  build) [[ $# -eq 0 ]] || { echo 'error: build accepts no extra arguments' >&2; exit 2; }; build ;;
  run)
    [[ -x "$binary" ]] || build
    mkdir -p "$channel_home" "$runtime_dir"
    exec env JCODE_HOME="$channel_home" JCODE_RUNTIME_DIR="$runtime_dir" \
      "$binary" run --no-update --socket "$socket" "$@"
    ;;
  *) echo "error: unsupported action: $action" >&2; usage >&2; exit 2 ;;
esac
