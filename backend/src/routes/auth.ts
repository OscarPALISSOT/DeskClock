import type { FastifyInstance } from 'fastify';
import { AppleAuthSchema, RefreshTokenSchema } from '../schemas/auth.schema.js';
import {
  createTokenPair,
  rotateRefreshToken,
  upsertUser,
  verifyAppleToken,
} from '../services/auth.service.js';

export default async function authRoutes(app: FastifyInstance) {
  // POST /auth/apple
  app.post('/apple', async (request, reply) => {
    const { identity_token } = AppleAuthSchema.parse(request.body);

    // Verified Apple token (JWKS)
    const claims = await verifyAppleToken(identity_token);

    const user = await upsertUser(app.db, claims);

    // access_token + refresh_token
    const tokens = await createTokenPair(app.db, user.id, (payload) => app.jwt.sign(payload));

    return reply.status(201).send(tokens);
  });

  // POST /auth/refresh
  app.post('/refresh', async (request, reply) => {
    const { refresh_token } = RefreshTokenSchema.parse(request.body);

    const tokens = await rotateRefreshToken(app.db, refresh_token, (payload) =>
      app.jwt.sign(payload)
    );

    return reply.send(tokens);
  });
}
