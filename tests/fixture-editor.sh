#!/usr/bin/env bash
set -euo pipefail

: "${SOPS_VAULT_TEST_VALUE:?missing SOPS_VAULT_TEST_VALUE}"
[ "$#" -eq 1 ] || exit 2
printf 'EXAMPLE_TOKEN=%s\n' "$SOPS_VAULT_TEST_VALUE" > "$1"
