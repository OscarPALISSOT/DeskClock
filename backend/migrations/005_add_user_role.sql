-- Migration: 005_add_user_role
-- Direction: up
ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user';
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'tester'));

-- Direction: down
-- ALTER TABLE users DROP CONSTRAINT users_role_check;
-- ALTER TABLE users DROP COLUMN role;