import 'dotenv/config';
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  TRUST_PROXY_HOPS: z.coerce.number().int().min(0).max(3).default(0),
  CORS_ORIGINS: z.string().default('http://localhost:5173'),
  SUPABASE_URL: z.string().url(),
  SUPABASE_ANON_KEY: z.string().min(1),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  PAYMENT_PROVIDER: z.enum(['paystack', 'flutterwave']).default('paystack'),
  PAYMENT_SECRET_KEY: z.string().optional(),
  PAYMENT_WEBHOOK_SECRET: z.string().optional(),
  PAYMENT_CALLBACK_URL: z.string().url().optional(),
  GOOGLE_MAPS_API_KEY: z.string().optional(),
  GOOGLE_PLACES_API_KEY: z.string().optional(),
  GOOGLE_GEOCODING_API_KEY: z.string().optional(),
  MAPS_PROVIDER: z.enum(['osm', 'google']).default('osm'),
  GEOCODER_PROVIDER: z.enum(['nominatim', 'photon']).default('nominatim'),
  PHOTON_URL: z.string().url().default('https://photon.komoot.io'),
  OSRM_URL: z.string().url().default('https://router.project-osrm.org'),
  NOMINATIM_URL: z.string().url().default('https://nominatim.openstreetmap.org'),
  MAPS_USER_AGENT: z.string().min(8).default('MoveTraq/1.0 (https://github.com/NdoulaPhilip/Movetraq)'),
  JWT_AUDIENCE: z.string().default('authenticated'),
  LOG_LEVEL: z.string().default('info'),
  AUTH_REDIRECT_URL: z.string().url().optional(),
  ADMIN_INVITE_REDIRECT_URL: z.string().url().optional(),
  MOBILE_MONITORING_URL: z.string().url().optional(),
  MONITORING_SERVICE_TOKEN: z.string().min(32).optional(),
});

export const env = envSchema.parse(process.env);

export const corsOrigins = env.CORS_ORIGINS.split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
