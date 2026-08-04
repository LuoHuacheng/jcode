#!/usr/bin/env bash
# Build or run a dual-track worktree without sharing JCODE_HOME, socket, or target artifacts.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build_channel.sh <official|local|integration> <build|run|path> [-- args...]

Each channel uses:
  ~/.jcode/channels/<channel>/home    runtime state, sessions, server data
  ~/.jcode/channels/<channel>/runtime daemon lock and Unix sockets
  ~/.jcode/channels/<channel>/target  Cargo artifacts
  ~/.jcode/channels/<channel>/jcode.sock

`build` compiles TUI binary and copies it into channel home. `run` builds when
needed, then executes `jcode run --no-update --socket <channel socket>` with
any trailing arguments. `path` prints source, binary, home, and socket paths.
EOF
}

[[ $# -ge 2 ]] || { usage >&2; exit 2; }
channel="$1"
action="$2"
shift 2
[[ "${1:-}" != '--' ]] || shift

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_dir="$(dirname "$repo_root")"
case "$channel" in
  local) source_dir="$repo_root" ;;
  official) source_dir="$base_dir/jcode-official" ;;
  integration) source_dir="$base_dir/jcode-integration" ;;
  *) echo "error: unsupported channel: $channel" >&2; usage >&2; exit 2 ;;
esac

git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "error: source worktree missing: $source_dir" >&2
  exit 1
}

channel_root="${JCODE_CHANNEL_ROOT:-$HOME/.jcode/channels}/$channel"
channel_home="$channel_root/home"
runtime_dir="$channel_root/runtime"
target_dir="$channel_root/target"
binary="$channel_root/bin/jcode"
socket="$channel_root/jcode.sock"

print_paths() {
  printf 'channel=%s\nsource=%s\nhome=%s\nruntime=%s\ntarget=%s\nbinary=%s\nsocket=%s\n' \
    "$channel" "$source_dir" "$channel_home" "$runtime_dir" "$target_dir" "$binary" "$socket"
}

build() {
  mkdir -p "$(dirname "$binary")" "$channel_home" "$runtime_dir" "$target_dir"
  (
    cd "$source_dir"
    JCODE_HOME="$channel_home" JCODE_RUNTIME_DIR="$runtime_dir" CARGO_TARGET_DIR="$target_dir" \
      ./scripts/dev_cargo.sh build --profile selfdev -p jcode --bin jcode
  )
  install -m 755 "$target_dir/selfdev/jcode" "$binary"
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
