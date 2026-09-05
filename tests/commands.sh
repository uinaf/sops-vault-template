#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'FAILED: %s\n' "$1" >&2
  exit 1
}

for command_name in age-keygen git jq mise sops; do
  command -v "$command_name" >/dev/null 2>&1 \
    || fail "missing required command: $command_name"
done

test_root="$(mktemp -d "${TMPDIR:-/tmp}/sops-vault-template-test.XXXXXX")"
key_root="$(mktemp -d "${TMPDIR:-/tmp}/sops-vault-template-keys.XXXXXX")"
boundary_root="$(mktemp -d "${TMPDIR:-/tmp}/sops-vault-template-boundary.XXXXXX")"
trap 'rm -rf "$test_root" "$key_root" "$boundary_root"' EXIT

# These fixtures must fail before SOPS or directory creation, without keys.
mkdir "$boundary_root/bin"
cat > "$boundary_root/bin/sops" <<'EOF'
#!/usr/bin/env bash
touch "$SOPS_VAULT_TEST_CALLED"
exit 9
EOF
chmod +x "$boundary_root/bin/sops"
for operation in new edit; do
  for boundary in parent missing-parent dangling-parent leaf dangling-leaf secrets-root; do
    fixture="$boundary_root/$operation-$boundary"
    mkdir -p "$fixture/repo/secrets/nested" "$fixture/outside"
    cp -R scripts "$fixture/repo/"
    printf 'creation_rules: []\n' > "$fixture/repo/.sops.yaml"
    (
      cd "$fixture/repo"
      git init -q -b main
      logical_path=nested/example
      if [ "$boundary" = missing-parent ]; then
        logical_path=nested/missing/example
        mkdir secrets/nested/missing
      fi
      payload="secrets/$logical_path.sops.env"
      touch "$payload"
      git add "$payload"
      rm -rf secrets
      mkdir -p secrets/nested
      case "$boundary" in
        parent|missing-parent)
          rmdir secrets/nested
          ln -s "$fixture/outside" secrets/nested
          if [ "$operation" = edit ]; then
            touch "$fixture/outside/example.sops.env"
          fi
          ;;
        dangling-parent)
          rmdir secrets/nested
          ln -s "$fixture/outside/missing" secrets/nested
          ;;
        leaf|dangling-leaf)
          if [ "$boundary" = leaf ]; then
            touch "$fixture/outside/example.sops.env"
          fi
          ln -s "$fixture/outside/example.sops.env" "$payload"
          ;;
        secrets-root)
          rm -rf secrets
          ln -s "$fixture/outside" secrets
          ;;
      esac
      if PATH="$boundary_root/bin:$PATH" \
        SOPS_VAULT_TEST_CALLED="$fixture/called" \
        "./scripts/secret-$operation.sh" "$logical_path" >"$fixture/output" 2>&1; then
        fail "secret-$operation accepted $boundary"
      fi
      [ ! -e "$fixture/called" ] || fail "secret-$operation invoked SOPS for $boundary"
      [ ! -e "$fixture/outside/missing" ] || fail "secret-$operation created an outside directory"
      grep -Eq 'outside this vault|must not be a symbolic link|parent is not a directory' "$fixture/output" \
        || fail "secret-$operation did not explain $boundary rejection"
    )
  done
done

cp -R AGENTS.md CLAUDE.md README.md LICENSE mise.toml recipients.yaml \
  .sops.yaml.example scripts docs tests "$test_root/"
cd "$test_root"
git init -q -b main

recovery_key="$key_root/recovery.agekey"
deployment_key="$key_root/deployment.agekey"
combined_keys="$key_root/keys.txt"
age-keygen -o "$recovery_key" >/dev/null 2>&1
age-keygen -o "$deployment_key" >/dev/null 2>&1
recovery_recipient="$(age-keygen -y "$recovery_key")"
deployment_recipient="$(age-keygen -y "$deployment_key")"
cat "$recovery_key" "$deployment_key" > "$combined_keys"
chmod 600 "$combined_keys"

cat > recipients.yaml <<EOF
version: 1
recovery:
  - name: recovery
    recipient: $recovery_recipient
deployments:
  - name: test@local
    recipient: $deployment_recipient
EOF

cat > .sops.yaml <<EOF
creation_rules:
  - path_regex: ^secrets/.*\\.sops\\.(yaml|json|env)$
    age: >-
      $recovery_recipient,
      $deployment_recipient
EOF

git add .

if ./scripts/secret-new.sh ../escape >/dev/null 2>&1; then
  fail "secret-new accepted path traversal"
fi
if ./scripts/secret-new.sh --format text integrations/example >/dev/null 2>&1; then
  fail "secret-new accepted unsupported format"
fi

SOPS_AGE_KEY_FILE="$combined_keys" \
SOPS_VAULT_TEST_VALUE=created \
EDITOR="$repo_root/tests/fixture-editor.sh" \
  mise run secret-new -- integrations/example >/dev/null

payload="secrets/integrations/example.sops.env"
[ -f "$payload" ] || fail "secret-new did not create payload"
sops filestatus "$payload" | grep -Eq '"encrypted"[[:space:]]*:[[:space:]]*true' \
  || fail "secret-new created plaintext"

git add "$payload"
if ./scripts/secret-new.sh integrations/example >/dev/null 2>&1; then
  fail "secret-new replaced an existing payload"
fi
if ./scripts/secret-edit.sh integrations/missing >/dev/null 2>&1; then
  fail "secret-edit accepted a missing payload"
fi

wrapped_output="$test_root/wrapped-output.txt"
if SOPS_AGE_KEY_FILE="$combined_keys" \
  SOPS_VAULT_TEST_VALUE="'wrapped'" \
  EDITOR="$repo_root/tests/fixture-json-editor.sh" \
    ./scripts/secret-new.sh --format json integrations/quoted >"$wrapped_output" 2>&1; then
  fail "secret-new accepted a literal quote-wrapped value"
fi
grep -Fq 'literal quote-wrapped value' "$wrapped_output" \
  || fail "secret-new did not explain quote-wrapped rejection"
wrapped_verify_output="$test_root/wrapped-verify-output.txt"
if SOPS_AGE_KEY_FILE="$combined_keys" \
  ./scripts/verify.sh >"$wrapped_verify_output" 2>&1; then
  fail "verify accepted a directly written quote-wrapped payload"
fi
grep -Fq 'literal quote-wrapped value' "$wrapped_verify_output" \
  || fail "verify did not explain quote-wrapped rejection"
rm "$wrapped_output" "$wrapped_verify_output" \
  secrets/integrations/quoted.sops.json

SOPS_AGE_KEY_FILE="$combined_keys" \
SOPS_VAULT_TEST_VALUE=updated \
EDITOR="$repo_root/tests/fixture-editor.sh" \
  mise run secret-edit -- integrations/example >/dev/null

SOPS_AGE_KEY_FILE="$combined_keys" sops decrypt --output-type dotenv "$payload" \
  | grep -Fxq 'EXAMPLE_TOKEN=updated' \
  || fail "secret-edit did not update payload"
SOPS_AGE_KEY_FILE="$combined_keys" mise run secret-audit >/dev/null
SOPS_AGE_KEY_FILE="$combined_keys" \
  ./scripts/validate-secret.sh "$test_root/$payload" >/dev/null

outside_output="$test_root/outside-output.txt"
if ./scripts/validate-secret.sh "$key_root/outside.sops.env" >"$outside_output" 2>&1; then
  fail "validation accepted a path outside the vault"
fi
grep -Fq 'secret payload path is outside this vault' "$outside_output" \
  || fail "outside-vault validation did not explain the path boundary"
rm "$outside_output"

if ./scripts/validate-secret.sh secrets/../outside.sops.env >/dev/null 2>&1; then
  fail "validation accepted relative traversal outside the vault"
fi

printf 'EXAMPLE_TOKEN=plaintext\n' > secrets/integrations/plain.env
if ./scripts/verify.sh >/dev/null 2>&1; then
  fail "verify accepted plaintext under secrets"
fi
rm secrets/integrations/plain.env

SOPS_AGE_KEY_FILE="$combined_keys" ./scripts/verify.sh >/dev/null
printf 'ok secret path validation, semantic rejection, create, edit, encryption, and plaintext rejection\n'
