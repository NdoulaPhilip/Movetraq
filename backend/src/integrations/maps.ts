import { z } from 'zod';
import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';
import type { QuoteInput } from '../validators/delivery.js';

export interface RouteMetrics { distanceMeters: number; durationSeconds: number; }
export interface MapService { route(pickup: QuoteInput['pickup'], destination: QuoteInput['destination']): Promise<RouteMetrics>; }
export class GoogleMapService implements MapService {
  async route(pickup: QuoteInput['pickup'], destination: QuoteInput['destination']): Promise<RouteMetrics> {
    if (!env.GOOGLE_MAPS_API_KEY) throw new ApiError(503, 'MAPS_NOT_CONFIGURED', 'Route quoting is unavailable.');
    const waypoint = (point: QuoteInput['pickup']) => ({ location: { latLng: { latitude: point.latitude, longitude: point.longitude } } });
    try {
      const response = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': env.GOOGLE_MAPS_API_KEY,
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration' },
        body: JSON.stringify({ origin: waypoint(pickup), destination: waypoint(destination), travelMode: 'DRIVE' }),
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) throw new Error('Route provider failed');
      const result = z.object({ routes: z.array(z.object({ distanceMeters: z.number().int().positive(),
        duration: z.string().regex(/^\d+(\.\d+)?s$/) })).min(1) }).parse(await response.json());
      return { distanceMeters: result.routes[0].distanceMeters, durationSeconds: Math.ceil(Number(result.routes[0].duration.slice(0, -1))) };
    } catch { throw new ApiError(503, 'ROUTE_UNAVAILABLE', 'A live route could not be calculated. Please retry.'); }
  }
}
export const mapService: MapService = new GoogleMapService();
