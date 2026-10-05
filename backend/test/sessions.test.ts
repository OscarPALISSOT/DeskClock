import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp, cleanDb, seedUserWithToken } from './setup.js';

type App = Awaited<ReturnType<typeof buildApp>>;

describe('Sessions', () => {
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

  // POST /sessions
  describe('POST /v1/sessions', () => {
    it('should create a session and return 201', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });

      expect(res.statusCode).toBe(201);
      const body = res.json();
      expect(body.user_id).toBe(userId);
      expect(body.started_at).toContain('2025-06-10T06:00:00');
      expect(body.ended_at).toBeNull();
    });

    it('should return office_id null when the user has no office configured', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });

      expect(res.statusCode).toBe(201);
      expect(res.json().office_id).toBeNull();
    });

    it('should resolve office_id server-side from the user own office', async () => {
      const officeRes = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 40.14325, longitude: 6.318548 },
      });
      const officeId = officeRes.json().id;

      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });

      expect(res.json().office_id).toBe(officeId);
    });

    it('should ignore a client-supplied office_id and never trust it', async () => {
      // The requesting user has their own office...
      const ownOfficeRes = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'Own office', latitude: 45.188323, longitude: 7.867538 },
      });
      const ownOfficeId = ownOfficeRes.json().id;

      // ...and another user has a different office.
      const other = await seedUserWithToken(app);
      const otherOfficeRes = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${other.token}` },
        payload: { label: 'Other office', latitude: 48.8566, longitude: 2.3522 },
      });
      const otherOfficeId = otherOfficeRes.json().id;

      // Attempt to spoof office_id in the request body.
      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00', office_id: otherOfficeId },
      });

      expect(res.json().office_id).toBe(ownOfficeId);
      expect(res.json().office_id).not.toBe(otherOfficeId);
    });

    it('should return 401 without token', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });
      expect(res.statusCode).toBe(401);
    });

    it('should return 400 if started_at is missing', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: {},
      });
      expect(res.statusCode).toBe(400);
    });
  });

  // PATCH /sessions/:id
  describe('PATCH /v1/sessions/:id', () => {
    it('should close an open session and return ended_at', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });
      const { id } = create.json();

      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${token}` },
        payload: { ended_at: '2025-06-10T18:00:00+02:00' },
      });

      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body.ended_at).toContain('2025-06-10T16:00:00');
    });

    it('should return 404 if the session is already closed', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });
      const { id } = create.json();

      await app.inject({
        method: 'PATCH',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${token}` },
        payload: { ended_at: '2025-06-10T18:00:00+02:00' },
      });

      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${token}` },
        payload: { ended_at: '2025-06-10T19:00:00+02:00' },
      });
      expect(res.statusCode).toBe(404);
    });

    it('should return 404 if the session belongs to another user', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });
      const { id } = create.json();

      const { token: otherToken } = await seedUserWithToken(app);

      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${otherToken}` },
        payload: { ended_at: '2025-06-10T18:00:00+02:00' },
      });
      expect(res.statusCode).toBe(404);
    });
  });

  // GET /sessions
  describe('GET /v1/sessions', () => {
    it('should return the sessions within the requested range', async () => {
      await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });

      const res = await app.inject({
        method: 'GET',
        url: '/v1/sessions?from=2025-06-10T00:00:00Z&to=2025-06-10T23:59:59Z',
        headers: { authorization: `Bearer ${token}` },
      });

      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body).toHaveLength(1);
      expect(body[0].user_id).toBe(userId);
    });

    it('should not return the sessions from another user', async () => {
      await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });

      const { token: otherToken } = await seedUserWithToken(app);

      const res = await app.inject({
        method: 'GET',
        url: '/v1/sessions?from=2025-06-10T00:00:00Z&to=2025-06-10T23:59:59Z',
        headers: { authorization: `Bearer ${otherToken}` },
      });

      expect(res.statusCode).toBe(200);
      expect(res.json()).toHaveLength(0);
    });
  });

  // DELETE /sessions/:id
  describe('DELETE /v1/sessions/:id', () => {
    it('should delete session and return 204', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });
      const { id } = create.json();

      const res = await app.inject({
        method: 'DELETE',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${token}` },
      });
      expect(res.statusCode).toBe(204);
    });

    it('should return 404 if the session belongs to another user', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });
      const { id } = create.json();

      const { token: otherToken } = await seedUserWithToken(app);

      const res = await app.inject({
        method: 'DELETE',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${otherToken}` },
      });
      expect(res.statusCode).toBe(404);
    });
  });

  // Office linkage
  describe('Session/office linkage', () => {
    it('should set office_id to null when the linked office is deleted', async () => {
      const officeRes = await app.inject({
        method: 'POST',
        url: '/v1/offices',
        headers: { authorization: `Bearer ${token}` },
        payload: { label: 'HQ', latitude: 45.188323, longitude: 5.712538 },
      });
      const officeId = officeRes.json().id;

      const sessionRes = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      });
      const sessionId = sessionRes.json().id;
      expect(sessionRes.json().office_id).toBe(officeId);

      await app.inject({
        method: 'DELETE',
        url: `/v1/offices/${officeId}`,
        headers: { authorization: `Bearer ${token}` },
      });

      const listRes = await app.inject({
        method: 'GET',
        url: '/v1/sessions?from=2025-06-10T00:00:00Z&to=2025-06-10T23:59:59Z',
        headers: { authorization: `Bearer ${token}` },
      });

      const session = listRes.json().find((s: { id: string }) => s.id === sessionId);
      expect(session.office_id).toBeNull();
    });
  });
});
