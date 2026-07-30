import type { FastifyInstance } from 'fastify';
import fp from 'fastify-plugin';

declare module 'fastify' {
  interface FastifyRequest {
    errorPayload: string | null;
  }
}

function extractErrorMessage(payload: string | null): string | undefined {
  if (!payload) return undefined;
  try {
    const parsed = JSON.parse(payload) as { error?: string; message?: string };
    return parsed.error ?? parsed.message;
  } catch {
    return undefined;
  }
}

async function requestLoggerPlugin(app: FastifyInstance) {
  app.decorateRequest('errorPayload', null);

  app.addHook('onSend', async (request, reply, payload) => {
    if (reply.statusCode >= 400 && typeof payload === 'string') {
      request.errorPayload = payload;
    }
    return payload;
  });

  app.addHook('onResponse', async (request, reply) => {
    const responseTime = Math.round(reply.elapsedTime);
    const line = `${request.method} ${request.url} ${reply.statusCode} (${responseTime}ms)`;

    if (reply.statusCode >= 500) {
      request.log.error(line);
    } else if (reply.statusCode >= 400) {
      const message = extractErrorMessage(request.errorPayload);
      request.log.warn(message ? `${line} — ${message}` : line);
    } else {
      request.log.info(line);
    }
  });
}

export default fp(requestLoggerPlugin);
