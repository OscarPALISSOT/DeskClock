import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest'
import { createHash, randomBytes } from 'node:crypto'
import { buildApp, seedUserWithToken, cleanDb } from './setup.js'

type App = Awaited<ReturnType<typeof buildApp>>

describe('Auth', () => {
  let app: App

  beforeAll(async () => {
    app = await buildApp()
  })

  afterAll(async () => {
    await app.close()
  })

  beforeEach(async () => {
    await cleanDb(app)
  })

  // POST /auth/apple 
  // JWKS Apple verification needs a true identityToken signed by Apple.
  // We only test the error case
  describe('POST /v1/auth/apple', () => {
    it('should return 400 if identity_token is missing', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/apple',
        payload: {},
      })
      expect(res.statusCode).toBe(400)
    })

    it('should return an error if Apple token is unvalid', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/apple',
        payload: { identity_token: 'token-bidon' },
      })
      // jose throw an verification error → 500 or 401 dependind on the handler
      expect(res.statusCode).toBeGreaterThanOrEqual(400)
    })
  })

  // POST /auth/refresh 
  describe('POST /v1/auth/refresh', () => {
    it('should return a new pair of tokens', async () => {
      const { user } = await seedUserWithToken(app)

      // Insert a refresh token in DB
      const rawToken = randomBytes(64).toString('hex')
      const tokenHash = createHash('sha256').update(rawToken).digest('hex')
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)

      await app.db`
        INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
        VALUES (${user.id}, ${tokenHash}, ${expiresAt.toISOString()})
      `

      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/refresh',
        payload: { refresh_token: rawToken },
      })

      expect(res.statusCode).toBe(200)
      const body = res.json()
      expect(body).toHaveProperty('access_token')
      expect(body).toHaveProperty('refresh_token')
      expect(body.expires_in).toBe(3600)
    })

    it("should invalid the old refresh token after rotation", async () => {
      const { user } = await seedUserWithToken(app)

      const rawToken = randomBytes(64).toString('hex')
      const tokenHash = createHash('sha256').update(rawToken).digest('hex')
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)

      await app.db`
        INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
        VALUES (${user.id}, ${tokenHash}, ${expiresAt.toISOString()})
      `

      // First refresh — ok
      await app.inject({
        method: 'POST',
        url: '/v1/auth/refresh',
        payload: { refresh_token: rawToken },
      })

      // Second attempt with the same token — should failed
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/refresh',
        payload: { refresh_token: rawToken },
      })
      expect(res.statusCode).toBe(401)
    })

    it('should return 401 if the refresh token is expired', async () => {
      const { user } = await seedUserWithToken(app)

      const rawToken = randomBytes(64).toString('hex')
      const tokenHash = createHash('sha256').update(rawToken).digest('hex')
      const expiredAt = new Date(Date.now() - 1000) // déjà expiré

      await app.db`
        INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
        VALUES (${user.id}, ${tokenHash}, ${expiredAt.toISOString()})
      `

      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/refresh',
        payload: { refresh_token: rawToken },
      })
      expect(res.statusCode).toBe(401)
    })

    it('should return 400 if refresh_token is missing', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/auth/refresh',
        payload: {},
      })
      expect(res.statusCode).toBe(400)
    })
  })
})