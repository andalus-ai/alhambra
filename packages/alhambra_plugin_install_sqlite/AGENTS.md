# Instructions for alhambra_plugin_install_sqlite

- Keep SQLite-specific persistence in this optional adapter package; do not add
  SQLite dependencies to plugin API or runtime contracts.
- Use explicit schema versions and transactional migrations.
- Persist current state and append-only history in the same transaction.
- Use BEGIN IMMEDIATE for cross-connection writes and CAS claims.
- Keep approval-ID uniqueness across retained history, not just current rows.
- Treat only committed, rolledBack and failed as terminal; ambiguous recovery
  states must remain queryable.
- Enforce journal fencing tokens atomically on writes and CAS after fence registration.
- Keep lease counters durable and monotonic across process restarts.
- Do not claim filesystem atomicity, distributed transactions, or exactly-once effects.
- Test reopen durability and competing independent database connections.
- Installed-plugin records must preserve stable operation ownership separately from the current fencing token; recovery takeover may compensate only records owned by that same operation.
- Fenced create/remove operations must validate the exact registered token in the same SQLite transaction as the record mutation.
- Unfenced compatibility methods must never overwrite or delete transaction-owned installed records.
- Keep the installed-record schema additive and do not change the shared database `PRAGMA user_version`.
