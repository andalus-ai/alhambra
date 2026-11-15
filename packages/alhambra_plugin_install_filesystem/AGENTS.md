# Instructions for alhambra_plugin_install_filesystem

- Keep local filesystem behavior in this optional adapter package.
- Every mutating operation must acquire the per-operation exclusive lock and
  validate the current fencing token before touching staging or destination.
- Persist operation fencing state outside plugin payloads; retain the reserved ownership marker in the installed tree for crash reconciliation.
- Reject symlinks, path traversal, absolute paths and reserved adapter metadata.
- Promotion must never overwrite an existing destination.
- Ambiguous lock ownership must fail closed; never delete a lock merely because
  it appears old.
- Recovery inspection is read-only.
- Do not claim distributed transactions or exactly-once effects.
- Run package tests, formatting and analysis before production adoption.
