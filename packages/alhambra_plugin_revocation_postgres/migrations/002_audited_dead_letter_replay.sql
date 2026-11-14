ALTER TABLE alhambra_plugin_revocation_outbox
  ADD COLUMN IF NOT EXISTS replay_of_event_id TEXT;

ALTER TABLE alhambra_plugin_revocation_outbox
  ADD COLUMN IF NOT EXISTS replay_generation INTEGER NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_alhambra_revocation_replay_generation
  ON alhambra_plugin_revocation_outbox (replay_of_event_id, replay_generation)
  WHERE replay_generation > 0;

CREATE TABLE IF NOT EXISTS alhambra_plugin_revocation_operator_action (
  action_id TEXT PRIMARY KEY,
  actor_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  approval_reference TEXT NOT NULL,
  target_event_id TEXT NOT NULL
    REFERENCES alhambra_plugin_revocation_outbox(event_id),
  replay_event_id TEXT NOT NULL UNIQUE
    REFERENCES alhambra_plugin_revocation_outbox(event_id),
  replay_generation INTEGER NOT NULL CHECK (replay_generation >= 1),
  occurred_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_alhambra_revocation_operator_target
  ON alhambra_plugin_revocation_operator_action (target_event_id, replay_generation);

INSERT INTO alhambra_plugin_revocation_schema (version)
VALUES (2) ON CONFLICT (version) DO NOTHING;
