# Generic semantic-policy engine for vault payload contracts.
#
# A generated vault defines two data tables in scripts/validate-secret-policy.jq
# and runs `validate` against decrypted JSON:
#
#   formats:   name -> {pattern, description, example, multiline?}
#   contracts: ciphertext path -> {keys: {KEY: format-name | {format, example}},
#                                  distinct?: [[KEY, ...], ...]}
#
# Single-line values get multiline and surrounding-whitespace checks unless the
# format sets multiline; multiline formats must anchor with \A and \z.
# `contract_fixtures` derives a valid payload per contract from the format
# examples, so tests never restate key inventories or value formats.

def _keyspec: if type == "string" then {format: .} else . end;

def _check_key($formats; $key; $spec; $value):
  ($spec | _keyspec) as $s
  | $formats[$s.format] as $format
  | if $format == null then "\($key): unregistered value format \($s.format)"
    else
      (if ($format.multiline // false) then empty
       elif ($value | contains("\n")) then "\($key): unexpected multiline value"
       elif ($value | test("^[[:space:]]|[[:space:]]$")) then
         "\($key): leading or trailing whitespace"
       else empty end),
      (if ($value | test($format.pattern)) then empty
       else "\($key): expected \($format.description)" end)
    end;

def validate($contracts; $formats; $secret_file):
  $contracts[$secret_file] as $contract
  | if $contract == null then
      "no registered semantic contract for \($secret_file); add its exact key and format checks to scripts/validate-secret-policy.jq"
    elif (keys | sort) != ($contract.keys | keys | sort) then
      "key inventory does not match the registered payload contract"
    else
      . as $payload
      | ($contract.keys | to_entries[]
         | _check_key($formats; .key; .value; $payload[.key])),
        (($contract.distinct // [])[] as $group
         | if ([$group[] as $key | $payload[$key]] | unique | length)
             != ($group | length) then
             "values must all differ: \($group | join(", "))"
           else empty end)
    end;

def contract_fixtures($contracts; $formats):
  $contracts
  | with_entries(.value |= (
      .keys | with_entries(.value |= (
        _keyspec as $s | ($s.example // $formats[$s.format].example)
      ))
    ));
