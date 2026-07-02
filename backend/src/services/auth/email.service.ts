import bcrypt from 'bcrypt';
import type { Sql } from 'postgres';

interface UserRow {
  id: string;
  email: string;
  password_hash: string;
}

interface TokenPair {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

export async function registerUser(db: Sql, email: string, password: string): Promise<UserRow> {
  const passwordHash = await bcrypt.hash(password, 10);

  const [user] = await db<UserRow[]>`
    INSERT INTO users (email, password_hash)
    VALUES (${email}, ${passwordHash})
    RETURNING *
  `.catch((err) => {
    throw Object.assign(new Error('Email already in use'), { statusCode: 409 });
  });

  if (!user) throw new Error('Insert user failed');

  return user;
}

export async function loginUser(db: Sql, email: string, password: string): Promise<UserRow> {
  const [user] = await db<UserRow[]>`
    SELECT * FROM users WHERE email = ${email}
  `;

  if (!user) {
    throw Object.assign(new Error('Invalid credentials'), { statusCode: 401 });
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    throw Object.assign(new Error('Invalid credentials'), { statusCode: 401 });
  }

  return user;
}
