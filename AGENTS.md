# Agent Guide

This repository is a reusable SOPS vault template. Keep it generic and safe to
instantiate in any organization.

## Start

- Read [Vault operations](./docs/operations.md) before changing commands or
  policy.
- Run `mise run verify` before committing.

## Boundaries

- Use placeholders for recipients, identities, organizations, machines,
  accounts, and password-manager items. This template holds no ciphertext or
  credentials.
- Secret values enter through the editor or another process boundary; keep
  them out of command arguments, logs, tests, docs, and fixtures.
- Create and edit commands take logical payload paths. Validation may
  canonicalize an absolute ciphertext path inside this repository.
- Fail closed when configuration is incomplete, a payload path is ambiguous,
  or tracked material crosses the ciphertext boundary.
- Generated vaults own their copies. This template is scaffolding, not a
  runtime dependency or package.

## Change Workflow

1. Preserve both supported states: an uninitialized template and an initialized
   vault with configured recipients.
2. Add command behavior to `scripts/` and cover it in `tests/commands.sh`.
3. Keep `README.md` task-oriented and put operational detail in
   `docs/operations.md`.
