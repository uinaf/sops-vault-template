def path_label($path): $path | map(tostring) | join(".");
def quote_wrapped:
  type == "string" and length >= 1 and
  ((startswith("'") and endswith("'")) or
   (startswith("\"") and endswith("\"")));

paths(scalars) as $path
| getpath($path) as $value
| if ($value | type) != "string" then
    "\(path_label($path)): expected a string value"
  elif ($value | length) == 0 then
    "\(path_label($path)): empty value"
  elif ($value | quote_wrapped) then
    "\(path_label($path)): literal quote-wrapped value"
  else empty end
