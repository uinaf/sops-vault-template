#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'FAILED: %s\n' "$1" >&2
  exit 1
}

assert_rejected() {
  local document="$1"
  local expected="$2"
  local output

  output="$(jq -r -f scripts/validate-secret.jq <<<"$document")"
  grep -Fq "$expected" <<<"$output" \
    || fail "baseline did not reject $expected"
}

[ -z "$(jq -r -f scripts/validate-secret.jq <<<'{"TOKEN":"valid"}')" ] \
  || fail "baseline rejected a valid string"
assert_rejected '{"TOKEN":"'"'"'wrapped'"'"'"}' 'literal quote-wrapped value'
assert_rejected '{"TOKEN":""}' 'empty value'
assert_rejected '{"TOKEN":42}' 'expected a string value'

printf 'ok valid strings accepted; wrapped, empty, and non-string values rejected\n'
