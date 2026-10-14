import { afterEach, describe, expect, it, vi } from 'vitest';

vi.mock('../src/config/env.js', () => ({ env: {} }));
import { GoogleAddressProvider } from '../src/services/address-search.js';

afterEach(() => vi.restoreAllMocks());
describe('archive-adapted address provider', () => {
  it('does not call a public demo or invent addresses when unconfigured', async () => {
    const request = vi.fn();
    const provider = new GoogleAddressProvider(undefined, undefined, request);
    await expect(provider.search('Ikeja Lagos')).rejects.toMatchObject({ status: 503, code: 'ADDRESS_PROVIDER_NOT_CONFIGURED' });
    await expect(provider.reverse({ latitude: 6.5, longitude: 3.4 })).rejects.toMatchObject({ status: 503 });
    expect(request).not.toHaveBeenCalled();
  });
  it('validates queries before requesting and returns only real usable coordinates', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ places: [
      { id: 'real-place', displayName: { text: 'Ikeja' }, formattedAddress: 'Ikeja Lagos', location: { latitude: 6.6, longitude: 3.3 } },
      { id: 'no-location', displayName: { text: 'Online shop' }, formattedAddress: 'Lagos' },
      { id: 'invalid', displayName: { text: 'Invalid' }, formattedAddress: 'Lagos', location: { latitude: 100, longitude: 3.3 } },
    ] })));
    const provider = new GoogleAddressProvider('places-secret', 'geocode-secret', request);
    await expect(provider.search(' ')).rejects.toBeDefined();
    expect(request).not.toHaveBeenCalled();
    expect(await provider.search(' Ikeja Lagos ')).toEqual([{ label: 'Ikeja', address: 'Ikeja Lagos', placeId: 'real-place', latitude: 6.6, longitude: 3.3, source: 'google' }]);
    const [url, init] = request.mock.calls[0];
    expect(url).toBe('https://places.googleapis.com/v1/places:searchText');
    expect(init.redirect).toBe('error');
    expect(JSON.parse(init.body)).toMatchObject({ textQuery: 'Ikeja Lagos', regionCode: 'NG', pageSize: 10 });
    expect(init.headers['X-Goog-Api-Key']).toBe('places-secret');
  });
  it('uses requested coordinates for reverse lookup without exposing a key', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ status: 'OK', results: [
      { place_id: 'place', formatted_address: 'Ikeja Lagos' },
    ] })));
    const provider = new GoogleAddressProvider('places', 'geocode', request);
    const point = { latitude: 6.6, longitude: 3.3 };
    const result = await provider.reverse(point);
    expect(result).toEqual({ ...point, label: 'Ikeja Lagos', address: 'Ikeja Lagos', placeId: 'place', source: 'google' });
    expect(new URL(request.mock.calls[0][0]).searchParams.get('latlng')).toBe('6.6,3.3');
    expect(JSON.stringify(result)).not.toContain('geocode');
    await expect(provider.reverse({ latitude: NaN, longitude: 0 })).rejects.toBeDefined();
    expect(request).toHaveBeenCalledTimes(1);
  });
  it('distinguishes no result from provider failures and sanitizes failures', async () => {
    const request = vi.fn();
    const provider = new GoogleAddressProvider('places', 'secret-key', request);
    request.mockResolvedValueOnce(new Response(JSON.stringify({ status: 'ZERO_RESULTS', results: [] })));
    await expect(provider.reverse({ latitude: 0, longitude: 0 })).rejects.toMatchObject({ status: 422, code: 'ADDRESS_NOT_FOUND' });
    request.mockResolvedValueOnce(new Response(JSON.stringify({ status: 'REQUEST_DENIED', error_message: 'secret-key' })));
    await expect(provider.reverse({ latitude: 0, longitude: 0 })).rejects.toMatchObject({ status: 503, message: 'Address lookup is temporarily unavailable.' });
    request.mockRejectedValueOnce(new Error('secret-key'));
    await expect(provider.search('Lagos Nigeria')).rejects.toMatchObject({ status: 503, message: 'Address lookup is temporarily unavailable.' });
    request.mockResolvedValueOnce(new Response('{"places":"invalid"}'));
    await expect(provider.search('Lagos Nigeria')).rejects.toMatchObject({ status: 503 });
  });
});
