#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source scripts/lib.sh

[ "$#" -eq 1 ] || vault_fail "usage: mise run secret-edit -- <logical-path>"
secret_ref="$1"
vault_validate_ref "$secret_ref"
vault_require_command sops

matches=()
for format in env json yaml; do
  candidate="secrets/${secret_ref}.sops.${format}"
  [ ! -f "$candidate" ] || matches+=("$candidate")
done

case "${#matches[@]}" in
  0) vault_fail "secret payload not found: $secret_ref" ;;
  1) ;;
  *) vault_fail "secret path resolves to multiple payloads: $secret_ref" ;;
esac

git ls-files --error-unmatch "${matches[0]}" >/dev/null 2>&1 \
  || vault_fail "secret payload is not tracked: ${matches[0]}"

sops "${matches[0]}"
./scripts/verify.sh
printf 'ok updated %s\n' "${matches[0]}"
