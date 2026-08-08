#!/usr/bin/env bash
set -euo pipefail

# Contract checks for the single-checkout official/local channel workflow.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/jcode-dual-track.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

fixture="$tmp_root/repo"
mkdir -p "$fixture/scripts"
fixture="$(cd "$fixture" && pwd)"
cp "$repo_root/scripts/build_channel.sh" "$fixture/scripts/build_channel.sh"
cp "$repo_root/scripts/sync_upstream.sh" "$fixture/scripts/sync_upstream.sh"
cp "$repo_root/scripts/setup_dual_track.sh" "$fixture/scripts/setup_dual_track.sh"
git -C "$fixture" init -q -b main
git -C "$fixture" config user.email test@example.invalid
git -C "$fixture" config user.name test
printf 'fixture\n' > "$fixture/file"
git -C "$fixture" add file scripts
git -C "$fixture" commit -qm fixture
official_repo="$tmp_root/official.git"
git init -q --bare "$official_repo"
git -C "$fixture" remote add upstream "$official_repo"
git -C "$fixture" push -q upstream main:master
if (cd "$fixture" && "$fixture/scripts/sync_upstream.sh" --dry-run >/dev/null 2>"$tmp_root/missing.err"); then
  fail 'dry-run unexpectedly succeeded before initialization'
fi
case "$(<"$tmp_root/missing.err")" in
  *'run scripts/setup_dual_track.sh first.'*) ;;
  *) fail 'missing official/master diagnostic not shown' ;;
esac


(cd "$fixture" && "$fixture/scripts/setup_dual_track.sh" upstream)
git -C "$fixture" switch --orphan upstream-rewind -q
git -C "$fixture" commit --allow-empty -qm rewind
git -C "$fixture" push -q --force upstream HEAD:master
git -C "$fixture" switch main -q
if (cd "$fixture" && "$fixture/scripts/sync_upstream.sh" >/dev/null 2>"$tmp_root/non-ff.err"); then
  fail 'sync unexpectedly accepted non-fast-forward official update'
fi
[[ "$(git -C "$fixture" branch --show-current)" == main ]] || fail 'sync did not restore main after failure'
case "$(<"$tmp_root/non-ff.err")" in
  *'Not possible to fast-forward'*|*'fatal:'*|*'error:'*) ;;
  *) fail 'non-fast-forward diagnostic not shown' ;;
esac
git -C "$fixture" show-ref --verify --quiet refs/heads/official/master || fail 'setup did not create official/master'

path_output="$(JCODE_CHANNEL_ROOT="$tmp_root/channels" "$fixture/scripts/build_channel.sh" local path)"
check_path() {
  case "$path_output" in
    *"$1"*) ;;
    *) fail "missing path entry: $1" ;;
  esac
}

check_path "channel=local"
check_path "source=$fixture@main"
check_path "home=$tmp_root/channels/local/home"
check_path "runtime=$tmp_root/channels/local/runtime"
check_path "target=$tmp_root/channels/local/target"
check_path "binary=$tmp_root/channels/local/bin/jcode"
check_path "socket=$tmp_root/channels/local/jcode.sock"

official_output="$(JCODE_CHANNEL_ROOT="$tmp_root/channels" "$fixture/scripts/build_channel.sh" official path)"
case "$official_output" in
  *"channel=official"*) ;;
  *) fail 'official path output missing' ;;
esac
case "$official_output" in
  *"$tmp_root/channels/local/"*) fail 'channel paths overlap' ;;
esac

dry_run_output="$(cd "$fixture" && "$fixture/scripts/sync_upstream.sh" --dry-run)"
case "$dry_run_output" in
  *'Dry run makes no Git changes or network requests.'*) ;;
  *) fail 'dry-run output missing no-change guarantee' ;;
esac

echo 'dual-track script checks passed'
