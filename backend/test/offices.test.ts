import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp, cleanDb, seedUserWithToken } from './setup.js';

type App = Awaited<ReturnType<typeof buildApp>>;

describe('Offices', () => {
  let app: App;
  let token: string;
  let userId: string;

  beforeAll(async () => {
    app = await buildApp();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    await cleanDb(app);
    const seeded = await seedUserWithToken(app);
    token = seeded.token;
    userId = seeded.user.id;
  });

  // POST /offices
  describe('POST /v1/offices', () => {
    it('should create an office and return 201', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });

      expect(res.statusCode).toBe(201);
      const body = res.json();
      expect(body.user_id).toBe(userId);
      expect(body.label).toBe('HQ');
      expect(body.latitude).toBe(45.188323);
      expect(body.longitude).toBe(5.712538);
    });

    it('should return 409 if the user already has an office', async () => {
      await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });

      const res = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'Second office', latitude: 48.8566, longitude: 2.3522 },
      });

      expect(res.statusCode).toBe(409);
    });

    it('should return 401 without token', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });
      expect(res.statusCode).toBe(401);
    });

    it('should return 400 if label is missing', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { latitude: 45.188323, longitude: 5.712538 },
      });
      expect(res.statusCode).toBe(400);
    });

    it('should return 400 if latitude is out of range', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 200, longitude: 5.712538 },
      });
      expect(res.statusCode).toBe(400);
    });
  });

  // GET /offices
  describe('GET /v1/offices', () => {
    it('should return an empty array when no office is configured', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
      });

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual([]);
    });

    it('should return the user office', async () => {
      await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });

      const res = await app.inject({
        method: 'GET',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
      });

      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body).toHaveLength(1);
      expect(body[0].label).toBe('HQ');
    });

    it('should not return another user office', async () => {
      await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });

      const { token: otherToken } = await seedUserWithToken(app);

      const res = await app.inject({
        method: 'GET',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${otherToken}` },
      });

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual([]);
    });

    it('should return 401 without token', async () => {
      const res = await app.inject({ method: 'GET', url: '/v1/offices' });
      expect(res.statusCode).toBe(401);
    });
  });

  // PATCH /offices/:id
  describe('PATCH /v1/offices/:id', () => {
    it('should update the label only', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });
      const { id } = create.json();

      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/offices/${id}`,
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'New label' },
      });

      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body.label).toBe('New label');
      expect(body.latitude).toBe(45.188323);
      expect(body.longitude).toBe(5.712538);
    });

    it('should update the coordinates', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });
      const { id } = create.json();

      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/offices/${id}`,
        headers: { authorization: `Bearer ${token}` },
        payload: { latitude: 48.8566, longitude: 2.3522 },
      });

      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body.latitude).toBe(48.8566);
      expect(body.longitude).toBe(2.3522);
    });

    it('should return 404 if the office belongs to another user', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });
      const { id } = create.json();

      const { token: otherToken } = await seedUserWithToken(app);

      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/offices/${id}`,
        headers: { authorization: `Bearer ${otherToken}` },
        payload: { label: 'Hijacked' },
      });
      expect(res.statusCode).toBe(404);
    });

    it('should return 404 if the office does not exist', async () => {
      const res = await app.inject({
        method: 'PATCH',
        url: '/v1/offices/00000000-0000-0000-0000-000000000000',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'Ghost' },
      });
      expect(res.statusCode).toBe(404);
    });
  });

  // DELETE /offices/:id
  describe('DELETE /v1/offices/:id', () => {
    it('should delete the office and return 204', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });
      const { id } = create.json();

      const res = await app.inject({
        method: 'DELETE',
        url: `/v1/offices/${id}`,
        headers: { authorization: `Bearer ${token}` },
      });
      expect(res.statusCode).toBe(204);
    });

    it('should return 404 if the office belongs to another user', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });
      const { id } = create.json();

      const { token: otherToken } = await seedUserWithToken(app);

      const res = await app.inject({
        method: 'DELETE',
        url: `/v1/offices/${id}`,
        headers: { authorization: `Bearer ${otherToken}` },
      });
      expect(res.statusCode).toBe(404);
    });

    it('should return 401 without token', async () => {
      const res = await app.inject({
        method: 'DELETE',
        url: '/v1/offices/00000000-0000-0000-0000-000000000000',
      });
      expect(res.statusCode).toBe(401);
    });
  });
});
