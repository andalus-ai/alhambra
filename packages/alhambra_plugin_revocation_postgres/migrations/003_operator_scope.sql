ALTER TABLE alhambra_plugin_revocation_operator_action
  ADD COLUMN IF NOT EXISTS scope_id TEXT NOT NULL DEFAULT 'default';

INSERT INTO alhambra_plugin_revocation_schema (version)
VALUES (3) ON CONFLICT (version) DO NOTHING;
