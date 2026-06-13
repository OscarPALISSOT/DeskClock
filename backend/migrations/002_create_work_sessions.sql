-- Migration: 002_create_work_sessions
-- Direction: up

CREATE TABLE work_sessions (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at   TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_work_sessions_user_started
  ON work_sessions (user_id, started_at DESC);

-- Direction: down
-- DROP INDEX idx_work_sessions_user_started;
-- DROP TABLE work_sessions;
