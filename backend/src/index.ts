import 'dotenv/config';
import Fastify, { type FastifyServerOptions } from 'fastify';

import corsPlugin from './plugins/cors.js';
import dbPlugin from './plugins/db.js';
import errorHandlerPlugin from './plugins/error.js';
import jwtPlugin from './plugins/jwt.js';
import requestLoggerPlugin from './plugins/requestLogger.js';

import authRoutes from './routes/auth/auth.js';
import meRoutes from './routes/me.js';
import sessionRoutes from './routes/sessions.js';

const logger: FastifyServerOptions['logger'] =
  process.env.NODE_ENV !== 'production'
    ? {
        level: 'debug',
        transport: {
          target: 'pino-pretty',
          options: {
            translateTime: 'HH:MM:ss',
            ignore: 'pid,hostname,reqId',
          },
        },
      }
    : true;

const app = Fastify({
  logger,
  disableRequestLogging: true,
});

// Plugins
await app.register(corsPlugin);
await app.register(dbPlugin);
await app.register(jwtPlugin);
await app.register(errorHandlerPlugin);
await app.register(requestLoggerPlugin);

// Routes
await app.register(sessionRoutes, { prefix: '/v1/sessions' });
await app.register(meRoutes, { prefix: '/v1/me' });
await app.register(authRoutes, { prefix: '/v1/auth' });

// Health check
app.get('/ping', async () => ({ status: 'ok' }));

const start = async () => {
  try {
    await app.listen({
      port: Number(process.env.PORT ?? 3000),
      host: '0.0.0.0',
    });
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

start();
