import { z } from 'zod';
import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';
import type { Coordinate } from '../services/address-search.js';

export interface RouteMetrics { distanceMeters: number; durationSeconds: number; points?: { latitude: number; longitude: number }[]; }
export interface MapService { route(pickup: Coordinate, destination: Coordinate): Promise<RouteMetrics>; }
export class GoogleMapService implements MapService {
  async route(pickup: Coordinate, destination: Coordinate): Promise<RouteMetrics> {
    if (!env.GOOGLE_MAPS_API_KEY) throw new ApiError(503, 'MAPS_NOT_CONFIGURED', 'Route quoting is unavailable.');
    const waypoint = (point: Coordinate) => ({ location: { latLng: { latitude: point.latitude, longitude: point.longitude } } });
    try {
      const response = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': env.GOOGLE_MAPS_API_KEY,
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.geoJsonLinestring' },
        body: JSON.stringify({ origin: waypoint(pickup), destination: waypoint(destination), travelMode: 'DRIVE',
          routingPreference: 'TRAFFIC_AWARE', polylineEncoding: 'GEO_JSON_LINESTRING' }),
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) throw new Error('Route provider failed');
      const result = z.object({ routes: z.array(z.object({ distanceMeters: z.number().int().positive(),
        duration: z.string().regex(/^\d+(\.\d+)?s$/), polyline: z.object({ geoJsonLinestring: z.object({
          type: z.literal('LineString'), coordinates: z.array(z.tuple([z.number().min(-180).max(180), z.number().min(-90).max(90)])).min(2),
        }) }) })).min(1) }).parse(await response.json());
      return { distanceMeters: result.routes[0].distanceMeters, durationSeconds: Math.ceil(Number(result.routes[0].duration.slice(0, -1))),
        points: result.routes[0].polyline.geoJsonLinestring.coordinates.map(([longitude,latitude]) => ({latitude,longitude})) };
    } catch { throw new ApiError(503, 'ROUTE_UNAVAILABLE', 'A live route could not be calculated. Please retry.'); }
  }
}
export class OsrmMapService implements MapService {
  constructor(private origin = 'https://router.project-osrm.org', private request: typeof fetch = fetch) {}
  async route(pickup:Coordinate,destination:Coordinate):Promise<RouteMetrics> {
    const point = z.object({latitude:z.number().finite().min(-90).max(90),longitude:z.number().finite().min(-180).max(180)});
    point.parse(pickup); point.parse(destination);
    const path = `${pickup.longitude},${pickup.latitude};${destination.longitude},${destination.latitude}`;
    const url = new URL(`${this.origin.replace(/\/$/,'')}/route/v1/driving/${path}`);
    url.search = new URLSearchParams({overview:'full',geometries:'geojson',steps:'false'}).toString();
    try {
      const response = await this.request(url,{redirect:'error',signal:AbortSignal.timeout(15000)});
      if (!response.ok) throw new Error();
      const body:unknown = await response.json();
      if (body && typeof body === 'object' && 'code' in body && body.code === 'NoRoute') {
        throw new ApiError(422,'NO_ROAD_ROUTE','No road route was found between these locations.');
      }
      const result = z.object({code:z.literal('Ok'),routes:z.array(z.object({
        distance:z.number().finite().nonnegative(),duration:z.number().finite().nonnegative(),
        geometry:z.object({type:z.literal('LineString'),coordinates:z.array(z.tuple([
          z.number().finite().min(-180).max(180),z.number().finite().min(-90).max(90)])).min(2).max(50000)}),
      })).min(1)}).parse(body).routes[0];
      return {distanceMeters:Math.max(1,Math.ceil(result.distance)),durationSeconds:Math.max(1,Math.ceil(result.duration)),
        points:result.geometry.coordinates.map(([longitude,latitude]) => ({latitude,longitude}))};
    } catch(error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(503,'ROUTE_UNAVAILABLE','A live route could not be calculated. Please retry.');
    }
  }
}
export const mapService: MapService = env.MAPS_PROVIDER === 'google' ? new GoogleMapService() : new OsrmMapService(env.OSRM_URL);
