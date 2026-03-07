#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_md() {
  HOME=/tmp dub run -q -- "$@"
}

assert_has() {
  local output="$1"
  local pattern="$2"
  local message="$3"
  if ! grep -Eq "$pattern" <<<"$output"; then
    echo "[oracle] FAIL: $message" >&2
    echo "[oracle] missing pattern: $pattern" >&2
    exit 1
  fi
}

assert_not_has() {
  local output="$1"
  local pattern="$2"
  local message="$3"
  if grep -Eq "$pattern" <<<"$output"; then
    echo "[oracle] FAIL: $message" >&2
    echo "[oracle] unexpected pattern: $pattern" >&2
    exit 1
  fi
}

assert_fails() {
  local output
  set +e
  output="$(run_md "$@" 2>&1)"
  local status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    echo "[oracle] FAIL: command was expected to fail: $*" >&2
    exit 1
  fi
  printf '%s' "$output"
}

echo "[oracle] check sh unset variable failure"
out_unset="$(assert_fails examples/test-shell-errors.md --filter sh_unset)"
assert_has "$out_unset" 'begin: sh_unset' 'sh failure must still print begin log'
assert_has "$out_unset" 'UNSET_SH_VAR' 'unset variable failure should mention the variable'
assert_has "$out_unset" 'Errors: 1' 'sh unset failure should count as one error'

echo "[oracle] check bash pipefail behavior"
out_pipefail="$(assert_fails examples/test-shell-errors.md --filter bash_pipefail)"
assert_has "$out_pipefail" 'begin: bash_pipefail' 'bash failure must still print begin log'
assert_not_has "$out_pipefail" 'must-not-print' 'bash pipeline failure must stop the script before the next command'
assert_has "$out_pipefail" 'Errors: 1' 'bash pipefail failure should count as one error'

echo "[oracle] check --buildOnly skips shell execution"
buildonly_target="$ROOT_DIR/build-only-should-not-exist"
rm -f "$buildonly_target"
out_buildonly="$(run_md examples/test-shell-buildonly.md --buildOnly 2>&1)"
assert_has "$out_buildonly" '^Success all blocks\.$' '--buildOnly run should still succeed'
if [[ -e "$buildonly_target" ]]; then
  echo "[oracle] FAIL: --buildOnly executed shell script unexpectedly" >&2
  exit 1
fi

echo "[oracle] check missing bash interpreter handling"
tmp_bin="$(mktemp -d)"
ln -s "$(command -v sh)" "$tmp_bin/sh"
set +e
out_missing_bash="$(HOME=/tmp PATH="$tmp_bin" ./md examples/test-shell.md --filter bash_test 2>&1)"
status_missing_bash=$?
set -e
rm -rf "$tmp_bin"
if [[ $status_missing_bash -eq 0 ]]; then
  echo "[oracle] FAIL: missing bash interpreter should fail" >&2
  exit 1
fi
assert_has "$out_missing_bash" 'failed to start bash interpreter' 'missing bash should report interpreter startup failure'
assert_has "$out_missing_bash" 'Ensure `bash` is available on PATH' 'missing bash should explain the PATH requirement'
assert_has "$out_missing_bash" 'Errors: 1' 'missing bash failure should count as one error'

echo "[oracle] PASS"
