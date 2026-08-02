#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source scripts/lib.sh

vault_require_command git
vault_require_command sops
[ -f recipients.yaml ] || vault_fail "missing recipients.yaml"
[ -f .sops.yaml.example ] || vault_fail "missing .sops.yaml.example"
[ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = AGENTS.md ] \
  || vault_fail "CLAUDE.md must link to AGENTS.md"

registered_recipients="$(grep -Eo 'age1[0-9a-z]+' recipients.yaml | sort -u || true)"
recipient_count="$(printf '%s\n' "$registered_recipients" | sed '/^$/d' | wc -l | tr -d ' ')"

payload_count=0
if [ -d secrets ]; then
  payload_count="$(find secrets -type f | wc -l | tr -d ' ')"
fi

if [ ! -f .sops.yaml ]; then
  [ "$recipient_count" -eq 0 ] \
    || vault_fail "recipients configured without .sops.yaml"
  [ "$payload_count" -eq 0 ] \
    || vault_fail "secret payloads exist before vault initialization"
else
  [ "$recipient_count" -ge 2 ] \
    || vault_fail "initialized vault requires recovery and deployment recipients"
  ! grep -Eq 'AGE_(RECOVERY|DEPLOYMENT)_RECIPIENT' .sops.yaml \
    || vault_fail "replace recipient placeholders in .sops.yaml"

  policy_recipients="$(grep -Eo 'age1[0-9a-z]+' .sops.yaml | sort -u || true)"
  [ "$registered_recipients" = "$policy_recipients" ] \
    || vault_fail "recipients.yaml and .sops.yaml recipients differ"

  if [ -d secrets ]; then
    while IFS= read -r secret_file; do
      [ -n "$secret_file" ] || continue
      case "$secret_file" in
        *.sops.yaml|*.sops.json|*.sops.env) ;;
        *) vault_fail "secret payload does not use a .sops extension: $secret_file" ;;
      esac

      status="$(sops filestatus "$secret_file" 2>/dev/null)" \
        || vault_fail "SOPS could not inspect $secret_file"
      printf '%s\n' "$status" | grep -Eq '"encrypted"[[:space:]]*:[[:space:]]*true' \
        || vault_fail "plaintext or invalid secret payload: $secret_file"
    done < <(find secrets -type f -print | sort)
  fi
fi

if git ls-files | grep -E '(^|/)(keys\.txt|[^/]+\.(agekey|pem|key))$' >/dev/null; then
  vault_fail "tracked private-key material"
fi

age_key_pattern='AGE-SECRET''-KEY-'
pem_key_pattern='-----BEGIN [A-Z0-9 ]*PRIVATE'' KEY-----'
if git grep -I -E "$age_key_pattern|$pem_key_pattern" -- . >/dev/null; then
  vault_fail "tracked private-key contents"
fi

git diff --check
git diff --cached --check

if [ -f .sops.yaml ]; then
  printf 'ok initialized vault policy, ciphertext boundary, and diff hygiene\n'
else
  printf 'ok uninitialized template boundary and diff hygiene\n'
fi
