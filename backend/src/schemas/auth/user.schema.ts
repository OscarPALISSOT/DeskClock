import { z } from 'zod';

export const UserRoleSchema = z.enum(['user', 'tester']);
export type UserRole = z.infer<typeof UserRoleSchema>;

// GET /me
export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  role: UserRoleSchema,
  created_at: z.string().datetime(),
});

export type User = z.infer<typeof UserSchema>;
