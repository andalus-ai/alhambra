-- Schema v4: persist host-assigned scope ownership on execution, journal and outbox.
-- Existing rows are explicitly assigned to the compatibility scope "default".
ALTER TABLE alhambra_plugin_revocation_execution
  ADD COLUMN IF NOT EXISTS scope_id TEXT NOT NULL DEFAULT 'default';

ALTER TABLE alhambra_plugin_revocation_journal
  ADD COLUMN IF NOT EXISTS scope_id TEXT NOT NULL DEFAULT 'default';

ALTER TABLE alhambra_plugin_revocation_outbox
  ADD COLUMN IF NOT EXISTS scope_id TEXT NOT NULL DEFAULT 'default';

CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_journal_scope_updated
  ON alhambra_plugin_revocation_journal(scope_id, updated_at DESC, idempotency_key DESC);

CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_outbox_scope_occurred
  ON alhambra_plugin_revocation_outbox(scope_id, occurred_at DESC, event_id DESC);

INSERT INTO alhambra_plugin_revocation_schema (version)
VALUES (4) ON CONFLICT (version) DO NOTHING;
