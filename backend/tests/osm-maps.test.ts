import { describe, expect, it, vi } from 'vitest';
vi.mock('../src/config/env.js', () => ({env:{MAPS_PROVIDER:'osm'}}));
import { NominatimAddressProvider, PhotonAddressProvider } from '../src/services/address-search.js';
import { OsrmMapService } from '../src/integrations/maps.js';

describe('OSM address lookup', () => {
  const place = {place_id:123,display_name:'Fixture street, Lagos',lat:'6.5',lon:'3.4'};
  it('uses an identifying user agent, caches repeated searches and deduplicates in-flight requests',async () => {
    const request=vi.fn().mockResolvedValue(new Response(JSON.stringify([place])));
    const provider=new NominatimAddressProvider('https://geocode.example.test','MoveTraq fixture contact',request,0);
    const [first,second]=await Promise.all([provider.search('Fixture street'),provider.search('Fixture street')]);
    expect(first).toEqual(second);
    expect(first[0]).toMatchObject({latitude:6.5,longitude:3.4,source:'osm',placeId:'osm:123'});
    expect(await provider.search('Fixture street')).toEqual(first);
    expect(request).toHaveBeenCalledTimes(1);
    expect(request.mock.calls[0][1].headers).toMatchObject({'User-Agent':'MoveTraq fixture contact'});
  });
  it('preserves selected coordinates during reverse lookup and validates provider results',async () => {
    const request=vi.fn().mockResolvedValueOnce(new Response(JSON.stringify(place)))
      .mockResolvedValueOnce(new Response(JSON.stringify({error:'Not found'})))
      .mockResolvedValueOnce(new Response(JSON.stringify([{...place,lat:'100'}])));
    const provider=new NominatimAddressProvider('https://geocode.example.test','MoveTraq fixture contact',request,0);
    expect(await provider.reverse({latitude:6.51,longitude:3.41})).toMatchObject({latitude:6.51,longitude:3.41});
    await expect(provider.reverse({latitude:0,longitude:0})).rejects.toMatchObject({status:422});
    await expect(provider.search('Invalid coordinates')).rejects.toMatchObject({status:503});
  });
  it('serializes distinct provider requests and hides provider failures',async () => {
    let active=0;let concurrent=0;
    const request=vi.fn(async () => {
      active++;concurrent=Math.max(concurrent,active);
      await new Promise(resolve => setTimeout(resolve,5));active--;
      return new Response(JSON.stringify([place]));
    });
    const provider=new NominatimAddressProvider('https://geocode.example.test','MoveTraq fixture contact',request,0);
    await Promise.all([provider.search('First search'),provider.search('Second search')]);
    expect(concurrent).toBe(1);
    const failed=new NominatimAddressProvider('https://geocode.example.test','MoveTraq fixture contact',vi.fn().mockRejectedValue(new Error('private-provider-detail')),0);
    await expect(failed.search('Third search')).rejects.toMatchObject({status:503,message:'Address lookup is temporarily unavailable.'});
  });
  it('reports only the upstream status when the hosted provider refuses a request',async () => {
    const provider=new NominatimAddressProvider('https://geocode.example.test','MoveTraq fixture contact',
      vi.fn().mockResolvedValue(new Response('private upstream response',{status:403})),0);
    await expect(provider.search('Fixture search')).rejects.toMatchObject({
      status:503,details:{provider:'nominatim',upstreamStatus:403},message:'Address lookup is temporarily unavailable.'});
  });
});
describe('OSRM road routing', () => {
  it('uses longitude first and returns actual road geometry and rounded metrics',async () => {
    const request=vi.fn().mockResolvedValue(new Response(JSON.stringify({code:'Ok',routes:[{
      distance:1200.4,duration:90.1,geometry:{type:'LineString',coordinates:[[3.4,6.5],[3.5,6.6]]},
    }]})));
    const route=await new OsrmMapService('https://routing.example.test',request).route({latitude:6.5,longitude:3.4},{latitude:6.6,longitude:3.5});
    expect(route).toEqual({distanceMeters:1201,durationSeconds:91,points:[{latitude:6.5,longitude:3.4},{latitude:6.6,longitude:3.5}]});
    expect(request.mock.calls[0][0].href).toContain('/route/v1/driving/3.4,6.5;3.5,6.6?');
  });
  it('never substitutes a straight line for a missing road route',async () => {
    const request=vi.fn().mockResolvedValue(new Response(JSON.stringify({code:'NoRoute'})));
    await expect(new OsrmMapService('https://routing.example.test',request).route({latitude:6,longitude:3},{latitude:7,longitude:4}))
      .rejects.toMatchObject({status:422,code:'NO_ROAD_ROUTE'});
  });
});
describe('Photon OSM geocoding', () => {
  const feature={geometry:{type:'Point',coordinates:[3.4,6.5]},properties:{osm_id:123,osm_type:'N',name:'Fixture',street:'Fixture street',city:'Lagos',country:'Nigeria'}};
  it('normalizes and caches real provider results without losing OSM identity',async () => {
    const request=vi.fn().mockResolvedValue(new Response(JSON.stringify({type:'FeatureCollection',features:[feature]})));
    const provider=new PhotonAddressProvider('https://photon.example.test','MoveTraq fixture contact',request,0);
    const result=await provider.search('Fixture Lagos');
    expect(result[0]).toMatchObject({latitude:6.5,longitude:3.4,source:'osm',placeId:'osm:N:123',address:'Fixture, Fixture street, Lagos, Nigeria'});
    expect(await provider.search('Fixture Lagos')).toEqual(result);expect(request).toHaveBeenCalledTimes(1);
    expect(request.mock.calls[0][0].pathname).toBe('/api/');
  });
  it('keeps the selected reverse-lookup coordinates and reports empty results',async () => {
    const request=vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({type:'FeatureCollection',features:[feature]})))
      .mockResolvedValueOnce(new Response(JSON.stringify({type:'FeatureCollection',features:[]})));
    const provider=new PhotonAddressProvider('https://photon.example.test','MoveTraq fixture contact',request,0);
    expect(await provider.reverse({latitude:6.51,longitude:3.41})).toMatchObject({latitude:6.51,longitude:3.41});
    await expect(provider.reverse({latitude:0,longitude:0})).rejects.toMatchObject({status:422,code:'ADDRESS_NOT_FOUND'});
  });
  it('rejects malformed coordinates rather than inventing a place',async () => {
    const request=vi.fn().mockResolvedValue(new Response(JSON.stringify({type:'FeatureCollection',features:[{...feature,geometry:{type:'Point',coordinates:[181,6]}}]})));
    await expect(new PhotonAddressProvider('https://photon.example.test','MoveTraq fixture contact',request,0).search('Fixture Lagos')).rejects.toMatchObject({status:503});
  });
});
