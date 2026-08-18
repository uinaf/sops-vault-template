# Vault Operations

Generated vaults store SOPS ciphertext and public age recipients. Private age
identities stay owner-only on approved deployments and in the vault owner's
recovery system.

## Configure

Add at least one recovery recipient and one deployment recipient to
`recipients.yaml`. Copy `.sops.yaml.example` to `.sops.yaml`, replace its
placeholders, and scope each creation rule to the payloads its consumers need.

Run the guardrail before adding ciphertext:

```bash
mise run verify
```

The verifier rejects partial configuration, recipient-policy drift, plaintext
under `secrets/`, private-key material, and invalid SOPS payloads. It decrypts
and validates changed or newly added payloads before accepting a local change;
a clean CI checkout does not need an age identity.

## Create

Create an environment payload by logical path:

```bash
mise run secret-new -- integrations/example
```

Use `--format json` or `--format yaml` when required. The command validates the
logical path, refuses existing or ambiguous payloads, invokes SOPS directly,
and runs the repository guardrail after saving.

Keep unrelated consumers in separate payloads even when they currently use the
same provider credential.

## Edit

Edit an existing payload through SOPS:

```bash
mise run secret-edit -- integrations/example
```

The command resolves exactly one supported ciphertext file, invokes SOPS,
decrypts the result in memory for semantic validation, and then runs the
repository guardrail. Secret values must enter through the editor or another
process boundary, never command arguments, chat, logs, or commits.

## Validate

`secret-new` and `secret-edit` reject empty, non-string, and literal
quote-wrapped values before reporting success. Validate every payload available
to the active age identity with:

```bash
mise run secret-audit
```

Validation accepts logical ciphertext paths and absolute paths inside this
repository, canonicalizing both to `secrets/...` before any repository policy
lookup. Paths outside the vault are rejected before decryption.

For payload-specific contracts, add executable
`scripts/validate-secret-policy.sh`.

- It receives the ciphertext path as its only argument and decrypted JSON on
  standard input.
- Validate exact keys and provider formats without printing values.
- Keep this hook repository-owned; generated vaults do not depend on future
  template releases.

## Consume

Prefer a process boundary so plaintext exists only in the consumer process:

```bash
sops exec-env --same-process secrets/integrations/example.sops.env \
  './path/to/command'
```

Use `sops exec-file` when a program requires a file path. A consumer-owned
renderer may write an owner-only local file when its runtime requires one; that
renderer owns permissions and cleanup.

## Add a Recipient

1. Generate a dedicated age identity outside the repository with owner-only
   permissions.
2. Back up the private identity in the approved recovery system.
3. Add only its public recipient and stable deployment metadata to
   `recipients.yaml`.
4. Add it only to the matching `.sops.yaml` path rules.
5. Run `sops updatekeys <payload>` for every affected payload.
6. Verify decryption with the new identity and rejection with an unrelated
   identity.
7. Run `mise run verify`.

Repository access grants ciphertext access; SOPS recipients grant decryption.
Both are required.

## Remove a Recipient

Remove the public recipient from the registry and affected SOPS rules, then
update the affected payload keys. Rotate every underlying secret the recipient
could decrypt because old Git revisions remain decryptable with the retired
private identity.

## Recover

Recovery is a human operation. Restore the backed-up age identity to an
owner-only temporary or standard SOPS identity path, set mode `0600`, and point
`SOPS_AGE_KEY_FILE` at it.

Verify access without printing plaintext:

```bash
SOPS_AGE_KEY_FILE=/owner-only/path/to/age-identity \
  sops decrypt --output /dev/null secrets/integrations/example.sops.env
```

Remove temporary recovery material after the operation. Unattended consumers
use deployment identities instead of recovery identities.
