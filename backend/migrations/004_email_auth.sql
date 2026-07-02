-- Migration: 004_email_auth
-- Direction: up
ALTER TABLE users DROP COLUMN apple_sub;
ALTER TABLE users ADD COLUMN password_hash TEXT NOT NULL DEFAULT '';
ALTER TABLE users ALTER COLUMN password_hash DROP DEFAULT;
ALTER TABLE users ALTER COLUMN email SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);

-- Direction: down
-- ALTER TABLE users DROP CONSTRAINT users_email_unique;
-- ALTER TABLE users ALTER COLUMN email DROP NOT NULL;
-- ALTER TABLE users DROP COLUMN password_hash;
-- ALTER TABLE users ADD COLUMN apple_sub TEXT UNIQUE NOT NULL DEFAULT '';
-- ALTER TABLE users ALTER COLUMN apple_sub DROP DEFAULT;