import type { FastifyInstance } from 'fastify'
import type { User } from '../schemas/auth.schema.js'

export default async function meRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate)

  // GET /me 
  app.get('/', async (request, reply) => {
    const userId = request.user.sub

    const [user] = await app.db<User[]>`
      SELECT id, email, created_at
      FROM users
      WHERE id = ${userId}
    `

    if (!user) {
      return reply.status(404).send({ error: 'User not found' })
    }

    return reply.send(user)
  })
}