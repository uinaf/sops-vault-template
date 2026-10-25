![sops-vault-template — reusable SOPS and age vault scaffold with fail-closed mise commands.](https://uinaf.dev/og/banner/sops-vault-template.png)

# uinaf/sops-vault-template

GitHub template for capability-scoped SOPS and age secret repositories.
Each generated vault owns its copy of the scripts and docs; nothing pulls
updates from this repository.

## Create a vault

Create a repository from
[this template](https://github.com/new?template_name=sops-vault-template&template_owner=uinaf),
clone it, and install `mise`, `sops`, `age`, `jq`, and `shellcheck`. Then:

1. Add at least one recovery and one deployment public recipient to
   `recipients.yaml`.
2. Copy `.sops.yaml.example` to `.sops.yaml`, replace its placeholders with
   those recipients, and scope each rule to the payloads its consumers need.
3. Run `mise run verify`.

Private age identities never enter the repository: back them up in your
recovery system and keep runtime copies owner-only on their deployments.

## Use the vault

Commands take logical paths below `secrets/`; values enter through the editor.

```bash
mise run secret-new -- integrations/example                # dotenv
mise run secret-new -- --format json identities/operator   # or yaml
mise run secret-edit -- integrations/example
mise run secret-audit   # every payload the active age identity can decrypt
mise run verify
```

Keep unrelated consumers in separate payloads, even when they share a provider
credential today.

[Vault operations](./docs/operations.md) covers payload contracts,
consumption, recipients, and recovery.

## License

Released under the [MIT License](./LICENSE).
