import Fastify, { FastifyServerOptions } from 'fastify'

const logger: FastifyServerOptions['logger'] =
  process.env['NODE_ENV'] !== 'production'
    ? {
      transport: {
        target: 'pino-pretty',
      },
    }
    : true

const app = Fastify({ logger })

app.get('/healthz', async () => ({ status: 'ok' }))

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