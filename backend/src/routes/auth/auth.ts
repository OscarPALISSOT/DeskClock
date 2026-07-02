import type { FastifyInstance } from 'fastify';
import { RefreshTokenSchema } from '../../schemas/auth/apple.schema.js';
import { rotateRefreshToken } from '../../services/auth/token.service.js';
import authAppleRoutes from './apple.js';
import authEmailRoutes from './email.js';

export default async function authRoutes(app: FastifyInstance) {
  app.register(authAppleRoutes, { prefix: '/apple' });
  app.register(authEmailRoutes, { prefix: '/email' });

  // POST /auth/refresh
  app.post('/refresh', async (request, reply) => {
    const { refresh_token } = RefreshTokenSchema.parse(request.body);

    const tokens = await rotateRefreshToken(app.db, refresh_token, (payload) =>
      app.jwt.sign(payload)
    );

    return reply.send(tokens);
  });
}
