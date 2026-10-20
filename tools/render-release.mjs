// Deploy the three existing MoveTraq services without changing hosted configuration.
// Usage: node tools/render-release.mjs [inspect|deploy|verify]
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import dotenv from '../backend/node_modules/dotenv/lib/main.js';
const root = fileURLToPath(new URL('../', import.meta.url));
const env = dotenv.parse(fs.readFileSync(`${root}backend/.env`));
const git = (...args) => execFileSync('git', args, {cwd: root, encoding: 'utf8'}).trim();
const repo = 'https://github.com/NdoulaPhilip/Movetraq';
const normalize = value => value?.replace(/\.git$/, '').replace(/\/$/, '').toLowerCase();
if (normalize(git('remote', 'get-url', 'origin')) !== normalize(repo)) throw new Error('Unexpected deployment repository.');
if (!env.RENDER_API_KEY) throw new Error('Saved Render access is required.');
async function api(path, method = 'GET', body) {
  const response = await fetch(`https://api.render.com/v1${path}`, {
    method, redirect: 'error', signal: AbortSignal.timeout(30000),
    headers: {Authorization: `Bearer ${env.RENDER_API_KEY}`, 'Content-Type': 'application/json'},
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`Render ${method} failed (${response.status}); response withheld.`);
  return response.json();
}
const specs = [
  {name: 'movetraq-production-api', root: 'backend', type: 'web_service'},
  {name: 'movetraq-api', root: 'server', type: 'web_service'},
  {name: 'movetraq-production-admin', root: '', type: 'static_site'},
];
let cursor;
const all = [];
do {
  const page = await api(`/services?limit=100${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
  all.push(...page.map(item => item.service));
  cursor = page.length === 100 ? page.at(-1).cursor : undefined;
} while (cursor);
const services = specs.map(spec => {
  const matches = all.filter(service => service.name === spec.name && normalize(service.repo) === normalize(repo));
  if (matches.length !== 1) throw new Error(`Expected exactly one ${spec.name} service.`);
  const service = matches[0];
  if (service.type !== spec.type || (service.rootDir || '') !== spec.root || service.branch !== 'main' ||
      service.suspended === 'suspended' || !service.serviceDetails?.url?.startsWith('https://')) {
    throw new Error(`Unexpected configuration for ${spec.name}; nothing changed.`);
  }
  return service;
});
if (new Set(services.map(service => service.ownerId)).size !== 1) throw new Error('Services belong to different workspaces.');
const mode = process.argv[2] || 'inspect';
if (!['inspect', 'deploy', 'verify'].includes(mode)) throw new Error('Choose inspect, deploy or verify.');
let commit;
if (mode === 'deploy') {
  if (git('status', '--porcelain')) throw new Error('Commit the reviewed source before deploying.');
  commit = git('rev-parse', 'HEAD');
  if (git('ls-remote', 'origin', 'refs/heads/main').split(/\s/)[0] !== commit) throw new Error('Publish this exact commit to origin/main first.');
  // Schema-dependent services must never be rolled out before their additive migration.
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) throw new Error('Supabase schema verification is required before deployment.');
  const schema = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/mobile_verification_notifications`, {
    method:'POST',redirect:'error',signal:AbortSignal.timeout(30000),
    headers:{apikey:env.SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json'},
    body:JSON.stringify({p_user:'user_deployment_probe'}),
  });
  await schema.body?.cancel();
  if (!schema.ok) throw new Error('Apply Supabase migrations 0017 and 0018 before deploying the approval workflow. No deployment triggered.');
}
for (const service of services) {
  const history = await api(`/services/${service.id}/deploys?limit=3`);
  if (mode === 'deploy') {
    const existing = history.map(item => item.deploy).find(deploy => deploy.commit?.id === commit &&
        ['created', 'build_in_progress', 'update_in_progress', 'pre_deploy_in_progress', 'queued', 'live'].includes(deploy.status));
    const deploy = existing || await api(`/services/${service.id}/deploys`, 'POST', {commitId: commit, clearCache: 'do_not_clear'});
    console.log(JSON.stringify({name: service.name, url: service.serviceDetails.url, deployId: deploy.id,
        status: deploy.status, commit, reused: !!existing}));
  } else {
    console.log(JSON.stringify({name: service.name, id: service.id, url: service.serviceDetails.url,
      deploys: history.map(({deploy}) => ({id: deploy.id, status: deploy.status, commit: deploy.commit?.id}))}));
  }
  if (mode === 'verify') {
    if (!history.some(({deploy}) => deploy.status === 'live' && deploy.commit?.id === git('rev-parse', 'HEAD'))) {
      throw new Error(`${service.name} is not yet live on the release commit.`);
    }
    const url = service.serviceDetails.url + (service.type === 'web_service' ? '/health' : '');
    const response = await fetch(url, {redirect: 'error', signal: AbortSignal.timeout(60000)});
    await response.body?.cancel();
    if (!response.ok) throw new Error(`${service.name} health failed (${response.status}).`);
    console.log(JSON.stringify({name: service.name, health: 'passed', httpStatus: response.status}));
  }
}
