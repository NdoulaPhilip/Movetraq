const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { Pool } = require('pg');

function loadEnvFile() {
  const envPath = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(envPath)) return;

  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const separator = trimmed.indexOf('=');
    if (separator === -1) continue;

    const key = trimmed.slice(0, separator).trim();
    const value = trimmed.slice(separator + 1).trim().replace(/^["']|["']$/g, '');
    if (key && process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

loadEnvFile();

const port = Number(process.env.PORT || 3000);
const jwtSecret = process.env.JWT_SECRET || 'movetraq-local-secret';
const databaseUrl = process.env.DATABASE_URL || process.env.POSTGRES_URL || '';
const nodeEnv = process.env.NODE_ENV || 'development';
const isProduction = nodeEnv === 'production';
const accessTokenTtlSeconds = Number(process.env.ACCESS_TOKEN_TTL_SECONDS || 60 * 60 * 24 * 7);
const allowedOrigins = String(process.env.CORS_ORIGINS || '*')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const users = new Map();
const credentials = new Map();
const orders = new Map();
const messages = new Map();
const walletTransactions = new Map();
const notifications = new Map();
let pgPool = null;
let usePostgres = false;
const rateLimitBuckets = new Map();

async function connectPostgres() {
  if (!databaseUrl) {
    console.warn('DATABASE_URL is not set. Data will stay in memory and reset when the server restarts.');
    return;
  }

  pgPool = new Pool({
    connectionString: databaseUrl,
    ssl: databaseUrl.includes('localhost') || databaseUrl.includes('127.0.0.1')
      ? false
      : { rejectUnauthorized: false },
  });
  await pgPool.query(`
    CREATE TABLE IF NOT EXISTS users (
      uid TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS credentials (
      email TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS order_messages (
      order_id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS wallet_transactions (
      user_id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS notifications (
      user_id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  usePostgres = true;
  console.log('MoveTraq API connected to PostgreSQL');
}

async function loadStore() {
  if (!usePostgres) return;

  const [
    userRows,
    credentialRows,
    orderRows,
    messageRows,
    walletRows,
    notificationRows,
  ] = await Promise.all([
    pgPool.query('SELECT uid, data FROM users'),
    pgPool.query('SELECT email, password_hash FROM credentials'),
    pgPool.query('SELECT id, data FROM orders'),
    pgPool.query('SELECT order_id, data FROM order_messages'),
    pgPool.query('SELECT user_id, data FROM wallet_transactions'),
    pgPool.query('SELECT user_id, data FROM notifications'),
  ]);

  for (const row of userRows.rows) users.set(row.uid, row.data);
  for (const row of credentialRows.rows) credentials.set(row.email, row.password_hash);
  for (const row of orderRows.rows) orders.set(row.id, row.data);
  for (const row of messageRows.rows) messages.set(row.order_id, row.data);
  for (const row of walletRows.rows) walletTransactions.set(row.user_id, row.data);
  for (const row of notificationRows.rows) notifications.set(row.user_id, row.data);

  if (users.size === 0) {
    const legacy = await pgPool.query(`
      SELECT data
      FROM app_state
      WHERE id = 'movetraq-store'
        AND to_regclass('public.app_state') IS NOT NULL
      LIMIT 1
    `).catch(() => ({ rows: [] }));
    const store = legacy.rows[0]?.data;
    if (store) {
      for (const [key, item] of Object.entries(store.users || {})) users.set(key, item);
      for (const [key, item] of Object.entries(store.credentials || {})) credentials.set(key, item);
      for (const [key, item] of Object.entries(store.orders || {})) orders.set(key, item);
      for (const [key, item] of Object.entries(store.messages || {})) messages.set(key, item);
      for (const [key, item] of Object.entries(store.walletTransactions || {})) walletTransactions.set(key, item);
      for (const [key, item] of Object.entries(store.notifications || {})) notifications.set(key, item);
      await saveStore();
      console.log('MoveTraq API migrated legacy app_state data to PostgreSQL tables');
    }
  }
}

async function upsertJsonMap(client, table, keyColumn, map) {
  for (const [key, value] of map.entries()) {
    await client.query(
      `
        INSERT INTO ${table} (${keyColumn}, data, updated_at)
        VALUES ($1, $2::jsonb, NOW())
        ON CONFLICT (${keyColumn})
        DO UPDATE SET data = EXCLUDED.data, updated_at = NOW()
      `,
      [key, JSON.stringify(value)],
    );
  }
}

async function saveStore() {
  if (!usePostgres) return;

  const client = await pgPool.connect();
  try {
    await client.query('BEGIN');
    await upsertJsonMap(client, 'users', 'uid', users);
    for (const [email, passwordHash] of credentials.entries()) {
      const user = [...users.values()].find((item) => item.email.toLowerCase() === email);
      await client.query(
        `
          INSERT INTO credentials (email, user_id, password_hash, updated_at)
          VALUES ($1, $2, $3, NOW())
          ON CONFLICT (email)
          DO UPDATE SET user_id = EXCLUDED.user_id, password_hash = EXCLUDED.password_hash, updated_at = NOW()
        `,
        [email, user?.uid || '', passwordHash],
      );
    }
    await upsertJsonMap(client, 'orders', 'id', orders);
    await upsertJsonMap(client, 'order_messages', 'order_id', messages);
    await upsertJsonMap(client, 'wallet_transactions', 'user_id', walletTransactions);
    await upsertJsonMap(client, 'notifications', 'user_id', notifications);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

function now() {
  return new Date().toISOString();
}

function id(prefix) {
  return `${prefix}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
}

function json(res, status, body) {
  const origin = res.req?.headers?.origin;
  const allowOrigin =
    allowedOrigins.includes('*') || !origin || allowedOrigins.includes(origin)
      ? origin || '*'
      : allowedOrigins[0] || '*';
  res.writeHead(status, {
    'content-type': 'application/json',
    'access-control-allow-origin': allowOrigin,
    'access-control-allow-methods': 'GET,POST,PATCH,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization',
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'no-referrer',
    'cache-control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

function clientIp(req) {
  return String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown')
    .split(',')[0]
    .trim();
}

function rateLimit(req, res, key, limit, windowMs) {
  const bucketKey = `${key}:${clientIp(req)}`;
  const current = Date.now();
  const bucket = rateLimitBuckets.get(bucketKey);
  if (!bucket || bucket.resetAt <= current) {
    rateLimitBuckets.set(bucketKey, { count: 1, resetAt: current + windowMs });
    return true;
  }
  bucket.count += 1;
  if (bucket.count > limit) {
    json(res, 429, { error: 'Too many requests. Please try again shortly.' });
    return false;
  }
  return true;
}

function text(value, fallback = '', max = 240) {
  return String(value ?? fallback).trim().slice(0, max);
}

function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.pbkdf2Sync(password, salt, 100000, 32, 'sha256').toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  if (!stored || !stored.includes(':')) return false;
  const [salt, expected] = stored.split(':');
  const actual = hashPassword(password, salt).split(':')[1];
  if (actual.length !== expected.length) return false;
  return crypto.timingSafeEqual(Buffer.from(actual), Buffer.from(expected));
}

function base64url(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function signToken(userId) {
  const header = base64url({ alg: 'HS256', typ: 'JWT' });
  const issuedAt = Math.floor(Date.now() / 1000);
  const payload = base64url({
    sub: userId,
    iat: issuedAt,
    exp: issuedAt + accessTokenTtlSeconds,
  });
  const signature = crypto
    .createHmac('sha256', jwtSecret)
    .update(`${header}.${payload}`)
    .digest('base64url');
  return `${header}.${payload}.${signature}`;
}

function verifyToken(token) {
  if (!token) return null;
  const [header, payload, signature] = token.split('.');
  if (!header || !payload || !signature) return null;
  const expected = crypto
    .createHmac('sha256', jwtSecret)
    .update(`${header}.${payload}`)
    .digest('base64url');
  if (signature.length !== expected.length) return null;
  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
    return null;
  }
  let decoded;
  try {
    decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (decoded.exp && decoded.exp < Math.floor(Date.now() / 1000)) {
    return null;
  }
  return users.get(decoded.sub) || null;
}

function authUser(req) {
  const header = req.headers.authorization || '';
  return verifyToken(header.replace(/^Bearer\s+/i, ''));
}

function requireAuth(req, res) {
  const user = authUser(req);
  if (!user) {
    json(res, 401, { error: 'Please sign in first.' });
    return null;
  }
  return user;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 1_000_000) {
        req.destroy();
        reject(new Error('Request body is too large.'));
      }
    });
    req.on('end', () => {
      if (!body) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(new Error('Invalid JSON body.'));
      }
    });
  });
}

function visibleOrders(user) {
  simulateActiveLocations();

  return [...orders.values()]
    .filter((order) => {
      if (order.senderId === user.uid || order.delivererId === user.uid) {
        return true;
      }
      if (order.targetDelivererId) {
        return order.targetDelivererId === user.uid;
      }
      return order.status === 'pendingOffer';
    })
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

function simulateActiveLocations() {
  const baseLat = 6.5244;
  const baseLng = 3.3792;
  const tick = Date.now() / 30000;

  for (const order of orders.values()) {
    if (!['accepted', 'pickedUp'].includes(order.status)) continue;

    const seed = order.id
      .split('')
      .reduce((sum, char) => sum + char.charCodeAt(0), 0);
    const radius = order.status === 'pickedUp' ? 0.012 : 0.007;
    const angle = tick + seed;

    if (order.courierLocation && order.simulatedLocation === false) continue;

    order.courierLocation = {
      latitude: baseLat + Math.sin(angle) * radius,
      longitude: baseLng + Math.cos(angle) * radius,
    };
    order.simulatedLocation = true;
  }
}

function orderCode() {
  return `MT-${Math.floor(1000 + Math.random() * 9000)}`;
}

function tx(type, title, sub, amount) {
  return {
    id: id('tx'),
    type,
    title,
    sub,
    amount: Number(amount || 0),
    createdAt: now(),
  };
}

function notification(title, body, type = 'delivery') {
  return {
    id: id('notif'),
    title,
    body,
    type,
    read: false,
    createdAt: now(),
  };
}

function addWalletTransaction(userId, item, balanceDelta = 0) {
  const user = users.get(userId);
  if (!user) return [];

  const list = walletTransactions.get(userId) || [];
  list.push(item);
  walletTransactions.set(userId, list);
  user.walletBalance = Number(user.walletBalance || 0) + Number(balanceDelta || 0);
  users.set(userId, user);
  return list;
}

function addNotification(userId, item) {
  if (!users.has(userId)) return [];

  const list = notifications.get(userId) || [];
  list.push(item);
  notifications.set(userId, list);
  return list;
}

function addDeliveryEvent(order, type, actorId, note) {
  const list = Array.isArray(order.deliveryEvents) ? order.deliveryEvents : [];
  list.push({
    id: id('event'),
    type,
    actorId,
    note,
    createdAt: now(),
  });
  order.deliveryEvents = list;
  return list;
}

function readLocation(body) {
  const latitude = Number(body.latitude);
  const longitude = Number(body.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return {
    latitude,
    longitude,
    updatedAt: now(),
  };
}

const fallbackPlaces = [
  ['Ikeja City Mall', 'Obafemi Awolowo Way, Ikeja, Lagos', 6.6143, 3.3571],
  ['Computer Village', 'Otigba Street, Ikeja, Lagos', 6.5965, 3.3421],
  ['Murtala Muhammed Airport', 'Airport Road, Ikeja, Lagos', 6.5774, 3.3212],
  ['University of Lagos', 'Akoka, Yaba, Lagos', 6.5158, 3.3899],
  ['Yaba Bus Park', 'Yaba, Lagos', 6.5095, 3.3711],
  ['Lekki Phase 1', 'Admiralty Way, Lekki, Lagos', 6.4474, 3.4723],
  ['The Palms Shopping Mall', 'BIS Way, Lekki, Lagos', 6.4351, 3.4562],
  ['Victoria Island', 'Ahmadu Bello Way, Lagos', 6.4281, 3.4219],
  ['Eko Hotel and Suites', 'Adetokunbo Ademola Street, Victoria Island, Lagos', 6.4265, 3.4303],
  ['Ajah Market', 'Lekki-Epe Expressway, Ajah, Lagos', 6.4698, 3.5852],
  ['Maryland Mall', 'Ikorodu Road, Maryland, Lagos', 6.5721, 3.3673],
  ['Surulere Stadium', 'National Stadium, Surulere, Lagos', 6.4973, 3.3644],
];

function localPlaceSuggestions(query, limit = 6) {
  const needle = String(query || '').trim().toLowerCase();
  if (needle.length < 2) return [];
  return fallbackPlaces
    .filter(([name, address]) => `${name} ${address}`.toLowerCase().includes(needle))
    .slice(0, limit)
    .map(([name, address, latitude, longitude]) => ({
      id: `local-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
      name,
      address,
      latitude,
      longitude,
      source: 'local',
    }));
}

async function placeSuggestions(query) {
  const local = localPlaceSuggestions(query);
  if (String(query || '').trim().length < 3) return local;

  const url = new URL('https://nominatim.openstreetmap.org/search');
  url.searchParams.set('format', 'jsonv2');
  url.searchParams.set('addressdetails', '1');
  url.searchParams.set('limit', '6');
  url.searchParams.set('countrycodes', 'ng');
  url.searchParams.set('q', query);

  try {
    const response = await fetch(url, {
      headers: {
        'user-agent': 'MoveTraq/1.0 (address autocomplete)',
        accept: 'application/json',
      },
      signal: AbortSignal.timeout(3500),
    });
    if (!response.ok) return local;

    const items = await response.json();
    const remote = items.map((item) => {
      const address = item.address || {};
      const name =
        item.name ||
        address.road ||
        address.suburb ||
        address.city ||
        address.state ||
        item.display_name;
      return {
        id: `osm-${item.place_id}`,
        name,
        address: item.display_name,
        latitude: Number(item.lat),
        longitude: Number(item.lon),
        source: 'osm',
      };
    });
    return [...remote, ...local]
      .filter((item, index, all) => all.findIndex((other) => other.address === item.address) === index)
      .slice(0, 6);
  } catch {
    return local;
  }
}

function requireOrderAccess(user, order) {
  if (order.targetDelivererId) {
    return (
      order.senderId === user.uid ||
      order.delivererId === user.uid ||
      order.targetDelivererId === user.uid
    );
  }
  return (
    order.senderId === user.uid ||
    order.delivererId === user.uid ||
    order.status === 'pendingOffer' ||
    order.status === 'negotiating'
  );
}

const server = http.createServer(async (req, res) => {
  res.req = req;
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const path = url.pathname;

    if (req.method === 'OPTIONS') {
      json(res, 204, {});
      return;
    }

    if (req.method === 'GET' && path === '/health') {
      json(res, 200, { ok: true });
      return;
    }

    if (req.method === 'GET' && path === '/health/db') {
      if (usePostgres) {
        await pgPool.query('SELECT 1');
      }
      json(res, 200, {
        ok: true,
        database: usePostgres ? 'postgres' : 'memory',
      });
      return;
    }

    const body = ['POST', 'PATCH'].includes(req.method) ? await readBody(req) : {};

    if (req.method === 'POST' && path === '/auth/signup') {
      if (!rateLimit(req, res, 'auth:signup', 8, 15 * 60 * 1000)) return;
      const email = text(body.email, '', 180).toLowerCase();
      const password = String(body.password || '');
      if (!isEmail(email) || password.length < 6) {
        json(res, 400, { error: 'A valid email and a 6 character password are required.' });
        return;
      }
      if ([...users.values()].some((user) => user.email.toLowerCase() === email)) {
        json(res, 409, { error: 'An account already exists for that email.' });
        return;
      }

      const user = {
        uid: id('user'),
        name: text(body.name, 'MoveTraq User', 80) || 'MoveTraq User',
        email,
        phone: text(body.phone, '', 32),
        activeRole: 'sender',
        rating: 5,
        totalDeliveries: 0,
        memberTier: 'Bronze',
        walletBalance: 0,
        delivererOnline: false,
        verified: false,
        vehicleType: 'bike',
        distanceKm: 0,
        etaMinutes: 0,
        rate: 0,
        createdAt: now(),
      };
      users.set(user.uid, user);
      credentials.set(email, hashPassword(password));
      await saveStore();
      json(res, 201, { token: signToken(user.uid), user });
      return;
    }

    if (req.method === 'POST' && path === '/auth/signin') {
      if (!rateLimit(req, res, 'auth:signin', 20, 15 * 60 * 1000)) return;
      const rawLogin = text(body.emailOrPhone, '', 180);
      const login = rawLogin.toLowerCase();
      const password = String(body.password || '');
      const user = [...users.values()].find(
        (item) => item.email.toLowerCase() === login || item.phone === rawLogin,
      );
      if (!user || !verifyPassword(password, credentials.get(user.email.toLowerCase()))) {
        json(res, 401, { error: 'Invalid email/phone or password.' });
        return;
      }
      json(res, 200, { token: signToken(user.uid), user });
      return;
    }

    if (req.method === 'POST' && path === '/auth/reset-password') {
      if (!rateLimit(req, res, 'auth:reset-password', 6, 30 * 60 * 1000)) return;
      const rawLogin = text(body.emailOrPhone, '', 180);
      const login = rawLogin.toLowerCase();
      const newPassword = String(body.newPassword || '');
      if (!login || newPassword.length < 6) {
        json(res, 400, { error: 'Email or phone and a 6 character password are required.' });
        return;
      }

      const user = [...users.values()].find(
        (item) => item.email.toLowerCase() === login || item.phone === rawLogin,
      );
      if (!user) {
        json(res, 404, { error: 'No MoveTraq account was found for that email or phone.' });
        return;
      }

      credentials.set(user.email.toLowerCase(), hashPassword(newPassword));
      await saveStore();
      json(res, 200, { ok: true });
      return;
    }

    if (req.method === 'POST' && path === '/auth/logout') {
      json(res, 200, { ok: true });
      return;
    }

    const user = requireAuth(req, res);
    if (!user) return;

    if (req.method === 'GET' && path === '/auth/me') {
      json(res, 200, { user });
      return;
    }

    if (req.method === 'PATCH' && path === '/users/me') {
      if (typeof body.name === 'string' && body.name.trim()) {
        user.name = text(body.name, user.name, 80);
      }
      if (typeof body.phone === 'string') {
        user.phone = text(body.phone, '', 32);
      }
      if (body.activeRole === 'sender' || body.activeRole === 'deliverer') {
        user.activeRole = body.activeRole;
      }
      if (typeof body.delivererOnline === 'boolean') {
        user.delivererOnline = body.delivererOnline;
      }
      if (typeof body.vehicleType === 'string' && body.vehicleType.trim()) {
        user.vehicleType = text(body.vehicleType, user.vehicleType, 40);
      }
      if (typeof body.rate === 'number') {
        user.rate = Math.max(0, Number(body.rate));
      }
      await saveStore();
      json(res, 200, { user });
      return;
    }

    if (req.method === 'PATCH' && path === '/users/me/location') {
      const location = readLocation(body);
      if (!location) {
        json(res, 400, { error: 'Valid latitude and longitude are required.' });
        return;
      }
      user.currentLocation = location;
      await saveStore();
      json(res, 200, { user, location });
      return;
    }

    if (req.method === 'GET' && path === '/deliverers') {
      json(res, 200, {
        deliverers: [...users.values()].filter(
          (item) => item.activeRole === 'deliverer' && item.delivererOnline,
        ),
      });
      return;
    }

    if (req.method === 'GET' && path === '/places/autocomplete') {
      const query = String(url.searchParams.get('q') || '').trim();
      json(res, 200, { suggestions: await placeSuggestions(query) });
      return;
    }

    if (req.method === 'GET' && path === '/orders') {
      json(res, 200, { orders: visibleOrders(user) });
      return;
    }

    if (req.method === 'POST' && path === '/orders') {
      const price = Number(body.price || 0);
      if (!Number.isFinite(price) || price < 0) {
        json(res, 400, { error: 'Order price must be a valid positive number.' });
        return;
      }
      const payout = Number(body.payout || Math.max(0, price - 500));
      if (!Number.isFinite(payout) || payout < 0 || payout > price) {
        json(res, 400, { error: 'Order payout is invalid.' });
        return;
      }
      if (price > 0 && Number(user.walletBalance || 0) < price) {
        json(res, 400, { error: 'Please top up your wallet before creating this order.' });
        return;
      }

      const isP2P = body.isP2P !== false && body.matchingMode !== 'express';
      const matchingMode = isP2P ? 'p2p' : 'express';
      const targetDelivererId =
        isP2P && body.targetDelivererId ? String(body.targetDelivererId) : null;
      const targetDelivererName =
        isP2P && body.targetDelivererName ? String(body.targetDelivererName) : null;
      const autoAccept = Boolean(body.autoAccept && body.delivererId);
      const delivererId = autoAccept ? String(body.delivererId) : null;
      const delivererName = autoAccept ? String(body.delivererName || '') : null;

      const order = {
        ...body,
        id: id('order'),
        code: orderCode(),
        senderId: user.uid,
        senderName: user.name,
        delivererId,
        delivererName,
        targetDelivererId,
        targetDelivererName,
        matchingMode,
        isP2P,
        isExpress: !isP2P,
        speedIndex: !isP2P && body.speedIndex !== undefined ? Number(body.speedIndex) : null,
        speedLabel: !isP2P ? String(body.speedLabel || 'Express') : null,
        price,
        payout,
        status: delivererId ? 'accepted' : 'pendingOffer',
        createdAt: now(),
        deliveredAt: null,
        releasedAt: null,
        dStage: 0,
        escrowHeld: price > 0,
        escrowReleased: false,
        escrowRefunded: false,
      };
      addDeliveryEvent(order, 'created', user.uid, targetDelivererName ? 'P2P request created' : 'Order opened');
      orders.set(order.id, order);
      if (price > 0) {
        addWalletTransaction(
          user.uid,
          tx('escrowHold', 'Escrow hold', `${order.code} ${order.title || 'delivery'}`, -price),
          -price,
        );
      }
      addNotification(
        user.uid,
        notification(
          'Order created',
          targetDelivererName
            ? `${order.code} was sent to ${targetDelivererName}.`
            : `${order.code} is ready for courier offers.`,
          'delivery',
        ),
      );
      if (targetDelivererId) {
        addNotification(
          targetDelivererId,
          notification('New P2P delivery request', `${user.name} sent you ${order.code}.`, 'job'),
        );
      } else if (order.delivererId) {
        addNotification(
          order.delivererId,
          notification('New assigned job', `${order.code} was assigned to you.`, 'job'),
        );
      }
      await saveStore();
      json(res, 201, { order });
      return;
    }

    const orderMatch = path.match(/^\/orders\/([^/]+)(?:\/([^/]+))?$/);
    if (orderMatch) {
      const order = orders.get(orderMatch[1]);
      const action = orderMatch[2];
      if (!order) {
        json(res, 404, { error: 'Order not found.' });
        return;
      }
      if (!requireOrderAccess(user, order)) {
        json(res, 403, { error: 'You do not have access to this order.' });
        return;
      }

      if (req.method === 'GET' && !action) {
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'accept') {
        if (!['pendingOffer', 'negotiating'].includes(order.status)) {
          json(res, 409, { error: 'This order is no longer available.' });
          return;
        }
        if (order.targetDelivererId && order.targetDelivererId !== user.uid) {
          json(res, 403, { error: 'This P2P request was sent to another deliverer.' });
          return;
        }
        order.delivererId = user.uid;
        order.delivererName = user.name;
        order.status = 'accepted';
        order.dStage = 0;
        addDeliveryEvent(order, 'accepted', user.uid, 'Courier accepted the order');
        addNotification(
          order.senderId,
          notification('Courier accepted', `${order.delivererName} accepted ${order.code}.`, 'delivery'),
        );
        addNotification(
          order.delivererId,
          notification('Job accepted', `You accepted ${order.code}.`, 'job'),
        );
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'stage') {
        if (!order.delivererId || order.delivererId !== user.uid) {
          json(res, 403, { error: 'Only the assigned deliverer can update delivery progress.' });
          return;
        }
        const stage = Number(body.stage);
        const statuses = ['accepted', 'pickedUp', 'delivered'];
        if (!statuses[stage]) {
          json(res, 400, { error: 'Invalid delivery stage.' });
          return;
        }
        order.dStage = stage;
        order.status = statuses[stage];
        if (stage === 2) order.deliveredAt = now();
        addDeliveryEvent(order, statuses[stage], user.uid, `${order.code} moved to ${statuses[stage]}`);
        const titles = ['Courier en route', 'Picked up', 'Delivered'];
        addNotification(
          order.senderId,
          notification(titles[stage], `${order.code} status updated.`, 'delivery'),
        );
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'location') {
        if (!order.delivererId || order.delivererId !== user.uid) {
          json(res, 403, { error: 'Only the assigned deliverer can update courier location.' });
          return;
        }
        const location = readLocation(body);
        if (!location) {
          json(res, 400, { error: 'Valid latitude and longitude are required.' });
          return;
        }
        order.courierLocation = location;
        order.simulatedLocation = false;
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'negotiate') {
        const price = Number(body.price);
        if (!Number.isFinite(price) || price < 0) {
          json(res, 400, { error: 'Price must be a valid positive number.' });
          return;
        }
        if (![order.senderId, order.delivererId, order.targetDelivererId].includes(user.uid)) {
          json(res, 403, { error: 'Only order participants can negotiate this order.' });
          return;
        }
        order.price = price;
        order.status = 'negotiating';
        addDeliveryEvent(order, 'negotiating', user.uid, `Price updated to NGN ${price.toFixed(0)}`);
        addNotification(
          order.senderId,
          notification('Price updated', `${order.code} is now negotiating at NGN ${price.toFixed(0)}.`, 'delivery'),
        );
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'confirm-price') {
        const price = Number(body.price);
        if (!Number.isFinite(price) || price < 0) {
          json(res, 400, { error: 'Price must be a valid positive number.' });
          return;
        }
        if (order.senderId !== user.uid) {
          json(res, 403, { error: 'Only the sender can confirm the final price.' });
          return;
        }
        if (order.senderId === user.uid && price > 0 && !order.escrowHeld && Number(user.walletBalance || 0) < price) {
          json(res, 400, { error: 'Please top up your wallet before confirming this price.' });
          return;
        }
        order.price = price;
        order.payout = Math.max(0, price - 500);
        order.status = 'pendingOffer';
        addDeliveryEvent(order, 'priceConfirmed', user.uid, `Price confirmed at NGN ${price.toFixed(0)}`);
        if (!order.escrowHeld && price > 0) {
          addWalletTransaction(
            order.senderId,
            tx('escrowHold', 'Escrow hold', `${order.code} ${order.title || 'delivery'}`, -price),
            -price,
          );
          order.escrowHeld = true;
        }
        addNotification(
          order.senderId,
          notification('Price confirmed', `${order.code} is open for couriers.`, 'delivery'),
        );
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'release') {
        if (order.senderId !== user.uid) {
          json(res, 403, { error: 'Only the sender can release escrow.' });
          return;
        }
        if (order.escrowReleased) {
          json(res, 200, { order });
          return;
        }
        order.status = 'released';
        order.releasedAt = now();
        order.escrowReleased = true;
        addDeliveryEvent(order, 'released', user.uid, 'Sender released escrow');
        if (order.delivererId) {
          addWalletTransaction(
            order.delivererId,
            tx('released', 'Delivery payout', `${order.code} ${order.title || 'delivery'}`, Number(order.payout || 0)),
            Number(order.payout || 0),
          );
          const deliverer = users.get(order.delivererId);
          if (deliverer) {
            deliverer.totalDeliveries = Number(deliverer.totalDeliveries || 0) + 1;
            users.set(deliverer.uid, deliverer);
          }
          addNotification(
            order.delivererId,
            notification('Payment released', `NGN ${Number(order.payout || 0).toFixed(0)} was added to your wallet.`, 'wallet'),
          );
        }
        addNotification(
          order.senderId,
          notification('Escrow released', `${order.code} has been completed.`, 'payment'),
        );
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'cancel') {
        if (order.senderId !== user.uid && order.delivererId !== user.uid) {
          json(res, 403, { error: 'Only an order participant can cancel this order.' });
          return;
        }
        if (order.status === 'released') {
          json(res, 409, { error: 'Released orders cannot be cancelled.' });
          return;
        }
        order.status = 'cancelled';
        addDeliveryEvent(order, 'cancelled', user.uid, 'Order cancelled');
        if (order.escrowHeld && !order.escrowReleased && !order.escrowRefunded) {
          addWalletTransaction(
            order.senderId,
            tx('refund', 'Escrow refund', `${order.code} ${order.title || 'delivery'}`, Number(order.price || 0)),
            Number(order.price || 0),
          );
          order.escrowRefunded = true;
        }
        addNotification(
          order.senderId,
          notification('Order cancelled', `${order.code} was cancelled.`, 'delivery'),
        );
        if (order.delivererId) {
          addNotification(
            order.delivererId,
            notification('Order cancelled', `${order.code} was cancelled.`, 'job'),
          );
        }
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (action === 'messages') {
        const list = messages.get(order.id) || [];
        if (req.method === 'GET') {
          json(res, 200, { messages: list });
          return;
        }
        if (req.method === 'POST') {
          const text = String(body.text || '').trim();
          if (!text) {
            json(res, 400, { error: 'Message text is required.' });
            return;
          }
          const message = {
            id: id('msg'),
            senderId: user.uid,
            text: text.slice(0, 1000),
            createdAt: now(),
          };
          list.push(message);
          messages.set(order.id, list);
          await saveStore();
          json(res, 201, { message });
          return;
        }
      }
    }

    if (req.method === 'GET' && path === '/wallet/transactions') {
      json(res, 200, { transactions: walletTransactions.get(user.uid) || [] });
      return;
    }

    if (req.method === 'GET' && path === '/wallet') {
      json(res, 200, {
        user,
        transactions: walletTransactions.get(user.uid) || [],
      });
      return;
    }

    if (req.method === 'POST' && path === '/wallet/topup') {
      if (!rateLimit(req, res, 'wallet:topup', 20, 15 * 60 * 1000)) return;
      const amount = Number(body.amount || 0);
      if (!Number.isFinite(amount) || amount <= 0) {
        json(res, 400, { error: 'A positive top-up amount is required.' });
        return;
      }
      if (process.env.DISABLE_TEST_WALLET_TOPUPS === 'true') {
        json(res, 403, { error: 'Wallet top-up requires a payment provider in production.' });
        return;
      }
      const list = addWalletTransaction(
        user.uid,
        tx('topup', body.title || 'Wallet top-up', body.sub || 'Wallet funding', amount),
        amount,
      );
      addNotification(user.uid, notification('Wallet topped up', `NGN ${amount.toFixed(0)} was added to your wallet.`, 'wallet'));
      await saveStore();
      json(res, 201, { user, transactions: list });
      return;
    }

    if (req.method === 'POST' && path === '/wallet/withdraw') {
      if (!rateLimit(req, res, 'wallet:withdraw', 10, 15 * 60 * 1000)) return;
      const amount = Number(body.amount || 0);
      if (!Number.isFinite(amount) || amount <= 0) {
        json(res, 400, { error: 'A positive withdrawal amount is required.' });
        return;
      }
      if (Number(user.walletBalance || 0) < amount) {
        json(res, 400, { error: 'Insufficient wallet balance.' });
        return;
      }
      const list = addWalletTransaction(
        user.uid,
        tx('withdrawal', body.title || 'Bank withdrawal', body.sub || 'Wallet withdrawal', -amount),
        -amount,
      );
      addNotification(user.uid, notification('Withdrawal requested', `NGN ${amount.toFixed(0)} withdrawal was recorded.`, 'wallet'));
      await saveStore();
      json(res, 201, { user, transactions: list });
      return;
    }

    if (req.method === 'POST' && path === '/wallet/transactions') {
      if (isProduction) {
        json(res, 403, { error: 'Direct wallet transactions are disabled in production.' });
        return;
      }
      const balanceDelta = Number(body.balanceDelta || 0);
      if (balanceDelta < 0 && Number(user.walletBalance || 0) + balanceDelta < 0) {
        json(res, 400, { error: 'Insufficient wallet balance.' });
        return;
      }
      const list = addWalletTransaction(
        user.uid,
        tx(
          body.type || 'topup',
          body.title || 'Wallet transaction',
          body.sub || '',
          Number(body.amount || balanceDelta || 0),
        ),
        balanceDelta,
      );
      addNotification(
        user.uid,
        notification('Wallet updated', `${body.title || 'Wallet transaction'} was recorded.`, 'wallet'),
      );
      await saveStore();
      json(res, 201, { user, transactions: list });
      return;
    }

    if (req.method === 'GET' && path === '/notifications') {
      json(res, 200, { notifications: notifications.get(user.uid) || [] });
      return;
    }

    if (req.method === 'POST' && path === '/notifications') {
      const list = notifications.get(user.uid) || [];
      list.push({
        id: id('notif'),
        title: body.title || 'MoveTraq',
        body: body.body || '',
        type: body.type || 'delivery',
        read: Boolean(body.read),
        createdAt: now(),
      });
      notifications.set(user.uid, list);
      await saveStore();
      json(res, 201, { notifications: list });
      return;
    }

    const notificationMatch = path.match(/^\/notifications\/([^/]+)\/read$/);
    if (req.method === 'POST' && notificationMatch) {
      const list = notifications.get(user.uid) || [];
      const notification = list.find((item) => item.id === notificationMatch[1]);
      if (notification) notification.read = true;
      await saveStore();
      json(res, 200, { notifications: list });
      return;
    }

    json(res, 404, { error: 'Route not found.' });
  } catch (error) {
    json(res, 500, { error: error.message || 'Server error.' });
  }
});

async function start() {
  if (isProduction && jwtSecret === 'movetraq-local-secret') {
    throw new Error('JWT_SECRET must be set in production.');
  }
  await connectPostgres();
  await loadStore();
  await saveStore();

  server.listen(port, () => {
    console.log(`MoveTraq API listening on http://localhost:${port}`);
  });
}

start().catch((error) => {
  console.error(`MoveTraq API failed to start: ${error.message}`);
  process.exit(1);
});
