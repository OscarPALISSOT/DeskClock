import fp from 'fastify-plugin'
import fastifyCors from '@fastify/cors'
import type { FastifyInstance } from 'fastify'

export default fp(async (app: FastifyInstance) => {
  app.register(fastifyCors, {
    origin: process.env['NODE_ENV'] === 'production' ? false : true,
  })
})