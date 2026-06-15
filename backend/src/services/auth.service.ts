import { createHash, randomBytes } from 'node:crypto';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import type { Sql } from 'postgres';

interface AppleClaims {
  sub: string;
  email?: string;
  aud: string | string[];
  iss: string;
  exp: number;
}

interface TokenPair {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

interface UserRow {
  id: string;
  apple_sub: string;
  email: string | null;
}

interface RefreshTokenRow {
  id: string;
  user_id: string;
  expires_at: string;
}

// JWKS Apple — automatically cached by jose
const APPLE_JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

// Apple token verification
export async function verifyAppleToken(identityToken: string): Promise<AppleClaims> {
  const clientId = process.env.APPLE_CLIENT_ID;

  if (!clientId) {
    throw new Error('APPLE_CLIENT_ID missing');
  }

  const { payload } = await jwtVerify(identityToken, APPLE_JWKS, {
    issuer: 'https://appleid.apple.com',
    audience: clientId,
  });

  return payload as unknown as AppleClaims;
}

export async function upsertUser(db: Sql, claims: AppleClaims): Promise<UserRow> {
  const [user] = await db<UserRow[]>`
    INSERT INTO users (apple_sub, email)
    VALUES (${claims.sub}, ${claims.email ?? null})
    ON CONFLICT (apple_sub) DO UPDATE
      SET email = COALESCE(EXCLUDED.email, users.email)
    RETURNING *
  `;

  if (!user) throw new Error('upsert user failed');
  return user;
}

// Tokens generation
export async function createTokenPair(
  db: Sql,
  userId: string,
  jwtSign: (payload: { sub: string }) => string
): Promise<TokenPair> {
  const expiresIn = 60 * 60; // 1h

  // Access token — signed by JWT secret
  const access_token = await jwtSign({ sub: userId });

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
