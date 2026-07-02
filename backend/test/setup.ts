import 'dotenv/config';
import Fastify from 'fastify';
import corsPlugin from '../src/plugins/cors.js';
import dbPlugin from '../src/plugins/db.js';
import errorHandlerPlugin from '../src/plugins/error.js';
import jwtPlugin from '../src/plugins/jwt.js';
import authRoutes from '../src/routes/auth/auth.js';
import meRoutes from '../src/routes/me.js';
import sessionRoutes from '../src/routes/sessions.js';

export async function buildApp() {
  process.env.DATABASE_URL = process.env.DATABASE_URL_TEST ?? '';

  const app = Fastify({ logger: false });

  await app.register(corsPlugin);
  await app.register(dbPlugin);
  await app.register(jwtPlugin);
  await app.register(errorHandlerPlugin);
  await app.register(authRoutes, { prefix: '/v1/auth' });
  await app.register(sessionRoutes, { prefix: '/v1/sessions' });
  await app.register(meRoutes, { prefix: '/v1/me' });

  await app.ready();
  return app;
}

export async function seedUserWithToken(app: Awaited<ReturnType<typeof buildApp>>) {
  const email = `test-${crypto.randomUUID()}@example.com`;
  const [user] = await app.db`
    INSERT INTO users (email, password_hash)
    VALUES (${email}, 'hashed_password_not_used_in_tests')
    RETURNING *
  `;
  if (!user) throw new Error('Seed user failed');
  const token = app.jwt.sign({ sub: user.id });
  return { user, token };
}

/** Cleans all tables between tests */
export async function cleanDb(app: Awaited<ReturnType<typeof buildApp>>) {
  await app.db`DELETE FROM refresh_tokens`;
  await app.db`DELETE FROM work_sessions`;
  await app.db`DELETE FROM users`;
}
