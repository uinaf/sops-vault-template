# Agent Guide

Reusable SOPS vault template. Keep it generic and safe to instantiate in any
organization.

## Boundaries

- Use placeholders for recipients, identities, organizations, machines,
  accounts, and password-manager items. The template holds no ciphertext or
  credentials.
- Keep secret values out of command arguments, logs, tests, docs, and
  fixtures.
- Fail closed when configuration is incomplete, a payload path is ambiguous,
  or tracked material crosses the ciphertext boundary.
- Keep both states working: the untouched template and a fully initialized
  vault. `scripts/verify.sh` rejects anything in between.

## Change workflow

1. Add command behavior to `scripts/` and cover it in `tests/commands.sh`.
2. Run `mise run verify` before committing.
3. Keep `README.md` to setup and daily commands; procedures go in
   [Vault operations](./docs/operations.md).
