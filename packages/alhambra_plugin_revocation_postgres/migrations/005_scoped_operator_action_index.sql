-- Add the scope-first ordering index used by operator-action keyset pages.
CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_operator_scope_occurred
  ON alhambra_plugin_revocation_operator_action(scope_id, occurred_at DESC, action_id DESC);

INSERT INTO alhambra_plugin_revocation_schema (version)
VALUES (5) ON CONFLICT (version) DO NOTHING;
