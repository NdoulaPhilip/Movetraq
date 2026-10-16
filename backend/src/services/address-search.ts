import { z } from 'zod';
import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';
import { pointSchema } from '../validators/delivery.js';

export type Coordinate = z.infer<typeof pointSchema>;
export interface AddressResult extends Coordinate {
  label: string; address: string; placeId: string; source: 'google' | 'osm';
}
export interface AddressProvider {
  search(query: string): Promise<AddressResult[]>;
  reverse(point: Coordinate): Promise<AddressResult>;
}
const querySchema = z.string().trim().min(3).max(200);
const placeSchema = z.object({ id: z.string().min(1).max(200),
  displayName: z.object({ text: z.string().min(1).max(500) }),
  formattedAddress: z.string().min(1).max(1000), location: pointSchema.passthrough() });

export class GoogleAddressProvider implements AddressProvider {
  constructor(private placesKey?: string, private geocodingKey?: string, private request: typeof fetch = fetch) {}
  private async json(url: string, key: string | undefined, init?: RequestInit): Promise<unknown> {
    if (!key?.trim()) throw new ApiError(503, 'ADDRESS_PROVIDER_NOT_CONFIGURED', 'Address lookup is unavailable.');
    try {
      const response = await this.request(url, { ...init, redirect: 'error', signal: AbortSignal.timeout(10000) });
      if (!response.ok) throw new Error('Provider request failed');
      return await response.json();
    } catch {
      throw new ApiError(503, 'ADDRESS_PROVIDER_UNAVAILABLE', 'Address lookup is temporarily unavailable.');
    }
  }
  async search(query: string): Promise<AddressResult[]> {
    const textQuery = querySchema.parse(query);
    const body = await this.json('https://places.googleapis.com/v1/places:searchText', this.placesKey, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': this.placesKey ?? '',
        'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location' },
      body: JSON.stringify({ textQuery, regionCode: 'NG', languageCode: 'en', pageSize: 10 }),
    });
    const result = z.object({ places: z.array(z.unknown()).max(20).default([]) }).safeParse(body);
    if (!result.success) throw new ApiError(503, 'ADDRESS_PROVIDER_UNAVAILABLE', 'Address lookup returned an invalid response.');
    return result.data.places.flatMap(value => {
      const place = placeSchema.safeParse(value);
      if (!place.success) return [];
      return [{ label: place.data.displayName.text, address: place.data.formattedAddress,
        placeId: place.data.id, latitude: place.data.location.latitude, longitude: place.data.location.longitude, source: 'google' as const }];
    });
  }
  async reverse(point: Coordinate): Promise<AddressResult> {
    const coordinates = pointSchema.parse(point);
    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.search = new URLSearchParams({ latlng: `${coordinates.latitude},${coordinates.longitude}`,
      key: this.geocodingKey ?? '', language: 'en' }).toString();
    const body = await this.json(url.href, this.geocodingKey);
    const parsed = z.object({ status: z.string(), results: z.array(z.object({
      formatted_address: z.string().min(1).max(1000), place_id: z.string().min(1).max(200),
    })).default([]) }).safeParse(body);
    if (!parsed.success || !['OK', 'ZERO_RESULTS'].includes(parsed.data.status)) {
      throw new ApiError(503, 'ADDRESS_PROVIDER_UNAVAILABLE', 'Address lookup is temporarily unavailable.');
    }
    const result = parsed.data.results[0];
    if (parsed.data.status === 'ZERO_RESULTS' || !result) throw new ApiError(422, 'ADDRESS_NOT_FOUND', 'No address was found for this point.');
    return { ...coordinates, label: result.formatted_address, address: result.formatted_address, placeId: result.place_id, source: 'google' };
  }
}
const osmPlace = z.object({ place_id: z.union([z.string(), z.number()]),
  display_name: z.string().min(1).max(1000), name: z.string().optional(),
  lat: z.coerce.number().finite().min(-90).max(90), lon: z.coerce.number().finite().min(-180).max(180) });

/** Explicit searches only. The shared queue also throttles reverse lookups. */
export class NominatimAddressProvider implements AddressProvider {
  private cache = new Map<string, {expires:number; value:unknown}>();
  private pending = new Map<string, Promise<unknown>>();
  private tail: Promise<unknown> = Promise.resolve();
  private nextRequest = 0;
  constructor(private origin = 'https://nominatim.openstreetmap.org',
    private userAgent = 'MoveTraq/1.0 (https://github.com/NdoulaPhilip/Movetraq)',
    private request: typeof fetch = fetch, private intervalMs = 1100) {}
  private json(path:string, params:Record<string,string>):Promise<unknown> {
    const url = new URL(`${this.origin.replace(/\/$/,'')}/${path}`);
    url.search = new URLSearchParams({...params,format:'jsonv2','accept-language':'en'}).toString();
    const key = url.href;
    const cached = this.cache.get(key);
    if (cached && cached.expires > Date.now()) return Promise.resolve(cached.value);
    const active = this.pending.get(key);
    if (active) return active;
    if (this.pending.size >= 20) return Promise.reject(new ApiError(503,'ADDRESS_PROVIDER_BUSY','Address lookup is busy. Please retry.'));
    const task = this.tail.catch(() => {}).then(async () => {
      const delay = this.nextRequest - Date.now();
      if (delay > 0) await new Promise(resolve => setTimeout(resolve,delay));
      this.nextRequest = Date.now() + this.intervalMs;
      try {
        const response = await this.request(url,{headers:{'User-Agent':this.userAgent,Accept:'application/json'},
          redirect:'error',signal:AbortSignal.timeout(10000)});
        if (!response.ok) throw new Error();
        const value:unknown = await response.json();
        if (this.cache.size >= 300) this.cache.delete(this.cache.keys().next().value!);
        this.cache.set(key,{expires:Date.now()+3600000,value});
        return value;
      } catch { throw new ApiError(503,'ADDRESS_PROVIDER_UNAVAILABLE','Address lookup is temporarily unavailable.'); }
    });
    this.tail = task;
    this.pending.set(key,task);
    void task.finally(() => this.pending.delete(key)).catch(() => {});
    return task;
  }
  private place(value:unknown):AddressResult {
    const result = osmPlace.safeParse(value);
    if (!result.success) throw new ApiError(503,'ADDRESS_PROVIDER_UNAVAILABLE','Address lookup returned an invalid response.');
    const item = result.data;
    return {label:item.name || item.display_name.split(',')[0], address:item.display_name,
      latitude:item.lat,longitude:item.lon,placeId:`osm:${item.place_id}`,source:'osm'};
  }
  async search(query:string):Promise<AddressResult[]> {
    const data = await this.json('search',{q:querySchema.parse(query),limit:'10'});
    const parsed = z.array(z.unknown()).max(20).safeParse(data);
    if (!parsed.success) throw new ApiError(503,'ADDRESS_PROVIDER_UNAVAILABLE','Address lookup returned an invalid response.');
    return parsed.data.map(value => this.place(value));
  }
  async reverse(point:Coordinate):Promise<AddressResult> {
    const coordinates = pointSchema.parse(point);
    const data = await this.json('reverse',{lat:coordinates.latitude.toFixed(5),lon:coordinates.longitude.toFixed(5),zoom:'18'});
    if (data && typeof data === 'object' && 'error' in data) throw new ApiError(422,'ADDRESS_NOT_FOUND','No address was found for this point.');
    // Keep the selected GPS/pin point, rather than the nearby feature centroid.
    return {...this.place(data),...coordinates};
  }
}
export const addressProvider: AddressProvider = env.MAPS_PROVIDER === 'google'
  ? new GoogleAddressProvider(env.GOOGLE_PLACES_API_KEY || env.GOOGLE_MAPS_API_KEY, env.GOOGLE_GEOCODING_API_KEY || env.GOOGLE_MAPS_API_KEY)
  : new NominatimAddressProvider(env.NOMINATIM_URL,env.MAPS_USER_AGENT);
