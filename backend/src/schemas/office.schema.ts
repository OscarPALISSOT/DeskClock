import { z } from 'zod';

export const CreateOfficeSchema = z.object({
  label: z.string().trim().min(1).max(100),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});

export const UpdateOfficeSchema = CreateOfficeSchema.partial();

export const OfficeParamsSchema = z.object({
  id: z.string().uuid(),
});

export type Office = {
  id: string;
  user_id: string;
  label: string;
  latitude: number;
  longitude: number;
  created_at: string;
};
