import type { FastifyError, FastifyInstance } from 'fastify';
import fp from 'fastify-plugin';
import { ZodError } from 'zod';

export default fp(async (app: FastifyInstance) => {
  app.setErrorHandler((error: FastifyError, _request, reply) => {
    if (error instanceof ZodError) {
      return reply.status(400).send({
        error: 'Validation failed',
        details: error.flatten().fieldErrors,
      });
    }

    const statusCode = error.statusCode ?? 500;
    return reply.status(statusCode).send({ error: error.message });
  });
});
