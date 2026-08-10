#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source scripts/lib.sh

[ "$#" -gt 0 ] || vault_fail "usage: scripts/validate-secret.sh <ciphertext> [...]"
vault_require_command jq
vault_require_command sops

for secret_file in "$@"; do
  secret_file="$(vault_normalize_ciphertext_path "$repo_root" "$secret_file")"
  [ ! -L "$secret_file" ] || vault_fail "secret payload must not be a symbolic link: $secret_file"
  [ -f "$secret_file" ] || vault_fail "secret payload not found: $secret_file"

  payload_json="$(sops decrypt --output-type json "$secret_file")" \
    || vault_fail "could not decrypt $secret_file"
  leaf_count="$(jq '[paths(scalars)] | length' <<<"$payload_json")"
  [ "$leaf_count" -gt 0 ] || vault_fail "$secret_file contains no secret values"

  errors="$(jq -r -f scripts/validate-secret.jq <<<"$payload_json")"
  [ -z "$errors" ] || vault_fail "$secret_file failed baseline validation: $errors"

  if [ -x scripts/validate-secret-policy.sh ]; then
    printf '%s\n' "$payload_json" \
      | scripts/validate-secret-policy.sh "$secret_file" \
      || vault_fail "$secret_file failed repository policy"
  fi

  printf 'ok %s decrypted values passed validation\n' "$secret_file"
done
