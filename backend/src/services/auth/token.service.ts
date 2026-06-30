import { createHash, randomBytes } from 'node:crypto';
import type { Sql } from 'postgres';

interface TokenPair {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

interface RefreshTokenRow {
  id: string;
  user_id: string;
  expires_at: string;
}

// Tokens generation
export async function createTokenPair(
  db: Sql,
  userId: string,
  jwtSign: (payload: { sub: string }) => string
): Promise<TokenPair> {
  const expiresIn = 60 * 60; // 1h

  // Access token — signed by JWT secret
  const access_token = jwtSign({ sub: userId });

  // Refresh token
  const rawToken = randomBytes(64).toString('hex');
  const tokenHash = createHash('sha256').update(rawToken).digest('hex');

  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

  await db`
    INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
    VALUES (${userId}, ${tokenHash}, ${expiresAt.toISOString()})
  `;

  return {
    access_token,
    refresh_token: rawToken,
    expires_in: expiresIn,
  };
}

// Refresh token rotation
export async function rotateRefreshToken(
  db: Sql,
  rawToken: string,
  jwtSign: (payload: { sub: string }) => string
): Promise<TokenPair> {
  const tokenHash = createHash('sha256').update(rawToken).digest('hex');

  const [existing] = await db<RefreshTokenRow[]>`
    DELETE FROM refresh_tokens
    WHERE token_hash = ${tokenHash}
      AND expires_at > now()
    RETURNING *
  `;

  if (!existing) {
    throw Object.assign(new Error('Invalid or expired refresh token'), { statusCode: 401 });
  }

  return createTokenPair(db, existing.user_id, jwtSign);
}
