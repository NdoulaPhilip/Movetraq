import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { createServer } from 'node:net';
import { fileURLToPath } from 'node:url';

const reservation = createServer();
reservation.listen(0, '127.0.0.1');
await once(reservation, 'listening');
const port = reservation.address().port;
await new Promise((resolve) => reservation.close(resolve));

const child = spawn(process.execPath, ['dist/server.js'], {
  cwd: fileURLToPath(new URL('../', import.meta.url)), windowsHide: true,
  env: { ...process.env, NODE_ENV: 'test', PORT: String(port), LOG_LEVEL: 'silent',
    SUPABASE_URL: 'http://127.0.0.1:54321', SUPABASE_ANON_KEY: 'smoke-test-anon',
    SUPABASE_SERVICE_ROLE_KEY: 'smoke-test-service', PAYMENT_SECRET_KEY: '', TRUST_PROXY_HOPS: '0' },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let stderr = '';
child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
try {
  let response;
  for (let attempt = 0; attempt < 30; attempt++) {
    if (child.exitCode !== null) throw new Error(`Built server exited early: ${stderr}`);
    try { response = await fetch(`http://127.0.0.1:${port}/health`, { signal: AbortSignal.timeout(1000) }); }
    catch { await new Promise((resolve) => setTimeout(resolve, 200)); continue; }
    break;
  }
  assert(response, `Built server did not start: ${stderr}`);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).data.status, 'healthy');
  const protectedResponse = await fetch(`http://127.0.0.1:${port}/api/v1/users/me`);
  assert.equal(protectedResponse.status, 401);
  console.log('PASS: compiled server starts, health responds, and account API requires authentication.');
} finally {
  if (child.exitCode === null) {
    child.kill();
    await once(child, 'exit');
  }
}
