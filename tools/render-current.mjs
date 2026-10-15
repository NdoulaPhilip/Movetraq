// Current Supabase backend/admin only. Default is read-only; --deploy provisions free services.
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import dotenv from '../backend/node_modules/dotenv/lib/main.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const env = dotenv.parse(fs.readFileSync(`${root}backend/.env`));
const repo = 'https://github.com/NdoulaPhilip/Movetraq';
const normalize = value => value?.replace(/\.git$/, '').replace(/\/$/, '').toLowerCase();
if (!env.RENDER_API_KEY || !env.RENDER_SERVICE_ID) throw new Error('Render credentials and the existing service ID are required.');
if (normalize(execFileSync('git', ['remote', 'get-url', 'origin'], { cwd: root, encoding: 'utf8' }).trim()) !== normalize(repo)) {
  throw new Error('Git repository does not match the approved deployment destination.');
}
async function api(path, method = 'GET', body) {
  const response = await fetch(`https://api.render.com/v1${path}`, {
    method, headers: { Authorization: `Bearer ${env.RENDER_API_KEY}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body), redirect: 'error', signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`Render ${method} request failed (${response.status}); response body withheld to protect credentials.`);
  const text = await response.text();
  return text.trim() ? JSON.parse(text) : null;
}
async function services() {
  let cursor; const result = [];
  do {
    const page = await api(`/services?limit=100${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
    result.push(...page.map(item => item.service));
    cursor = page.length === 100 ? page.at(-1).cursor : undefined;
  } while (cursor);
  return result;
}
const anchor = await api(`/services/${encodeURIComponent(env.RENDER_SERVICE_ID)}`);
if (normalize(anchor.repo) !== normalize(repo) || !anchor.ownerId) throw new Error('Existing Render service does not belong to the approved repository.');
const all = await services();
const names = ['movetraq-production-api', 'movetraq-production-admin'];
async function verifyPublic() {
  const [backend, admin] = names.map(name => all.find(s => s.ownerId === anchor.ownerId && s.name === name && normalize(s.repo) === normalize(repo)));
  if (!backend || !admin) throw new Error('Both approved services must exist before verification.');
  const apiUrl = backend.serviceDetails.url;
  const adminUrl = admin.serviceDetails.url;
  const request = (url, options = {}) => fetch(url, { ...options, redirect: 'error', signal: AbortSignal.timeout(60000) });
  const check = (condition, message) => { if (!condition) throw new Error(message); };
  const health = await request(`${apiUrl}/health`);
  check(health.ok && (await health.json()).data?.service === 'movetraq-backend', 'API health check failed.');
  const protectedResponse = await request(`${apiUrl}/api/v1/users/me`, { headers: { Origin: adminUrl } });
  check(protectedResponse.status === 401, 'Account API did not reject an unauthenticated request.');
  check(protectedResponse.headers.get('access-control-allow-origin') === adminUrl, 'Admin CORS origin does not match.');
  await protectedResponse.body?.cancel();
  const preflight = await request(`${apiUrl}/api/v1/auth/signin`, { method: 'OPTIONS', headers: {
    Origin: adminUrl, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type',
  } });
  check(preflight.ok && preflight.headers.get('access-control-allow-origin') === adminUrl, 'Admin sign-in preflight failed.');
  const page = await request(adminUrl);
  check(page.ok, 'Admin website did not respond successfully.');
  const html = await page.text();
  check(html.includes('<title>MoveTraq Admin</title>'), 'Unexpected admin HTML.');
  const script = html.match(/<script[^>]*src="([^"]+\.js)"/);
  check(!!script, 'Admin JavaScript asset is missing.');
  const assetUrl = new URL(script[1], adminUrl);
  check(assetUrl.origin === new URL(adminUrl).origin, 'Unexpected admin asset origin.');
  const asset = await request(assetUrl);
  check(asset.ok, 'Admin JavaScript asset did not load.');
  const js = await asset.text();
  check(js.includes(`${apiUrl}/api/v1`), 'Admin bundle does not use the deployed API.');
  check(!['RENDER_API_KEY', 'SUPABASE_SERVICE_ROLE_KEY', 'PAYMENT_SECRET_KEY'].some(key => env[key]?.length > 12 && js.includes(env[key])),
    'A server credential was found in the admin bundle.');
  const invitation = await request(`${adminUrl}/accept-invitation`);
  check(invitation.ok && (await invitation.text()).includes('<title>MoveTraq Admin</title>'), 'Admin SPA rewrite failed.');
  console.log(JSON.stringify({ apiUrl, adminUrl, health: 'passed', accountAuthorization: 'passed', cors: 'passed',
    signInPreflight: 'passed', adminAsset: 'passed', apiBundleUrl: 'passed', noBundledServerSecrets: 'passed', spaRewrite: 'passed' }));
}
if (!process.argv.includes('--deploy')) {
  for (const service of all.filter(s => s.ownerId === anchor.ownerId && names.includes(s.name) && normalize(s.repo) === normalize(repo))) {
    const history = await api(`/services/${service.id}/deploys?limit=1`);
    console.log(JSON.stringify({ name: service.name, id: service.id, url: service.serviceDetails?.url,
      deploys: history.map(item => ({ id: item.deploy.id, status: item.deploy.status, commit: item.deploy.commit?.id })) }));
  }
  if (process.argv.includes('--verify')) await verifyPublic();
} else {
  for (const key of ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY']) {
    if (!env[key]?.trim()) throw new Error(`${key} is required.`);
  }
  if (env.SUPABASE_URL !== 'https://qdvfdvdsdkllsdlepfke.supabase.co') throw new Error('Unexpected Supabase project.');
  const pairs = values => Object.entries(values).map(([key, value]) => ({ key, value }));
  async function ensure(name, type, rootDir, details, values) {
    const existing = all.find(s => s.ownerId === anchor.ownerId && s.name === name);
    if (existing) {
      if (normalize(existing.repo) !== normalize(repo) || existing.type !== type || (existing.rootDir || '') !== rootDir) {
        throw new Error(`${name} exists with an unexpected repository, type or root; no settings changed.`);
      }
      return existing;
    }
    const result = await api('/services', 'POST', { name, type, ownerId: anchor.ownerId, repo, branch: 'main',
      rootDir, autoDeployTrigger: 'commit', envVars: pairs(values), serviceDetails: details });
    console.log(JSON.stringify({ created: name, id: result.service.id, initialDeploy: result.deployId }));
    return result.service;
  }
  const apiValues = { NODE_VERSION: '24', NODE_ENV: 'production', TRUST_PROXY_HOPS: '1', LOG_LEVEL: 'info',
    SUPABASE_URL: env.SUPABASE_URL, SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY,
    SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY,
    CORS_ORIGINS: 'https://deployment-pending.invalid', PAYMENT_PROVIDER: 'paystack',
    ...Object.fromEntries(['PAYMENT_SECRET_KEY', 'PAYMENT_CALLBACK_URL', 'GOOGLE_MAPS_API_KEY', 'GOOGLE_PLACES_API_KEY',
      'GOOGLE_GEOCODING_API_KEY', 'AUTH_REDIRECT_URL'].filter(key => env[key]?.trim()).map(key => [key, env[key].trim()])),
  };
  const backend = await ensure(names[0], 'web_service', 'backend', {
    runtime: 'node', plan: 'free', region: anchor.serviceDetails?.region || 'oregon', healthCheckPath: '/health',
    envSpecificDetails: { buildCommand: 'npm ci --include=dev && npm run build', startCommand: 'npm start' },
  }, apiValues);
  const apiUrl = backend.serviceDetails?.url;
  if (!apiUrl?.startsWith('https://')) throw new Error('Render did not return a public HTTPS API URL.');
  const adminValues = { NODE_VERSION: '24', VITE_API_URL: `${apiUrl}/api/v1` };
  const admin = await ensure(names[1], 'static_site', '', {
    buildCommand: 'cd admin && npm ci --include=dev && npm run build', publishPath: 'admin/dist',
    routes: [{ type: 'rewrite', source: '/*', destination: '/index.html' }],
  }, adminValues);
  const adminUrl = admin.serviceDetails?.url;
  if (!adminUrl?.startsWith('https://')) throw new Error('Render did not return a public HTTPS admin URL.');
  apiValues.CORS_ORIGINS = adminUrl;
  apiValues.ADMIN_INVITE_REDIRECT_URL = `${adminUrl}/accept-invitation`;
  const state = { api: { id: backend.id, url: apiUrl }, admin: { id: admin.id, url: adminUrl } };
  fs.writeFileSync(`${root}backend/.env.current-render-state.json`, JSON.stringify(state, null, 2));
  for (const [service, values] of [[backend, apiValues], [admin, adminValues]]) {
    for (const [key, value] of Object.entries(values)) await api(`/services/${service.id}/env-vars/${key}`, 'PUT', { value });
    const deploy = await api(`/services/${service.id}/deploys`, 'POST', { clearCache: 'do_not_clear' });
    console.log(JSON.stringify({ name: service.name, id: service.id, url: service.serviceDetails.url,
      deployId: deploy?.id, status: deploy?.status ?? 'accepted_status_pending' }));
  }
}
