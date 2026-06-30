import type { FastifyInstance } from 'fastify';
import { AppleAuthSchema, RefreshTokenSchema } from '../../schemas/auth/apple.schema.js';
import { upsertUser, verifyAppleToken } from '../../services/auth/apple.service.js';
import { createTokenPair, rotateRefreshToken } from '../../services/auth/token.service.js';

export default async function authAppleRoutes(app: FastifyInstance) {
  // POST /auth/apple
  app.post('/', async (request, reply) => {
    const { identity_token } = AppleAuthSchema.parse(request.body);

    // Verified Apple token (JWKS)
    const claims = await verifyAppleToken(identity_token);

    const user = await upsertUser(app.db, claims);

    // access_token + refresh_token
    const tokens = await createTokenPair(app.db, user.id, (payload) => app.jwt.sign(payload));

    return reply.status(201).send(tokens);
  });
}
