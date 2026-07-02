import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp, cleanDb } from './setup';

type App = Awaited<ReturnType<typeof buildApp>>;

describe('Auth apple', () => {
  let app: App;

  beforeAll(async () => {
    app = await buildApp();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    await cleanDb(app);
  });

  // POST /auth/email/register
  describe('POST /v1/auth/email/register', () => {
    it('should create a user and return tokens', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/email/register',
        payload: { email: 'new@example.com', password: 'motdepasse123' },
      });
      expect(res.statusCode).toBe(201);
      const body = res.json();
      expect(body).toHaveProperty('access_token');
      expect(body).toHaveProperty('refresh_token');
      expect(body.expires_in).toBe(3600);
    });

    it('should return 409 if email already exists', async () => {
      await app.inject({
        method: 'POST',
        url: '/v1/auth/email/register',
        payload: { email: 'dup@example.com', password: 'motdepasse123' },
      });
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/email/register',
        payload: { email: 'dup@example.com', password: 'autremdp123' },
      });
      expect(res.statusCode).toBe(409);
    });

    it('should return 400 if email is missing', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/email/register',
        payload: { password: 'motdepasse123' },
      });
      expect(res.statusCode).toBe(400);
    });

    it('should return 400 if password is too short', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/email/register',
        payload: { email: 'test@example.com', password: 'court' },
      });
      expect(res.statusCode).toBe(400);
    });
  });

  // POST /auth/email/login
  describe('POST /v1/auth/email/login', () => {
    it('should return tokens with valid credentials', async () => {
      await app.inject({
        method: 'POST',
        url: '/v1/auth/email/register',
        payload: { email: 'login@example.com', password: 'motdepasse123' },
      });
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/email/login',
        payload: { email: 'login@example.com', password: 'motdepasse123' },
      });
      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body).toHaveProperty('access_token');
      expect(body).toHaveProperty('refresh_token');
    });

    it('should return 401 with wrong password', async () => {
      await app.inject({
        method: 'POST',
        url: '/v1/auth/email/register',
        payload: { email: 'login2@example.com', password: 'motdepasse123' },
      });
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/email/login',
        payload: { email: 'login2@example.com', password: 'mauvaismdp' },
      });
      expect(res.statusCode).toBe(401);
    });

    it('should return 401 with unknown email', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/email/login',
        payload: { email: 'inconnu@example.com', password: 'motdepasse123' },
      });
      expect(res.statusCode).toBe(401);
    });

    it('should return 400 if payload is empty', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/email/login',
        payload: {},
      });
      expect(res.statusCode).toBe(400);
    });
  });
});
