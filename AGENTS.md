# Agent Guide

This repository is a reusable SOPS vault template. Keep it generic and safe to
instantiate in any organization.

## Start

- Read [Vault operations](./docs/operations.md) before changing commands or
  policy.
- Run `mise run verify` before committing.

## Boundaries

- Never add real recipients, ciphertext, credentials, private identities,
  password-manager references, organization names, machine names, or account
  details to this template.
- Keep secret values out of command arguments, logs, tests, docs, and fixtures.
- Commands accept logical payload paths only. Do not add flags that accept
  secret values.
- Fail closed when configuration is incomplete, a payload path is ambiguous,
  or tracked material crosses the ciphertext boundary.
- Keep generated vaults independent. This template is scaffolding, not a
  runtime dependency or package.

## Change Workflow

1. Preserve both supported states: an uninitialized template and an initialized
   vault with configured recipients.
2. Add command behavior to `scripts/` and cover it in `tests/commands.sh`.
3. Keep `README.md` task-oriented and put operational detail in
   `docs/operations.md`.
4. Run `mise run verify`.
