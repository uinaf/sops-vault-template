# Vault operations

## Payload contracts

To enforce exact keys and provider formats, add an executable
`scripts/validate-secret-policy.sh`. It receives the ciphertext path as its
only argument and decrypted JSON on standard input, and must never print
values.

To declare contracts as data instead, define `formats` and `contracts` in
`scripts/validate-secret-policy.jq` (schema in
[`scripts/policy-engine.jq`](../scripts/policy-engine.jq)) and run the engine
from the hook:

```bash
jq -r -L scripts --arg secret_file "$secret_file" \
  'include "validate-secret-policy"; include "policy-engine";
   validate(contracts; formats; $secret_file)'
```

## Consume

Keep plaintext inside the consumer process:

```bash
sops exec-env --same-process secrets/integrations/example.sops.env \
  './path/to/command'
```

Use `sops exec-file` when a program needs a file path. A renderer that writes
an owner-only file owns its permissions and cleanup.

## Add a recipient

Keep recovery item references outside the vault.

1. Generate a dedicated age identity outside the repository, owner-only.
2. Back up the private identity in your recovery system.
3. Add only its public recipient and deployment metadata to
   `recipients.yaml`, and add it to the matching `.sops.yaml` rules.
4. Run `sops updatekeys <payload>` for every affected payload.
5. Check that the new identity decrypts and an unrelated one does not.
6. Run `mise run verify`.

## Remove a recipient

Remove it from `recipients.yaml` and the `.sops.yaml` rules, then run
`sops updatekeys` on the affected payloads. Old Git revisions stay decryptable
with the retired identity, so rotate every secret it could read.

## Recover

Recovery is a human operation; unattended consumers use deployment identities.
Restore the backed-up age identity to an owner-only path with mode `0600`,
then check access without printing plaintext:

```bash
SOPS_AGE_KEY_FILE=/owner-only/path/to/age-identity \
  sops decrypt --output /dev/null secrets/integrations/example.sops.env
```

Remove temporary recovery material afterwards.
