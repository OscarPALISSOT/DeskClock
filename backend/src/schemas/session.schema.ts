import { z } from 'zod';

export const SessionSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  started_at: z.string().datetime(),
  ended_at: z.string().datetime().nullable(),
  created_at: z.string().datetime(),
});

export type Session = z.infer<typeof SessionSchema>;

// POST /sessions
export const CreateSessionSchema = z.object({
  started_at: z.string().datetime({ offset: true }),
});
export type CreateSessionInput = z.infer<typeof CreateSessionSchema>;

// PATCH /sessions/:id
export const CloseSessionSchema = z.object({
  ended_at: z.string().datetime({ offset: true }),
});
export type CloseSessionInput = z.infer<typeof CloseSessionSchema>;

// GET /sessions
export const ListSessionsQuerySchema = z.object({
  from: z.string().datetime({ offset: true }),
  to: z.string().datetime({ offset: true }),
});
export type ListSessionsQuery = z.infer<typeof ListSessionsQuerySchema>;

// Params /:id
export const SessionParamsSchema = z.object({
  id: z.string().uuid(),
});
export type SessionParams = z.infer<typeof SessionParamsSchema>;
