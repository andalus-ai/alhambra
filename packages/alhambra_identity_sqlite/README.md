# Alhambra Identity SQLite

SQLite persistence adapters for the infrastructure-free `alhambra_identity` contracts.

## Included

- `SqliteIdentityStore`: implements `MembershipRepository`, `RoleRepository`, and `AuthorizationAuditSink`.
- Schema initialization for membership, role, and authorization audit tables.
- Tenant membership lookup and unique user/organization membership constraint.
- Role permission persistence as canonical `resource:action` keys.
- Append-only-by-API authorization decision recording.

## Usage

```dart
import 'package:alhambra_data_sqlite/alhambra_data_sqlite.dart';
import 'package:alhambra_identity/alhambra_identity.dart';
import 'package:alhambra_identity_sqlite/alhambra_identity_sqlite.dart';

final database = Sqlite3Database('/var/lib/app/identity.sqlite');
await database.open();

final identityStore = SqliteIdentityStore(database);
await identityStore.initialize();

final authorization = DefaultAuthorizationService(
  membershipRepository: identityStore.memberships,
  roleRepository: identityStore.roles,
  auditSink: identityStore.auditSink,
  requireAudit: true,
);
```

The host owns database lifecycle, backup, encryption-at-rest, file permissions, migrations, and retention. The database must be configured for the durability level required by the application. Do not use a local SQLite file as a shared multi-instance authorization database without a deliberate deployment design.

## Security notes

- Keep the database writable only by the trusted host process.
- Do not expose the audit table to application users or ordinary operators.
- Add host-specific retention, export, monitoring, and tamper-evidence controls.
- The package does not implement user authentication, organization persistence, or remote replication.
- Schema creation is idempotent; subsequent schema changes belong in explicit host migrations.
