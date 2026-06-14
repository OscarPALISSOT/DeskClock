import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest'
import { buildApp, seedUserWithToken, cleanDb } from './setup.js'

type App = Awaited<ReturnType<typeof buildApp>>

describe('Sessions', () => {
  let app: App
  let token: string
  let userId: string

  beforeAll(async () => {
    app = await buildApp()
  })

  afterAll(async () => {
    await app.close()
  })

  beforeEach(async () => {
    await cleanDb(app)
    const seeded = await seedUserWithToken(app)
    token = seeded.token
    userId = seeded.user.id
  })

  // POST /sessions 
  describe('POST /v1/sessions', () => {
    it('should create a session and return 201', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })

      expect(res.statusCode).toBe(201)
      const body = res.json()
      expect(body.user_id).toBe(userId)
      expect(body.started_at).toContain('2025-06-10T06:00:00')
      expect(body.ended_at).toBeNull()
    })

    it('should return 401 without token', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })
      expect(res.statusCode).toBe(401)
    })

    it('should return 400 if started_at is missing', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: {},
      })
      expect(res.statusCode).toBe(400)
    })
  })

  // PATCH /sessions/:id 
  describe('PATCH /v1/sessions/:id', () => {
    it('should close an open session and return ended_at', async () => {
      // Create an open session
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })
      const { id } = create.json()

      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${token}` },
        payload: { ended_at: '2025-06-10T18:00:00+02:00' },
      })

      expect(res.statusCode).toBe(200)
      const body = res.json()
      expect(body.ended_at).toContain('2025-06-10T16:00:00')
    })

    it('should return 404 if the session is already closed', async () => {
      // create session
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })
      const { id } = create.json()

      // first close-out
      await app.inject({
        method: 'PATCH',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${token}` },
        payload: { ended_at: '2025-06-10T18:00:00+02:00' },
      })

      // second attempt
      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${token}` },
        payload: { ended_at: '2025-06-10T19:00:00+02:00' },
      })
      expect(res.statusCode).toBe(404)
    })

    it("should return 404 if the session belongs to another user", async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })
      const { id } = create.json()

      // other user
      const { token: otherToken } = await seedUserWithToken(app)

      const res = await app.inject({
        method: 'PATCH',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${otherToken}` },
        payload: { ended_at: '2025-06-10T18:00:00+02:00' },
      })
      expect(res.statusCode).toBe(404)
    })
  })

  // GET /sessions 
  describe('GET /v1/sessions', () => {
    it('should return the sessions within the requested range', async () => {
      // create session
      await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })

      const res = await app.inject({
        method: 'GET',
        url: '/v1/sessions?from=2025-06-10T00:00:00Z&to=2025-06-10T23:59:59Z',
        headers: { authorization: `Bearer ${token}` },
      })

      expect(res.statusCode).toBe(200)
      const body = res.json()
      expect(body).toHaveLength(1)
      expect(body[0].user_id).toBe(userId)
    })

    it("should not return the sessions from another user", async () => {
      // create session
      await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })

      const { token: otherToken } = await seedUserWithToken(app)

      const res = await app.inject({
        method: 'GET',
        url: '/v1/sessions?from=2025-06-10T00:00:00Z&to=2025-06-10T23:59:59Z',
        headers: { authorization: `Bearer ${otherToken}` },
      })

      expect(res.statusCode).toBe(200)
      expect(res.json()).toHaveLength(0)
    })
  })

  // DELETE /sessions/:id 
  describe('DELETE /v1/sessions/:id', () => {
    it('should delete session et return 204', async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })
      const { id } = create.json()

      const res = await app.inject({
        method: 'DELETE',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${token}` },
      })
      expect(res.statusCode).toBe(204)
    })

    it("should returne 404 if the session belongs to another user", async () => {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/sessions',
        headers: { authorization: `Bearer ${token}` },
        payload: { started_at: '2025-06-10T08:00:00+02:00' },
      })
      const { id } = create.json()

      const { token: otherToken } = await seedUserWithToken(app)

      const res = await app.inject({
        method: 'DELETE',
        url: `/v1/sessions/${id}`,
        headers: { authorization: `Bearer ${otherToken}` },
      })
      expect(res.statusCode).toBe(404)
    })
  })
})