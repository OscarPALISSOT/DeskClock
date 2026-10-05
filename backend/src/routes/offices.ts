import type { FastifyInstance } from 'fastify';
import {
  CreateOfficeSchema,
  type Office,
  OfficeParamsSchema,
  UpdateOfficeSchema,
} from '../schemas/office.schema.js';

export default async function officeRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate);

  // GET /offices — array shape kept ready for multi-office (premium);
  // exactly 0 or 1 element for now.
  app.get('/', async (request, reply) => {
    const userId = request.user.sub;

    const offices = await app.db<Office[]>`
      SELECT *
      FROM offices
      WHERE user_id = ${userId}
    `;
    return reply.send(offices);
  });

  // POST /offices — create
  app.post('/', async (request, reply) => {
    const body = CreateOfficeSchema.parse(request.body);
    const userId = request.user.sub;

    // Explicit check for a clean 409. The DB-level unique constraint
    // (offices_user_id_unique) remains the source of truth if this races.
    const [existing] = await app.db<Office[]>`
      SELECT id FROM offices WHERE user_id = ${userId}
    `;

    if (existing) {
      return reply.status(409).send({ error: 'Office already exists for this user' });
    }

    const [office] = await app.db<Office[]>`
      INSERT INTO offices (user_id, label, latitude, longitude)
      VALUES (${userId}, ${body.label}, ${body.latitude}, ${body.longitude})
      RETURNING *
    `;
    return reply.status(201).send(office);
  });

  // PATCH /offices/:id
  app.patch<{ Params: { id: string } }>('/:id', async (request, reply) => {
    const { id } = OfficeParamsSchema.parse(request.params);
    const body = UpdateOfficeSchema.parse(request.body);
    const userId = request.user.sub;

    const [office] = await app.db<Office[]>`
      UPDATE offices
      SET
        label     = COALESCE(${body.label ?? null}, label),
        latitude  = COALESCE(${body.latitude ?? null}, latitude),
        longitude = COALESCE(${body.longitude ?? null}, longitude)
      WHERE id = ${id}
        AND user_id = ${userId}
      RETURNING *
    `;

    if (!office) {
      return reply.status(404).send({ error: 'Office not found' });
    }

    return reply.send(office);
  });

  // DELETE /offices/:id
  // work_sessions.office_id is set to NULL by the DB (ON DELETE SET NULL) —
  // no cleanup needed here.
  app.delete<{ Params: { id: string } }>('/:id', async (request, reply) => {
    const { id } = OfficeParamsSchema.parse(request.params);
    const userId = request.user.sub;

    const [deleted] = await app.db<Office[]>`
      DELETE FROM offices
      WHERE id = ${id}
        AND user_id = ${userId}
      RETURNING *
    `;

    if (!deleted) {
      return reply.status(404).send({ error: 'Office not found' });
    }

    return reply.status(204).send();
  });
}
