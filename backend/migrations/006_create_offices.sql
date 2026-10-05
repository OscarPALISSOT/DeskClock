-- Migration: 006_create_offices
-- Direction: up

CREATE TABLE offices (
  id         UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID             NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label      TEXT             NOT NULL,
  latitude   DOUBLE PRECISION NOT NULL,
  longitude  DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ      NOT NULL DEFAULT now()
);

-- Temporary constraint: one office per user until multi-office (premium) support
-- is implemented. Drop this in the future migration that introduces it.
ALTER TABLE offices ADD CONSTRAINT offices_user_id_unique UNIQUE (user_id);

-- Direction: down
-- ALTER TABLE offices DROP CONSTRAINT offices_user_id_unique;
-- DROP TABLE offices;