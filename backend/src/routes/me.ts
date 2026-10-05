import type { FastifyInstance } from 'fastify';
import type { User } from '../schemas/auth/user.schema.js';
import type { Office } from '../schemas/office.schema.js';

export default async function meRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate);

  // GET /me
  app.get('/', async (request, reply) => {
    const userId = request.user.sub;

    const [user] = await app.db<User[]>`
      SELECT id, email, role, created_at
      FROM users
      WHERE id = ${userId}
    `;

    if (!user) {
      return reply.status(404).send({ error: 'User not found' });
    }

    // Array kept ready for multi-office (premium); one element for now.
    const offices = await app.db<Office[]>`
      SELECT *
      FROM offices
      WHERE user_id = ${userId}
    `;

    return reply.send({ ...user, offices });
  });
}
