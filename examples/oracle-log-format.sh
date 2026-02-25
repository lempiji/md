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

echo "[oracle] check default named log format"
out_default_shell="$(run_md examples/test-shell.md 2>&1)"
assert_has "$out_default_shell" '^begin: sh_test$' 'default log must keep name-only format for sh_test'
assert_has "$out_default_shell" '^begin: bash_test$' 'default log must keep name-only format for bash_test'
assert_not_has "$out_default_shell" '^begin: (d|sh|bash):' 'default log must not include language prefix for named blocks'

echo "[oracle] check --show-lang named log format"
out_lang_shell="$(run_md examples/test-shell.md --show-lang 2>&1)"
assert_has "$out_lang_shell" '^begin: sh:sh_test$' '--show-lang must include sh:sh_test'
assert_has "$out_lang_shell" '^begin: sh:bash_test$' '--show-lang must include sh:bash_test'
assert_has "$out_lang_shell" '^begin: bash:sh_test$' '--show-lang must include bash:sh_test'
assert_has "$out_lang_shell" '^begin: bash:bash_test$' '--show-lang must include bash:bash_test'

echo "[oracle] check default single/global log format"
out_default_readme="$(run_md README.md 2>&1)"
assert_has "$out_default_readme" '^begin single: 0$' 'default single log must keep numeric label'
assert_has "$out_default_readme" '^begin global :0$' 'default global log must keep numeric label (0)'
assert_has "$out_default_readme" '^begin global :1$' 'default global log must keep numeric label (1)'
assert_not_has "$out_default_readme" '^begin single: d:0$' 'default single log must not include language prefix'
assert_not_has "$out_default_readme" '^begin global :d:0$' 'default global log must not include language prefix'

echo "[oracle] check --show-lang single/global log format"
out_lang_readme="$(run_md README.md --show-lang 2>&1)"
assert_has "$out_lang_readme" '^begin: d:main$' '--show-lang must include d prefix for named D block'
assert_has "$out_lang_readme" '^begin: sh:shell_sample$' '--show-lang must include sh prefix for named shell block'
assert_has "$out_lang_readme" '^begin single: d:0$' '--show-lang must include d prefix for single block'
assert_has "$out_lang_readme" '^begin global :d:0$' '--show-lang must include d prefix for global block (0)'
assert_has "$out_lang_readme" '^begin global :d:1$' '--show-lang must include d prefix for global block (1)'

echo "[oracle] PASS"
