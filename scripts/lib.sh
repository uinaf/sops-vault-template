#!/usr/bin/env bash

vault_fail() {
  printf 'FAILED: %s\n' "$1" >&2
  exit 1
}

vault_require_command() {
  command -v "$1" >/dev/null 2>&1 || vault_fail "missing required command: $1"
}

vault_validate_ref() {
  local secret_ref="$1"
  local component
  local old_ifs="$IFS"

  [ -n "$secret_ref" ] || vault_fail "secret path is required"
  case "$secret_ref" in
    /*|*/|*//*|secrets/*|*.sops.env|*.sops.json|*.sops.yaml)
      vault_fail "use a logical path such as integrations/example"
      ;;
  esac

  IFS=/
  for component in $secret_ref; do
    [[ "$component" =~ ^[a-z0-9][a-z0-9._-]*$ ]] \
      || vault_fail "invalid secret path component: $component"
  done
  IFS="$old_ifs"
}
