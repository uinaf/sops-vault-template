#!/usr/bin/env bash
set -euo pipefail

: "${SOPS_VAULT_TEST_VALUE:?missing SOPS_VAULT_TEST_VALUE}"
[ "$#" -eq 1 ] || exit 2
jq -n --arg token "$SOPS_VAULT_TEST_VALUE" '{EXAMPLE_TOKEN: $token}' > "$1"
