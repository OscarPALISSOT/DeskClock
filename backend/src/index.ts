import 'dotenv/config'
import Fastify, { FastifyError, FastifyServerOptions } from 'fastify'

import dbPlugin from './plugins/db.js'
import jwtPlugin from './plugins/jwt.js'
import corsPlugin from './plugins/cors.js'
import errorHandlerPlugin from './plugins/error.js'

import sessionRoutes from './routes/sessions.js'
import meRoutes from './routes/me.js'
import authRoutes from './routes/auth.js'

const logger: FastifyServerOptions['logger'] =
  process.env['NODE_ENV'] !== 'production'
    ? {
      transport: {
        target: 'pino-pretty',
      },
    }
    : true

const app = Fastify({ logger })

// Plugins
await app.register(corsPlugin)
await app.register(dbPlugin)
await app.register(jwtPlugin)
await app.register(errorHandlerPlugin)

// Routes
await app.register(sessionRoutes, { prefix: '/v1/sessions' })
await app.register(meRoutes, { prefix: '/v1/me' })
await app.register(authRoutes, { prefix: '/v1/auth' })

// Health check
app.get('/ping', async () => ({ status: 'ok' }))

const start = async () => {
  try {
    await app.listen({
      port: Number(process.env['PORT'] ?? 3000),
      host: '0.0.0.0',
    })
  } catch (err) {
    app.log.error(err)
    process.exit(1)
  }
}

start()