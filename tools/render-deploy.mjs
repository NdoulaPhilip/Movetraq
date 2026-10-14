// Usage: node tools/render-deploy.mjs [--deploy]. Default is read-only status.
// Credentials are loaded from ignored backend/.env and never printed.
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import dotenv from '../backend/node_modules/dotenv/lib/main.js';
const root = fileURLToPath(new URL('../', import.meta.url));
const env = {...dotenv.parse(fs.readFileSync(`${root}backend/.env`)), ...process.env};
const repo = 'https://github.com/AlepsGitHub/MoveTraq';
if (!env.RENDER_API_KEY) throw new Error('Save RENDER_API_KEY in backend/.env first.');
function redact(message) {
  for (const value of Object.values(env)) if (typeof value === 'string' && value.length > 10) message = message.replaceAll(value, '[redacted]');
  return message;
}
async function api(path, method = 'GET', body) {
  const response = await fetch(`https://api.render.com/v1${path}`, {
    method, headers: {Authorization: `Bearer ${env.RENDER_API_KEY}`, 'Content-Type': 'application/json'},
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(30000),
  });
  const text = await response.text();
  if (!response.ok) throw new Error(redact(`Render ${method} ${path}: ${response.status} ${text}`));
  return text ? JSON.parse(text) : null;
}
async function list(path, itemKey) {
  let cursor, result = [];
  do {
    const page = await api(`${path}${path.includes('?') ? '&' : '?'}limit=100${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
    result.push(...page.map(item => item[itemKey]));
    cursor = page.length === 100 ? page.at(-1).cursor : undefined;
  } while (cursor);
  return result;
}
async function main() {
const services = await list('/services', 'service');
const ours = services.filter(service => service.repo?.replace(/\.git$/, '').toLowerCase() === repo.toLowerCase());
if (!process.argv.includes('--deploy')) {
  console.log(JSON.stringify({services: ours.map(s => ({id:s.id,name:s.name,url:s.serviceDetails?.url}))}));
  for (const service of ours) {
    const deployments = await api(`/services/${service.id}/deploys?limit=1`);
    console.log(JSON.stringify({name:service.name,deployments:deployments.map(x => ({id:x.deploy.id,status:x.deploy.status,commit:x.deploy.commit?.id}))}));
    if (process.argv.includes('--logs') && service.type === 'web_service') {
      const logs = await api(`/logs?ownerId=${service.ownerId}&resource=${service.id}&type=build&limit=40`);
      console.log(redact(JSON.stringify({name:service.name,logs:logs.logs?.map(x => x.message)})));
    }
  }
  return;
}
for (const key of ['DATABASE_URL','DATABASE_CA_CERT_BASE64','SUPABASE_URL','SUPABASE_ANON_KEY','SUPABASE_SERVICE_ROLE_KEY','DATA_ENCRYPTION_KEY']) {
  if (!env[key]?.trim()) throw new Error(`${key} is required before deployment.`);
}
const owners = await list('/owners', 'owner');
const ownerId = env.RENDER_OWNER_ID || (owners.length === 1 ? owners[0].id : undefined);
if (!ownerId || !owners.some(o => o.id === ownerId)) {
  console.log(JSON.stringify({workspaces:owners.map(o => ({id:o.id,name:o.name}))}));
  throw new Error('Choose the workspace by saving RENDER_OWNER_ID in backend/.env.');
}
const pairs = values => Object.entries(values).map(([key,value]) => ({key,value}));
async function ensure(name, type, serviceDetails, values) {
  const existing = services.find(s => s.name === name && s.ownerId === ownerId);
  if (existing) {
    if (!ours.some(s => s.id === existing.id)) throw new Error(`${name} exists but belongs to a different repository.`);
    return api(`/services/${existing.id}`,'PATCH',{serviceDetails});
  }
  const created = await api('/services','POST',{
    name,type,ownerId,repo,branch:'main',autoDeployTrigger:'off',envVars:pairs(values),serviceDetails,
  });
  console.log(JSON.stringify({created:name,id:created.service.id,deployId:created.deployId}));
  return created.service;
}
const apiValues = {
  NODE_VERSION:'24',NODE_ENV:'production',DATABASE_TLS:'true',
  ...Object.fromEntries(['DATABASE_URL','DATABASE_CA_CERT_BASE64','SUPABASE_URL','SUPABASE_ANON_KEY','SUPABASE_SERVICE_ROLE_KEY','DATA_ENCRYPTION_KEY'].map(k => [k,env[k]])),
  CORS_ORIGINS:env.CORS_ORIGINS || 'http://localhost:5173',
  ...Object.fromEntries(['GOOGLE_ROUTES_API_KEY','GOOGLE_MAPS_API_KEY','ROUTING_PROVIDER','PAYSTACK_SECRET_KEY','PAYMENT_CALLBACK_URL'].filter(k => env[k]?.trim()).map(k => [k,env[k].trim()])),
};
const backend = await ensure('movetraq-api','web_service',{
  runtime:'node',plan:'free',region:'frankfurt',healthCheckPath:'/ready',
  envSpecificDetails:{buildCommand:'cd backend && npm ci --include=dev && npm run build',startCommand:'cd backend && npm start'},
},apiValues);
const apiUrl = backend.serviceDetails?.url;
if (!apiUrl) throw new Error('Render did not return an API URL; inspect its service before continuing.');
const adminValues = {NODE_VERSION:'24',VITE_API_URL:apiUrl,VITE_SUPABASE_URL:env.SUPABASE_URL,VITE_SUPABASE_ANON_KEY:env.SUPABASE_ANON_KEY};
const admin = await ensure('movetraq-admin','static_site',{
  buildCommand:'cd admin && npm ci --include=dev && npm run build',publishPath:'admin/dist',
  routes:[{type:'rewrite',source:'/*',destination:'/index.html'}],
},adminValues);
const adminUrl = admin.serviceDetails?.url;
if (!adminUrl) throw new Error('Render did not return an admin URL; inspect its service before continuing.');
apiValues.CORS_ORIGINS = adminUrl;
// Limit mutations to the expected variables on these two MoveTraq services.
for (const [service,values] of [[backend,apiValues],[admin,adminValues]]) {
  for (const [key,value] of Object.entries(values)) await api(`/services/${service.id}/env-vars/${key}`,'PUT',{value});
  const deployment = await api(`/services/${service.id}/deploys`,'POST',{clearCache:'do_not_clear'});
  console.log(JSON.stringify({name:service.name,id:service.id,url:service.serviceDetails.url,deployId:deployment?.id}));
}
fs.writeFileSync(`${root}backend/.env.render-state.json`,JSON.stringify({api:{id:backend.id,url:apiUrl},admin:{id:admin.id,url:adminUrl}},null,2));
console.log('Services submitted. Run without --deploy to monitor; verify API /ready before switching the mobile URL.');
}
await main();
