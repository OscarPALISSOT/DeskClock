import type { FastifyInstance } from 'fastify';
import { LoginSchema, RegisterSchema } from '../../schemas/auth/email.schema.js';
import { loginUser, registerUser } from '../../services/auth/email.service.js';
import { createTokenPair } from '../../services/auth/token.service.js';

export default async function authEmailRoutes(app: FastifyInstance) {
  // POST /auth/email/register
  app.post('/register', async (request, reply) => {
    const { email, password } = RegisterSchema.parse(request.body);

    const user = await registerUser(app.db, email, password);

    // access_token + refresh_token
    const tokens = await createTokenPair(app.db, user.id, (payload) => app.jwt.sign(payload));

    return reply.status(201).send(tokens);
  });

  // POST /auth/login
  app.post('/login', async (request, reply) => {
    const { email, password } = LoginSchema.parse(request.body);

    const user = await loginUser(app.db, email, password);

    // access_token + refresh_token
    const tokens = await createTokenPair(app.db, user.id, (payload) => app.jwt.sign(payload));

    return reply.send(tokens);
  });
}
