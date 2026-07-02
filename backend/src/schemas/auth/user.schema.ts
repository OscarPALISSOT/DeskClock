import { z } from 'zod';

// GET /me
export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  created_at: z.string().datetime(),
});

export type User = z.infer<typeof UserSchema>;
