import { createRemoteJWKSet, jwtVerify } from 'jose';
import type { Sql } from 'postgres';

interface AppleClaims {
  sub: string;
  email?: string;
  aud: string | string[];
  iss: string;
  exp: number;
}

interface UserRow {
  id: string;
  apple_sub: string;
  email: string | null;
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
