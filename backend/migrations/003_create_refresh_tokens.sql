-- Migration: 003_create_refresh_tokens
-- Direction: up

CREATE TABLE refresh_tokens (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT        NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_refresh_tokens_user
  ON refresh_tokens (user_id);

-- Direction: down
-- DROP INDEX idx_refresh_tokens_user;
-- DROP TABLE refresh_tokens;
