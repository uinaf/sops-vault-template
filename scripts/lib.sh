#!/usr/bin/env bash

vault_fail() {
  printf 'FAILED: %s\n' "$1" >&2
  exit 1
}

vault_require_command() {
  command -v "$1" >/dev/null 2>&1 || vault_fail "missing required command: $1"
}

vault_normalize_ciphertext_path() {
  local repo_root="$1"
  local secret_file="$2"
  local canonical_root
  local secret_parent
  local component
  local parent_path
  local remaining

  canonical_root="$(cd "$repo_root" && pwd -P)"
  case "$secret_file" in
    /*)
      secret_parent="$(cd "$(dirname "$secret_file")" 2>/dev/null && pwd -P)" \
        || vault_fail "secret payload parent does not exist: $secret_file"
      secret_file="$secret_parent/$(basename "$secret_file")"
      case "$secret_file" in
        "$canonical_root"/*) secret_file=${secret_file#"$canonical_root"/} ;;
        *) vault_fail "secret payload path is outside this vault: $secret_file" ;;
      esac
      ;;
    *) secret_file=${secret_file#./} ;;
  esac
  case "$secret_file" in
    ..|../*|*/..|*/../*) vault_fail "secret payload path must not traverse parent directories: $secret_file" ;;
  esac

  # Resolve existing ancestors before allowing callers to create missing ones.
  parent_path="$canonical_root"
  remaining="$(dirname "$secret_file")"
  while [ -n "$remaining" ]; do
    component=${remaining%%/*}
    if [ "$remaining" = "$component" ]; then
      remaining=""
    else
      remaining=${remaining#*/}
    fi
    parent_path="$parent_path/$component"
    if [ -e "$parent_path" ] || [ -L "$parent_path" ]; then
      [ -d "$parent_path" ] || vault_fail "secret payload parent is not a directory: $secret_file"
      parent_path="$(cd "$parent_path" && pwd -P)"
      case "$parent_path" in
        "$canonical_root"|"$canonical_root"/*) ;;
        *) vault_fail "secret payload path is outside this vault: $secret_file" ;;
      esac
    fi
  done
  secret_file="$parent_path/$(basename "$secret_file")"
  [ ! -L "$secret_file" ] || vault_fail "secret payload must not be a symbolic link: $secret_file"
  secret_file=${secret_file#"$canonical_root"/}
  case "$secret_file" in
    secrets/*.sops.env|secrets/*.sops.json|secrets/*.sops.yaml) ;;
    *) vault_fail "unsupported secret payload path: $secret_file" ;;
  esac
  printf '%s\n' "$secret_file"
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
