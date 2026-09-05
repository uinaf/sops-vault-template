#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source scripts/lib.sh

format="env"
secret_ref=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --format)
      shift
      [ "$#" -gt 0 ] || vault_fail "--format requires env, json, or yaml"
      format="$1"
      ;;
    --help|-h)
      printf 'usage: mise run secret-new -- [--format env|json|yaml] <logical-path>\n'
      exit 0
      ;;
    -*) vault_fail "unknown option: $1" ;;
    *)
      [ -z "$secret_ref" ] || vault_fail "only one logical path is allowed"
      secret_ref="$1"
      ;;
  esac
  shift
done

case "$format" in
  env|json|yaml) ;;
  *) vault_fail "unsupported format: $format" ;;
esac

vault_validate_ref "$secret_ref"
vault_require_command sops
[ -f .sops.yaml ] || vault_fail "missing .sops.yaml; configure recipients first"

for candidate_format in env json yaml; do
  candidate="secrets/${secret_ref}.sops.${candidate_format}"
  vault_normalize_ciphertext_path "$repo_root" "$candidate" >/dev/null
  [ ! -e "$candidate" ] || vault_fail "secret payload already exists: $candidate"
done

target="secrets/${secret_ref}.sops.${format}"
mkdir -p "$(dirname "$target")"
vault_normalize_ciphertext_path "$repo_root" "$target" >/dev/null
sops "$target"

status="$(sops filestatus "$target" 2>/dev/null)" \
  || vault_fail "SOPS could not inspect new payload: $target"
printf '%s\n' "$status" | grep -Eq '"encrypted"[[:space:]]*:[[:space:]]*true' \
  || vault_fail "new payload is not encrypted: $target"

./scripts/validate-secret.sh "$target"
./scripts/verify.sh
printf 'ok created %s\n' "$target"
