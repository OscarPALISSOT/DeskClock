import { z } from 'zod';

// POST /auth/apple
export const AppleAuthSchema = z.object({
  identity_token: z.string().min(1),
});

export type AppleAuthInput = z.infer<typeof AppleAuthSchema>;

// POST /auth/refresh
export const RefreshTokenSchema = z.object({
  refresh_token: z.string().min(1),
});

export type RefreshTokenInput = z.infer<typeof RefreshTokenSchema>;

// Réponse auth (access + refresh)
export const AuthResponseSchema = z.object({
  access_token: z.string(),
  refresh_token: z.string(),
  expires_in: z.number(), // secondes
});

export type AuthResponse = z.infer<typeof AuthResponseSchema>;
