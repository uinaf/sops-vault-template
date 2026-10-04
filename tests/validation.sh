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

# Bash backs a here-string with a temporary file (3.2 always, 5.x above the
# pipe buffer), so decrypted payloads must reach jq through a pipe.
fixture_root="$(mktemp -d)"
trap 'rm -rf -- "$fixture_root"' EXIT
mkdir -p "$fixture_root/vault/scripts" "$fixture_root/vault/secrets" "$fixture_root/bin"
cp scripts/lib.sh scripts/validate-secret.sh scripts/validate-secret.jq "$fixture_root/vault/scripts/"
touch "$fixture_root/vault/secrets/large.sops.json"
cat >"$fixture_root/bin/sops" <<'EOF'
#!/usr/bin/env bash
printf '{"TOKEN":"%s"}\n' "$(head -c 100000 /dev/zero | tr '\0' x)"
EOF
cat >"$fixture_root/bin/jq" <<EOF
#!/usr/bin/env bash
touch "$fixture_root/jq-called"
[ ! -f /dev/stdin ] || touch "$fixture_root/jq-read-a-file"
exec "$(command -v jq)" "\$@"
EOF
chmod +x "$fixture_root/bin/sops" "$fixture_root/bin/jq"
(cd "$fixture_root/vault" && PATH="$fixture_root/bin:$PATH" \
  ./scripts/validate-secret.sh secrets/large.sops.json </dev/null >/dev/null) \
  || fail "validate-secret rejected a valid decrypted payload"
[ -e "$fixture_root/jq-called" ] || fail "validate-secret never ran jq"
[ ! -e "$fixture_root/jq-read-a-file" ] \
  || fail "validate-secret passed a decrypted payload to jq through a temporary file"

printf 'ok valid strings accepted; wrapped, empty, and non-string values rejected; payloads piped to jq\n'
