import { z } from 'zod';
import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';
import { pointSchema } from '../validators/delivery.js';

export type Coordinate = z.infer<typeof pointSchema>;
export interface AddressResult extends Coordinate {
  label: string; address: string; placeId: string; source: 'google';
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
export const addressProvider: AddressProvider = new GoogleAddressProvider(
  env.GOOGLE_PLACES_API_KEY || env.GOOGLE_MAPS_API_KEY, env.GOOGLE_GEOCODING_API_KEY || env.GOOGLE_MAPS_API_KEY);
