import type { FastifyInstance } from 'fastify';
import {
  CloseSessionSchema,
  CreateSessionSchema,
  ListSessionsQuerySchema,
  type Session,
  SessionParamsSchema,
} from '../schemas/session.schema.js';

export default async function sessionRoutes(app: FastifyInstance) {
  // Protect all routes of this plugin
  app.addHook('onRequest', app.authenticate);

  // POST /sessions — clock-in
  app.post<{ Body: { started_at: string } }>('/', async (request, reply) => {
    const body = CreateSessionSchema.parse(request.body);
    const userId = request.user.sub;

    const [session] = await app.db<Session[]>`
      INSERT INTO work_sessions (user_id, started_at)
      VALUES (${userId}, ${body.started_at})
      RETURNING *
    `;
    return reply.status(201).send(session);
  });

  // PATCH /sessions/:id — clock-out
  app.patch<{ Params: { id: string }; Body: { ended_at: string } }>(
    '/:id',
    async (request, reply) => {
      const { id } = SessionParamsSchema.parse(request.params);
      const body = CloseSessionSchema.parse(request.body);
      const userId = request.user.sub;

      const [session] = await app.db<Session[]>`
        UPDATE work_sessions
        SET ended_at = ${body.ended_at}
        WHERE id = ${id}
          AND user_id = ${userId}
          AND ended_at IS NULL
        RETURNING *
      `;

      if (!session) {
        return reply.status(404).send({ error: 'Session not found or already closed' });
      }

      return reply.send(session);
    }
  );

  // GET /sessions — liste sur une plage
  app.get<{ Querystring: { from: string; to: string } }>('/', async (request, reply) => {
    const query = ListSessionsQuerySchema.parse(request.query);
    const userId = request.user.sub;

    const sessions = await app.db<Session[]>`
        SELECT *
        FROM work_sessions
        WHERE user_id = ${userId}
          AND started_at >= ${query.from}
          AND started_at <= ${query.to}
        ORDER BY started_at ASC
      `;
    return reply.send(sessions);
  });

  // DELETE /sessions/:id
  app.delete<{ Params: { id: string } }>('/:id', async (request, reply) => {
    const { id } = SessionParamsSchema.parse(request.params);
    const userId = request.user.sub;

    const [deleted] = await app.db<Session[]>`
      DELETE FROM work_sessions
      WHERE id = ${id}
        AND user_id = ${userId}
      RETURNING *
    `;

    if (!deleted) {
      return reply.status(404).send({ error: 'Session not found' });
    }

    return reply.status(204).send();
  });
}
