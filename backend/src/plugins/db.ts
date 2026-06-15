import type { FastifyInstance } from 'fastify';
import fp from 'fastify-plugin';
import postgres from 'postgres';

declare module 'fastify' {
  interface FastifyInstance {
    db: postgres.Sql;
  }
}

export default fp(async (app: FastifyInstance) => {
  const db = postgres(process.env.DATABASE_URL ?? '', {
    max: 10,
    idle_timeout: 30,
    connect_timeout: 10,
    onnotice: (notice) => app.log.debug(notice, 'postgres notice'),
  });

  // Vérification de la connexion au démarrage
  await db`SELECT 1`;
  app.log.info('PostgreSQL connecté');

  app.decorate('db', db);

  app.addHook('onClose', async () => {
    await db.end();
    app.log.info('PostgreSQL disconnected');
  });
});
