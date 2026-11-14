# Instructions for alhambra_plugin_install_sqlite

- Keep SQLite-specific persistence in this optional adapter package; do not add
  SQLite dependencies to plugin API or runtime contracts.
- Use explicit schema versions and transactional migrations.
- Persist current state and append-only history in the same transaction.
- Use BEGIN IMMEDIATE for cross-connection writes and CAS claims.
- Keep approval-ID uniqueness across retained history, not just current rows.
- Treat only committed, rolledBack and failed as terminal; ambiguous recovery
  states must remain queryable.
- Do not claim filesystem atomicity, worker fencing, or exactly-once effects.
- Test reopen durability and competing independent database connections.
