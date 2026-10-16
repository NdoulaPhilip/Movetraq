import { afterEach, describe, expect, it, vi } from 'vitest';
vi.mock('../src/config/env.js', () => ({ env: { GOOGLE_MAPS_API_KEY: 'fixture-key' } }));
import { GoogleMapService } from '../src/integrations/maps.js';

afterEach(() => vi.unstubAllGlobals());
describe('mobile road routes', () => {
  it('returns provider geometry with longitude and latitude in the correct order', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ routes: [{
      distanceMeters: 1200, duration: '91.2s',
      polyline: { geoJsonLinestring: { type: 'LineString', coordinates: [[3.4, 6.5], [3.5, 6.6]] } },
    }] })));
    vi.stubGlobal('fetch', request);
    expect(await new GoogleMapService().route({latitude:6.5,longitude:3.4},{latitude:6.6,longitude:3.5}))
      .toEqual({distanceMeters:1200,durationSeconds:92,points:[{latitude:6.5,longitude:3.4},{latitude:6.6,longitude:3.5}]});
    const options=request.mock.calls[0][1] as RequestInit;
    expect(JSON.parse(options.body as string).polylineEncoding).toBe('GEO_JSON_LINESTRING');
  });
  it('fails visibly when the provider omits road geometry', async () => {
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue(new Response(JSON.stringify({routes:[{distanceMeters:1200,duration:'90s'}]}))));
    await expect(new GoogleMapService().route({latitude:6,longitude:3},{latitude:7,longitude:4}))
      .rejects.toMatchObject({status:503,code:'ROUTE_UNAVAILABLE'});
  });
});
