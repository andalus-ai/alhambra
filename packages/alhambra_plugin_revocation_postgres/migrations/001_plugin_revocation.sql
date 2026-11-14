CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_schema (
  version INTEGER PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_execution (
  idempotency_key TEXT PRIMARY KEY,
  operation_id TEXT NOT NULL,
  plugin_id TEXT NOT NULL,
  provider_owner_id TEXT NOT NULL,
  action TEXT NOT NULL,
  status TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  detail TEXT
);

CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_journal (
  idempotency_key TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
  operation_id TEXT NOT NULL,
  plugin_id TEXT NOT NULL,
  provider_owner_id TEXT NOT NULL,
  action TEXT NOT NULL,
  status TEXT NOT NULL,
  revision BIGINT NOT NULL CHECK (revision >= 1),
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  correlation_id TEXT,
  detail TEXT
);

CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_outbox (
  event_id TEXT PRIMARY KEY,
  idempotency_key TEXT NOT NULL UNIQUE,
  operation_id TEXT NOT NULL,
  plugin_id TEXT NOT NULL,
  provider_owner_id TEXT NOT NULL,
  action TEXT NOT NULL,
  outcome TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  detail TEXT,
  state TEXT NOT NULL CHECK (state IN ('pending', 'leased', 'delivered', 'deadLetter')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at TIMESTAMPTZ NOT NULL,
  lease_owner TEXT,
  lease_token TEXT,
  lease_until TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  last_error_code TEXT
);

CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_outbox_due
  ON alhambra_plugin_revocation_outbox (next_attempt_at, occurred_at, event_id)
  WHERE state = 'pending';

CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_outbox_expired_lease
  ON alhambra_plugin_revocation_outbox (lease_until, occurred_at, event_id)
  WHERE state = 'leased';
