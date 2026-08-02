# SOPS Vault Template

A small GitHub template for capability-scoped SOPS and age secret repositories.
Generated vaults own their copied policy, scripts, and documentation; this repo
is not a package or runtime dependency.

## Create a Vault

Create a repository from [this template](https://github.com/new?template_name=sops-vault-template&template_owner=uinaf), then clone it.

Install `mise`, `sops`, `age`, and `shellcheck`. Configure the vault before
adding secrets:

1. Add the public recovery and deployment recipients to `recipients.yaml`.
2. Copy `.sops.yaml.example` to `.sops.yaml`.
3. Replace the example placeholders with those public recipients.
4. Run `mise run verify`.

Private age identities belong in an approved recovery system and owner-only on
their deployments. Only public recipients belong in the repository.

## Use the Vault

Create an environment payload:

```bash
mise run secret-new -- integrations/example
```

Choose JSON or YAML when the consumer requires it:

```bash
mise run secret-new -- --format json identities/operator
mise run secret-new -- --format yaml deploy/service
```

Edit an existing payload and run the full guardrail:

```bash
mise run secret-edit -- integrations/example
mise run verify
```

Commands accept logical paths below `secrets/`; they never accept secret values
as arguments. [Vault operations](./docs/operations.md) covers payloads,
recipients, consumption, rotation, and recovery.

## Template Contract

- `recipients.yaml` is the public recipient registry.
- `.sops.yaml` is the initialized path-to-recipient policy.
- `secrets/` contains only `.sops.env`, `.sops.json`, or `.sops.yaml`
  ciphertext.
- `scripts/verify.sh` accepts the untouched template state or a completely
  initialized vault and rejects partial configuration.
- `CLAUDE.md` points to the canonical `AGENTS.md` guidance.

## License

Released under the [MIT License](./LICENSE).
