-- Migration: 001_create_users
-- Direction: up

CREATE TABLE users (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  apple_sub  TEXT        UNIQUE NOT NULL,
  email      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Direction: down
-- DROP TABLE users;
