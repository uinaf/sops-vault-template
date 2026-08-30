#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'FAILED: %s\n' "$1" >&2
  exit 1
}

formats='{
  "hex8": {
    "pattern": "^[a-f0-9]{8}$",
    "description": "an 8-character hex id",
    "example": "0123abcd"
  },
  "block": {
    "pattern": "\\A-----BEGIN TEST-----\\n[\\s\\S]+\\n-----END TEST-----\\n?\\z",
    "description": "a test block",
    "example": "-----BEGIN TEST-----\npayload\n-----END TEST-----",
    "multiline": true
  }
}'
contracts='{
  "secrets/example.sops.json": {
    "keys": {
      "TOKEN_A": "hex8",
      "TOKEN_B": {"format": "hex8", "example": "89abcdef"},
      "BLOCK": "block"
    },
    "distinct": [["TOKEN_A", "TOKEN_B"]]
  }
}'

policy() {
  jq -nr -L scripts \
    --argjson formats "$formats" \
    --argjson contracts "$contracts" \
    --arg secret_file "$1" \
    --argjson payload "$2" \
    'include "policy-engine";
     $payload | validate($contracts; $formats; $secret_file)'
}

mutate() {
  jq -c "$2" <<<"$1"
}

fixture="$(jq -nc -L scripts \
  --argjson formats "$formats" --argjson contracts "$contracts" \
  'include "policy-engine";
   contract_fixtures($contracts; $formats)["secrets/example.sops.json"]')"

[ -z "$(policy secrets/example.sops.json "$fixture")" ] \
  || fail "engine rejected its own derived fixture"

policy secrets/other.sops.json "$fixture" \
  | grep -Fq 'no registered semantic contract for secrets/other.sops.json' \
  || fail "unregistered payload did not explain how to register its contract"

policy secrets/example.sops.json "$(mutate "$fixture" 'del(.TOKEN_A)')" \
  | grep -Fq 'key inventory does not match' \
  || fail "engine accepted a missing key"

policy secrets/example.sops.json "$(mutate "$fixture" '.EXTRA = "0123abcd"')" \
  | grep -Fq 'key inventory does not match' \
  || fail "engine accepted an extra key"

policy secrets/example.sops.json "$(mutate "$fixture" '.TOKEN_A = "nope"')" \
  | grep -Fq 'TOKEN_A: expected an 8-character hex id' \
  || fail "engine accepted a format mismatch"

policy secrets/example.sops.json "$(mutate "$fixture" '.TOKEN_A = "0123abcd\nevil"')" \
  | grep -Fq 'TOKEN_A: unexpected multiline value' \
  || fail "engine accepted a multiline single-line value"

policy secrets/example.sops.json "$(mutate "$fixture" '.TOKEN_B = " 89abcdef"')" \
  | grep -Fq 'TOKEN_B: leading or trailing whitespace' \
  || fail "engine accepted surrounding whitespace"

policy secrets/example.sops.json "$(mutate "$fixture" '.TOKEN_B = .TOKEN_A')" \
  | grep -Fq 'values must all differ: TOKEN_A, TOKEN_B' \
  || fail "engine accepted duplicate values in a distinct group"

policy secrets/example.sops.json "$(mutate "$fixture" '.BLOCK = "-----BEGIN TEST-----\npayload"')" \
  | grep -Fq 'BLOCK: expected a test block' \
  || fail "engine accepted a truncated multiline value"

broken_contracts='{"secrets/example.sops.json": {"keys": {"TOKEN_A": "missing"}}}'
jq -nr -L scripts \
  --argjson formats "$formats" --argjson contracts "$broken_contracts" \
  --argjson payload '{"TOKEN_A": "0123abcd"}' \
  'include "policy-engine";
   $payload | validate($contracts; $formats; "secrets/example.sops.json")' \
  | grep -Fq 'TOKEN_A: unregistered value format missing' \
  || fail "engine accepted a contract referencing an unregistered format"

printf 'ok policy engine contract routing, formats, and fixture derivation\n'
