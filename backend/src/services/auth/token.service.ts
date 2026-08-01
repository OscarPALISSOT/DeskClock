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

function parseDurationToSeconds(input: string): number {
  const match = input.match(/^(\d+)(s|m|h|d)$/);
  if (!match) {
    throw new Error(`Invalid duration format: "${input}". Expected e.g. "1h", "30d", "45m".`);
  }
  const value = Number(match[1]);
  const unit = match[2] as 's' | 'm' | 'h' | 'd';
  const multipliers = { s: 1, m: 60, h: 3600, d: 86400 };
  return value * multipliers[unit];
}

// Tokens generation
export async function createTokenPair(
  db: Sql,
  userId: string,
  jwtSign: (payload: { sub: string }) => string
): Promise<TokenPair> {
  const jwtExpiresIn = process.env.JWT_EXPIRES_IN ?? '1h';
  const refreshExpiresIn = process.env.REFRESH_TOKEN_EXPIRES_IN ?? '30d';

  // Access token — expiresIn applied via the fastify-jwt plugin's sign defaults, signed by JWT secret
  const access_token = jwtSign({ sub: userId });

  // Refresh token
  const rawToken = randomBytes(64).toString('hex');
  const tokenHash = createHash('sha256').update(rawToken).digest('hex');

  const expiresAt = new Date(Date.now() + parseDurationToSeconds(refreshExpiresIn) * 1000);

  await db`
    INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
    VALUES (${userId}, ${tokenHash}, ${expiresAt.toISOString()})
  `;

  return {
    access_token,
    refresh_token: rawToken,
    expires_in: parseDurationToSeconds(jwtExpiresIn),
  };
}

// Refresh token rotation
export async function rotateRefreshToken(
  db: Sql,
  rawToken: string,
  jwtSign: (payload: { sub: string }) => string
): Promise<TokenPair> {
  const tokenHash = createHash('sha256').update(rawToken).digest('hex');

  // Opportunistic cleanup: every rotation is a natural occasion to purge
  // expired refresh tokens, without needing a dedicated cron job.
  await db`DELETE FROM refresh_tokens WHERE expires_at < now()`;

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
