// Deploy the existing mobile/maps APIs only. Never logs credential values.
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import dotenv from '../backend/node_modules/dotenv/lib/main.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const envFile = `${root}backend/.env`;
const local = dotenv.parse(fs.readFileSync(envFile));
const repo = 'https://github.com/NdoulaPhilip/Movetraq';
const specs = {
  backend: {id:'srv-db8as06q1p3s73a7g03g',name:'movetraq-production-api',root:'backend'},
  mobile: {id:'srv-dapuig6gekts73f94a6g',name:'movetraq-api',root:'server'},
};
const normal = value => value?.replace(/\.git$/,'').replace(/\/$/,'').toLowerCase();
if (!local.RENDER_API_KEY) throw new Error('Saved Render access is required.');
if (normal(execFileSync('git',['remote','get-url','origin'],{cwd:root,encoding:'utf8'}).trim()) !== normal(repo)) {
  throw new Error('Unexpected deployment repository.');
}
async function api(path, method='GET', body) {
  const response = await fetch(`https://api.render.com/v1${path}`,{
    method,headers:{Authorization:`Bearer ${local.RENDER_API_KEY}`,'Content-Type':'application/json'},
    body:body === undefined ? undefined : JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`Render ${method} failed (${response.status}); response withheld.`);
  const text = await response.text();
  return text.trim() ? JSON.parse(text) : null;
}
async function variables(id) {
  const result = {}; let cursor;
  do {
    const page = await api(`/services/${id}/env-vars?limit=100${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
    for (const {envVar} of page) result[envVar.key] = envVar.value;
    cursor = page.length === 100 ? page.at(-1).cursor : undefined;
  } while (cursor);
  return result;
}
const services = {};
for (const [label,spec] of Object.entries(specs)) {
  const service = await api(`/services/${spec.id}`);
  if (service.name !== spec.name || service.type !== 'web_service' || service.rootDir !== spec.root ||
      normal(service.repo) !== normal(repo) || service.branch !== 'main' || service.suspended === 'suspended') {
    throw new Error(`Unexpected ${label} service configuration; nothing changed.`);
  }
  if (!service.serviceDetails?.url?.startsWith('https://')) throw new Error(`Missing ${label} HTTPS origin.`);
  services[label] = {...service,values:await variables(spec.id)};
}
if (services.backend.ownerId !== services.mobile.ownerId) throw new Error('The two APIs belong to different Render workspaces.');

async function databaseCheck() {
  const values = services.backend.values;
  if (!values.SUPABASE_URL || !values.SUPABASE_SERVICE_ROLE_KEY) throw new Error('Hosted database configuration is missing.');
  if (local.SUPABASE_URL && values.SUPABASE_URL !== local.SUPABASE_URL) throw new Error('Hosted database differs from the local project.');
  for (const [command,body] of [
    ['mobile_deliverer_command',{p_user:'user_deployment_probe',p_command:'status',p_input:{}}],
    ['mobile_location_command',{p_user:'user_deployment_probe',p_command:'addresses',p_input:{}}],
  ]) {
    const response = await fetch(`${values.SUPABASE_URL}/rest/v1/rpc/${command}`,{method:'POST',
      headers:{apikey:values.SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${values.SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json'},
      body:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(30000)});
    if (!response.ok) throw new Error(`Hosted migration check ${command} failed (${response.status}); no migrations applied.`);
    await response.body?.cancel();
  }
  console.log(JSON.stringify({hostedMigrations:'0015 and 0016 verified',databaseWrites:'none'}));
}
const token = services.backend.values.MONITORING_SERVICE_TOKEN || services.mobile.values.MONITORING_SERVICE_TOKEN ||
  local.MONITORING_SERVICE_TOKEN || randomBytes(32).toString('hex');
if (token.length < 32) throw new Error('The existing bridge token must be at least 32 characters.');
const desired = {
  backend:{MAPS_PROVIDER:'osm',GEOCODER_PROVIDER:local.GEOCODER_PROVIDER || 'photon',
    PHOTON_URL:local.PHOTON_URL || 'https://photon.komoot.io',OSRM_URL:local.OSRM_URL || 'https://router.project-osrm.org',
    NOMINATIM_URL:local.NOMINATIM_URL || 'https://nominatim.openstreetmap.org',
    MAPS_USER_AGENT:local.MAPS_USER_AGENT || 'MoveTraq/1.0 (https://github.com/NdoulaPhilip/Movetraq)',
    MONITORING_SERVICE_TOKEN:token,MOBILE_MONITORING_URL:services.mobile.serviceDetails.url},
  mobile:{MONITORING_SERVICE_TOKEN:token,DELIVERER_AUTHORITY_URL:services.backend.serviceDetails.url},
};
const mode = process.argv[2] || 'inspect';
const target = process.argv[3];
if (mode === 'inspect' || mode === 'configure') {
  await databaseCheck();
  for (const [label,service] of Object.entries(services)) {
    const history = await api(`/services/${service.id}/deploys?limit=1`);
    const changes = Object.keys(desired[label]).filter(key => service.values[key] !== desired[label][key]);
    console.log(JSON.stringify({service:label,id:service.id,url:service.serviceDetails.url,
      latest:history.map(({deploy}) => ({id:deploy.id,status:deploy.status,commit:deploy.commit?.id})),
      environmentKeysToUpdate:changes}));
    if (mode === 'configure') {
      for (const key of changes) await api(`/services/${service.id}/env-vars/${key}`,'PUT',{value:desired[label][key]});
      console.log(JSON.stringify({configured:label,changedKeys:changes}));
    }
  }
  if (mode === 'configure' && local.MONITORING_SERVICE_TOKEN !== token) {
    const source = fs.readFileSync(envFile,'utf8');
    fs.writeFileSync(envFile,/^MONITORING_SERVICE_TOKEN=.*$/m.test(source)
      ? source.replace(/^MONITORING_SERVICE_TOKEN=.*$/m,`MONITORING_SERVICE_TOKEN=${token}`)
      : `${source}\nMONITORING_SERVICE_TOKEN=${token}\n`);
  }
} else if (mode === 'deploy') {
  if (!services[target]) throw new Error('Choose backend or mobile.');
  const commit = execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim();
  const remote = execFileSync('git',['ls-remote','origin','refs/heads/main'],{cwd:root,encoding:'utf8'}).trim().split(/\s/)[0];
  if (remote !== commit) throw new Error('Publish this exact commit to main before deployment.');
  const deploy = await api(`/services/${services[target].id}/deploys`,'POST',{commitId:commit,clearCache:'do_not_clear'});
  console.log(JSON.stringify({service:target,deployId:deploy.id,status:deploy.status,commit:deploy.commit?.id || commit}));
} else if (mode === 'status') {
  for (const [label,service] of Object.entries(services)) {
    const history = await api(`/services/${service.id}/deploys?limit=2`);
    console.log(JSON.stringify({service:label,deploys:history.map(({deploy}) => ({id:deploy.id,status:deploy.status,commit:deploy.commit?.id}))}));
  }
} else if (mode === 'verify') {
  await databaseCheck();
  const backend = services.backend;
  const request = (url,options={}) => fetch(url,{...options,redirect:'error',signal:AbortSignal.timeout(60000)});
  for (const [label,service] of Object.entries(services)) {
    const response = await request(`${service.serviceDetails.url}/health`);
    if (!response.ok) throw new Error(`${label} health failed (${response.status}).`);
    await response.body?.cancel();
    console.log(JSON.stringify({service:label,health:'passed'}));
  }
  const db = await request(`${services.mobile.serviceDetails.url}/health/db`);
  if (!db.ok) throw new Error(`Mobile database health failed (${db.status}).`);
  await db.body?.cancel();
  const unauthorized = await request(`${backend.serviceDetails.url}/internal/mobile-maps`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({userId:'user_deployment_probe',command:'addresses'})});
  if (unauthorized.status !== 401) throw new Error('Maps service authentication check failed.');
  await unauthorized.body?.cancel();
  for (const [command,input] of [['addresses',{}],['search',{query:'Ikeja Lagos'}],
    ['reverse',{latitude:6.6018,longitude:3.3515}],
    ['route',{pickup:{latitude:6.6018,longitude:3.3515},destination:{latitude:6.6173,longitude:3.3581}}]]) {
    const response = await request(`${backend.serviceDetails.url}/internal/mobile-maps`,{method:'POST',
      headers:{Authorization:`Bearer ${backend.values.MONITORING_SERVICE_TOKEN}`,'Content-Type':'application/json'},
      body:JSON.stringify({userId:'user_deployment_probe',command,input})});
    if (!response.ok) throw new Error(`Live ${command} failed (${response.status}); response withheld.`);
    const result = await response.json();
    if (!result.success || !result.data) throw new Error(`Invalid live ${command} response.`);
    if (command === 'search' && !result.data.suggestions?.length) throw new Error('Live search returned no places.');
    if (command === 'route' && !(result.data.points?.length > 1 && result.data.distanceMeters > 0)) throw new Error('Live road geometry is missing.');
    console.log(JSON.stringify({command,result:'passed',...(command === 'route' ? {
      distanceMeters:result.data.distanceMeters,durationSeconds:result.data.durationSeconds,roadPoints:result.data.points.length}: {})}));
  }
  const protectedMobile = await request(`${services.mobile.serviceDetails.url}/places/autocomplete?q=Ikeja`);
  if (protectedMobile.status !== 401) throw new Error('Mobile location endpoint authentication check failed.');
  await protectedMobile.body?.cancel();
  console.log(JSON.stringify({mobileDatabase:'passed',mapsServiceAuthorization:'passed',mobileAuthorization:'passed',
    bridgeTokensMatch:services.backend.values.MONITORING_SERVICE_TOKEN === services.mobile.values.MONITORING_SERVICE_TOKEN}));
} else throw new Error('Choose inspect, configure, deploy, status or verify.');
