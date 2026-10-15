const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { Pool } = require('pg');
const { WalletPayments, PaymentError, minorUnits, validSignature, validReference } = require('./payments');
const monitoring = require('./monitoring');
const { DelivererAccess } = require('./deliverer-access');

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
const delivererAccess = new DelivererAccess({origin:process.env.DELIVERER_AUTHORITY_URL||'https://movetraq-production-api.onrender.com',secret:process.env.MONITORING_SERVICE_TOKEN});

const port = Number(process.env.PORT || 3000);
const jwtSecret = process.env.JWT_SECRET || 'movetraq-local-secret';
const databaseUrl = process.env.DATABASE_URL || process.env.POSTGRES_URL || '';
const nodeEnv = process.env.NODE_ENV || 'development';
const isProduction = nodeEnv === 'production';
const accessTokenTtlSeconds = Number(process.env.ACCESS_TOKEN_TTL_SECONDS || 60 * 60 * 24 * 7);
const googleMapsApiKey =
  process.env.GOOGLE_PLACES_API_KEY ||
  process.env.GOOGLE_GEOCODING_API_KEY ||
  process.env.GOOGLE_MAPS_API_KEY ||
  process.env.GOOGLE_API_KEY ||
  '';
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
const savedAddresses = new Map();
const securitySettings = new Map();
const supportTickets = new Map();
let pgPool = null;
let usePostgres = false;
const rateLimitBuckets = new Map();
let pendingWalletEntries = [];
let requestQueue = Promise.resolve();
function walletPayments() {
  return new WalletPayments({ pool: usePostgres ? pgPool : null, secret: process.env.PAYMENT_SECRET_KEY,
    origin: process.env.MOVETRAQ_PUBLIC_API_URL || process.env.RENDER_EXTERNAL_URL });
}

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
    CREATE TABLE IF NOT EXISTS saved_addresses (
      user_id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS security_settings (
      user_id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS support_tickets (
      user_id TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  usePostgres = true;
  await pgPool.query(fs.readFileSync(path.join(__dirname, '..', 'migrations', '0001_paystack_wallet.sql'), 'utf8'));
  await pgPool.query(fs.readFileSync(path.join(__dirname, '..', 'migrations', '0002_mobile_monitoring.sql'), 'utf8'));
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
    addressRows,
    securityRows,
    supportRows,
  ] = await Promise.all([
    pgPool.query('SELECT uid, data FROM users'),
    pgPool.query('SELECT email, password_hash FROM credentials'),
    pgPool.query('SELECT id, data FROM orders'),
    pgPool.query('SELECT order_id, data FROM order_messages'),
    pgPool.query('SELECT user_id, data FROM wallet_transactions'),
    pgPool.query('SELECT user_id, data FROM notifications'),
    pgPool.query('SELECT user_id, data FROM saved_addresses'),
    pgPool.query('SELECT user_id, data FROM security_settings'),
    pgPool.query('SELECT user_id, data FROM support_tickets'),
  ]);

  for (const map of [users, credentials, orders, messages, walletTransactions, notifications, savedAddresses, securitySettings, supportTickets]) map.clear();
  for (const row of userRows.rows) users.set(row.uid, row.data);
  for (const row of credentialRows.rows) credentials.set(row.email, row.password_hash);
  for (const row of orderRows.rows) orders.set(row.id, row.data);
  for (const row of messageRows.rows) messages.set(row.order_id, row.data);
  for (const row of walletRows.rows) walletTransactions.set(row.user_id, row.data);
  for (const row of notificationRows.rows) notifications.set(row.user_id, row.data);
  for (const row of addressRows.rows) savedAddresses.set(row.user_id, row.data);
  for (const row of securityRows.rows) securitySettings.set(row.user_id, row.data);
  for (const row of supportRows.rows) supportTickets.set(row.user_id, row.data);

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
      for (const [key, item] of Object.entries(store.savedAddresses || {})) savedAddresses.set(key, item);
      for (const [key, item] of Object.entries(store.securitySettings || {})) securitySettings.set(key, item);
      for (const [key, item] of Object.entries(store.supportTickets || {})) supportTickets.set(key, item);
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
    for (const entry of pendingWalletEntries) {
      await client.query(`insert into legacy_wallet_ledger(id,user_id,kind,amount_minor,balance_after_minor)
        values($1,$2,$3,$4,$5)`, [entry.id, entry.userId, entry.kind, entry.amountMinor, entry.balanceMinor]);
    }
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
    await upsertJsonMap(client, 'saved_addresses', 'user_id', savedAddresses);
    await upsertJsonMap(client, 'security_settings', 'user_id', securitySettings);
    await upsertJsonMap(client, 'support_tickets', 'user_id', supportTickets);
    await client.query('COMMIT');
    pendingWalletEntries = [];
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
  res.auditStatus = status;
  res.auditResult = {actor:body?.user?.uid,reference:body?.reference,order:body?.order?.id};
  const origin = res.req?.headers?.origin;
  const allowOrigin =
    allowedOrigins.includes('*') || !origin || allowedOrigins.includes(origin)
      ? origin || '*'
      : allowedOrigins[0] || '*';
  res.writeHead(status, {
    'content-type': 'application/json',
    'access-control-allow-origin': allowOrigin,
    'access-control-allow-methods': 'GET,POST,PATCH,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization,idempotency-key',
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'no-referrer',
    'cache-control': 'no-store',
    'x-request-id': res.req?.requestId || '',
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

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = []; let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1_000_000) {
        req.destroy();
        reject(new Error('Request body is too large.'));
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      resolve(Buffer.concat(chunks));
    });
    req.on('error', reject);
    req.on('aborted', () => reject(new PaymentError(400, 'Request was interrupted.')));
  });
}
async function readBody(req) {
  const raw = await req.rawBody;
  try { return raw?.length ? JSON.parse(raw.toString('utf8')) : {}; }
  catch { throw new PaymentError(400, 'Invalid JSON body.'); }
}

function visibleOrders(user, approved=false) {
  return [...orders.values()]
    .filter((order) => {
      if (order.senderId === user.uid) {
        return true;
      }
      if (!approved) return false;
      if (order.delivererId === user.uid) return true;
      if (order.targetDelivererId) {
        return order.targetDelivererId === user.uid;
      }
      return order.status === 'pendingOffer';
    })
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
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
  const amountMinor = minorUnits(balanceDelta);
  const balanceMinor = minorUnits(user.walletBalance || 0) + amountMinor;
  if (!Number.isSafeInteger(balanceMinor) || balanceMinor < 0) throw new PaymentError(409, 'Insufficient wallet balance.');
  user.walletBalance = balanceMinor / 100;
  user.walletRevision = Number(user.walletRevision || 0) + 1;
  pendingWalletEntries.push({ id: item.id, userId, kind: item.type, amountMinor, balanceMinor });
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

function publicSecuritySettings(userId) {
  const settings = securitySettings.get(userId) || {};
  return {
    biometricsEnabled: Boolean(settings.biometricsEnabled),
    pinEnabled: Boolean(settings.pinHash),
  };
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

function readOptionalLocation(value) {
  if (!value || typeof value !== 'object') return null;
  const latitude = Number(value.latitude);
  const longitude = Number(value.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return { latitude, longitude };
}

function distanceKm(from, to) {
  if (!from || !to) return null;
  const lat1 = Number(from.latitude);
  const lon1 = Number(from.longitude);
  const lat2 = Number(to.latitude);
  const lon2 = Number(to.longitude);
  if (![lat1, lon1, lat2, lon2].every(Number.isFinite)) return null;

  const radiusKm = 6371;
  const toRadians = (degrees) => degrees * Math.PI / 180;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) ** 2;
  return 2 * radiusKm * Math.asin(Math.sqrt(a));
}

function applyLiveEta(order) {
  if (!order || !order.courierLocation) return order;
  const destination =
    order.status === 'accepted'
      ? order.pickupLocation || order.dropoffLocation
      : order.dropoffLocation;
  const km = distanceKm(order.courierLocation, destination);
  if (km == null) return order;

  const averageUrbanKmh = Number(process.env.DELIVERY_AVERAGE_KMH || 22);
  const safeKmh = Number.isFinite(averageUrbanKmh) && averageUrbanKmh > 0
    ? averageUrbanKmh
    : 22;
  const etaMinutes = Math.max(1, Math.ceil((km / safeKmh) * 60));
  order.etaMinutes = etaMinutes;
  order.etaUpdatedAt = now();
  order.etaDistanceKm = Number(km.toFixed(2));
  return order;
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

function normalizeGoogleAddress(item) {
  const location = item.geometry?.location || {};
  return {
    id: item.place_id ? `google-${item.place_id}` : `google-${crypto.randomUUID()}`,
    placeId: item.place_id || '',
    name:
      item.name ||
      item.structured_formatting?.main_text ||
      item.formatted_address ||
      item.description ||
      '',
    address:
      item.formatted_address ||
      item.description ||
      item.vicinity ||
      item.name ||
      '',
    latitude: Number.isFinite(Number(location.lat)) ? Number(location.lat) : null,
    longitude: Number.isFinite(Number(location.lng)) ? Number(location.lng) : null,
    source: 'google',
  };
}

async function googlePlaceDetails(placeId) {
  if (!googleMapsApiKey || !placeId) return null;

  const url = new URL('https://maps.googleapis.com/maps/api/place/details/json');
  url.searchParams.set('place_id', placeId);
  url.searchParams.set('fields', 'place_id,name,formatted_address,geometry');
  url.searchParams.set('key', googleMapsApiKey);

  const response = await fetch(url, { signal: AbortSignal.timeout(4000) });
  if (!response.ok) return null;
  const data = await response.json();
  if (data.status !== 'OK' || !data.result) return null;
  return normalizeGoogleAddress(data.result);
}

async function googlePlaceSuggestions(query) {
  if (!googleMapsApiKey) return [];

  const url = new URL('https://maps.googleapis.com/maps/api/place/autocomplete/json');
  url.searchParams.set('input', query);
  url.searchParams.set('components', 'country:ng');
  url.searchParams.set('key', googleMapsApiKey);

  const response = await fetch(url, { signal: AbortSignal.timeout(4000) });
  if (!response.ok) return [];
  const data = await response.json();
  if (!['OK', 'ZERO_RESULTS'].includes(data.status)) return [];

  const predictions = Array.isArray(data.predictions) ? data.predictions : [];
  const detailed = await Promise.all(
    predictions.slice(0, 6).map(async (prediction) => {
      const details = await googlePlaceDetails(prediction.place_id);
      return details || normalizeGoogleAddress(prediction);
    }),
  );
  return detailed.filter((item) => item.address);
}

async function geocodeAddress(query) {
  const trimmed = String(query || '').trim();
  if (trimmed.length < 2) return null;

  if (googleMapsApiKey) {
    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.searchParams.set('address', trimmed);
    url.searchParams.set('components', 'country:NG');
    url.searchParams.set('key', googleMapsApiKey);

    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(4000) });
      if (response.ok) {
        const data = await response.json();
        const result = Array.isArray(data.results) ? data.results[0] : null;
        if (data.status === 'OK' && result) {
          return normalizeGoogleAddress(result);
        }
      }
    } catch {
      // Fall through to non-Google/local geocoders.
    }
  }

  const local = localPlaceSuggestions(trimmed, 1)[0];
  if (local) return local;

  try {
    const url = new URL('https://nominatim.openstreetmap.org/search');
    url.searchParams.set('format', 'jsonv2');
    url.searchParams.set('limit', '1');
    url.searchParams.set('countrycodes', 'ng');
    url.searchParams.set('q', trimmed);
    const response = await fetch(url, {
      headers: {
        'user-agent': 'MoveTraq/1.0 (address geocoding)',
        accept: 'application/json',
      },
      signal: AbortSignal.timeout(3500),
    });
    if (!response.ok) return null;
    const items = await response.json();
    const item = Array.isArray(items) ? items[0] : null;
    if (!item) return null;
    return {
      id: `osm-${item.place_id}`,
      name: item.name || item.display_name,
      address: item.display_name,
      latitude: Number(item.lat),
      longitude: Number(item.lon),
      source: 'osm',
    };
  } catch {
    return null;
  }
}

async function placeSuggestions(query) {
  const local = localPlaceSuggestions(query);
  if (String(query || '').trim().length < 3) return local;

  try {
    const google = await googlePlaceSuggestions(query);
    if (google.length) {
      return [...google, ...local]
        .filter((item, index, all) => all.findIndex((other) => other.address === item.address) === index)
        .slice(0, 6);
    }
  } catch {
    // Fall through to OSM/local suggestions.
  }

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

function homeGreeting() {
  const timezone = process.env.APP_TIMEZONE || 'Africa/Lagos';
  let hour = new Date().getHours();
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      hour: 'numeric',
      hour12: false,
      timeZone: timezone,
    }).formatToParts(new Date());
    hour = Number(parts.find((part) => part.type === 'hour')?.value ?? hour);
  } catch {
    // Keep the server-local hour if the configured timezone is invalid.
  }

  if (hour < 12) return { greeting: 'Good morning', period: 'morning', hour, timezone };
  if (hour < 17) return { greeting: 'Good afternoon', period: 'afternoon', hour, timezone };
  return { greeting: 'Good evening', period: 'evening', hour, timezone };
}

async function handleRequest(req, res) {
  res.req = req;
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const path = url.pathname;

    if (req.method === 'OPTIONS') {
      json(res, 204, {});
      return;
    }

    if (req.method === 'GET' && path === '/internal/monitoring') {
      if (!rateLimit(req, res, 'internal:monitoring', 120, 60 * 1000)) return;
      if (!monitoring.authorized(req.headers.authorization, process.env.MONITORING_SERVICE_TOKEN)) {
        json(res, 401, { error: 'Monitoring access denied.' }); return;
      }
      const staff = req.headers['x-monitoring-staff'];
      if (typeof staff !== 'string' || !/^[0-9a-f-]{36}$/i.test(staff)) { json(res, 403, { error: 'Staff identity required.' }); return; }
      if (!usePostgres) { json(res, 503, { error: 'Persistent monitoring unavailable.' }); return; }
      await pgPool.query(`insert into mobile_request_attempts(id,staff_id,method,route,category,status,outcome,finished_at)
        values($1,$2,'GET','/internal/monitoring','security',200,'successful',now())`,[crypto.randomUUID(),staff]);
      json(res, 200, await monitoring.monitoringData(pgPool, url.searchParams)); return;
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

    if (req.method === 'GET' && path === '/home/context') {
      json(res, 200, {
        ...homeGreeting(),
        serverTime: now(),
      });
      return;
    }

    if (req.method === 'GET' && ['/payments/paystack/return', '/payments/paystack/cancel'].includes(path)) {
      json(res, 200, { status: 'verification_required' }); return;
    }
    if (req.method === 'GET' && path === '/payments/config') {
      let enabled = false;
      try { walletPayments().ready(); enabled = true; } catch {}
      json(res, 200, { provider: 'paystack', enabled, testMode: process.env.PAYMENT_SECRET_KEY?.startsWith('sk_test_') || false,
        currency: 'NGN', minimumMinor: 10000, maximumMinor: 100000000 }); return;
    }
    if (req.method === 'POST' && path === '/payments/webhooks/paystack') {
      if (!rateLimit(req, res, 'paystack:webhook', 120, 60 * 1000)) return;
      const raw = await req.rawBody;
      if (!validSignature(raw, req.headers['x-paystack-signature'], process.env.PAYMENT_SECRET_KEY)) {
        json(res, 401, { error: 'Invalid payment signature.' }); return;
      }
      let event;
      try { event = JSON.parse(raw.toString('utf8')); } catch { throw new PaymentError(400, 'Invalid webhook body.'); }
      if (event.event === 'charge.success' && validReference(event.data?.reference)) {
        try {
          const verified = await walletPayments().verify(event.data.reference);
          if (verified.status !== 'verified') throw new PaymentError(503, 'Payment is not settled yet.');
        }
        catch (error) { if (error.status !== 404) throw error; }
      }
      json(res, 200, { received: true }); return;
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
        canDeliver: false,
        delivererVerificationStatus: 'not_started',
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
      await delivererAccess.profile(user);
      json(res, 200, { token: signToken(user.uid), user });
      return;
    }

    if (req.method === 'POST' && path === '/auth/reset-password') {
      if (!rateLimit(req, res, 'auth:reset-password', 6, 30 * 60 * 1000)) return;
      json(res, 410, { error: 'Password recovery requires email verification. Please contact support until the verified recovery service is connected.' });
      return;
    }

    if (req.method === 'POST' && path === '/auth/logout') {
      json(res, 200, { ok: true });
      return;
    }

    const user = requireAuth(req, res);
    if (!user) return;
    if(req.method==='GET'&&path==='/deliverer-access'){
      const state=await delivererAccess.command(user,'status');await delivererAccess.profile(user,state);
      json(res,200,{...state,user});return;
    }
    const applicationRoute=path.match(/^\/api\/v1\/deliverers\/me\/applications(?:\/([0-9a-f-]{36})(?:\/(documents|submit))?)?$/i);
    const documentConfirm=path.match(/^\/api\/v1\/verification-documents\/([0-9a-f-]{36})\/confirm$/i);
    if(applicationRoute||documentConfirm){
      let command,input=body;
      if(documentConfirm&&req.method==='POST'){command='confirm';input={documentId:documentConfirm[1]};}
      else if(applicationRoute&&req.method==='POST'){
        command=applicationRoute[2]==='documents'?'reserve':applicationRoute[2]==='submit'?'submit':'start';
        input={...body,...(applicationRoute[1]?{applicationId:applicationRoute[1]}:{})};
      }else if(applicationRoute&&req.method==='GET')command='status';
      if(command){const result=await delivererAccess.command(user,command,input);
        if(applicationRoute?.[1]&&req.method==='GET'&&result.id!==applicationRoute[1]){json(res,404,{error:'Application was not found.'});return;}
        json(res,200,{success:true,data:result});return;}
    }

    if (req.method === 'POST' && path === '/payments/topups') {
      if (!rateLimit(req, res, 'paystack:initialize', 20, 15 * 60 * 1000)) return;
      if (!body || Object.keys(body).some(key => key !== 'amountMinor')) throw new PaymentError(400, 'Only the top-up amount is accepted.');
      json(res, 200, await walletPayments().initialize(user, body.amountMinor, req.headers['idempotency-key'])); return;
    }
    const verifyPayment = path.match(/^\/payments\/(mt-[a-f0-9]{64})\/verify$/);
    if (req.method === 'POST' && verifyPayment) {
      if (!rateLimit(req, res, 'paystack:verify', 30, 60 * 1000)) return;
      const result = await walletPayments().verify(verifyPayment[1], user.uid);
      if (result.status === 'verified') await loadStore();
      json(res, 200, { reference: result.reference, status: result.status,
        ...(result.status === 'verified' ? { user: users.get(user.uid) } : {}) }); return;
    }

    if (req.method === 'GET' && path === '/auth/me') {
      await delivererAccess.profile(user);
      json(res, 200, { user });
      return;
    }

    if (req.method === 'PATCH' && path === '/users/me') {
      if(body.vehicleType!==undefined)throw new PaymentError(403,'Transport changes require a reviewed deliverer application.');
      if(body.activeRole==='deliverer'||body.delivererOnline===true)await delivererAccess.requireApproved(user);
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
      const candidates=[];
      for(const item of users.values())if(item.activeRole==='deliverer'&&item.delivererOnline){await delivererAccess.profile(item);if(item.canDeliver)candidates.push(item);}
      json(res, 200, {
        deliverers: candidates,
      });
      return;
    }

    if (req.method === 'GET' && path === '/places/autocomplete') {
      const query = String(url.searchParams.get('q') || '').trim();
      json(res, 200, { suggestions: await placeSuggestions(query) });
      return;
    }

    if (req.method === 'GET' && path === '/places/geocode') {
      const query = String(url.searchParams.get('q') || '').trim();
      const result = await geocodeAddress(query);
      if (!result) {
        json(res, 404, { error: 'Address could not be geocoded.' });
        return;
      }
      json(res, 200, { location: result });
      return;
    }

    if (req.method === 'GET' && path === '/orders') {
      await delivererAccess.profile(user);
      json(res, 200, { orders: visibleOrders(user,user.canDeliver===true) });
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
      if(autoAccept)throw new PaymentError(403,'Deliverers must accept jobs through their approved account.');
      if(body.targetDelivererId){const target=users.get(String(body.targetDelivererId));if(!target)throw new PaymentError(404,'Deliverer not found.');await delivererAccess.requireApproved(target);}
      const delivererId = autoAccept ? String(body.delivererId) : null;
      const delivererName = autoAccept ? String(body.delivererName || '') : null;
      const pickupAddress = text(body.pickupAddress).trim() || 'Current location';
      const dropoffAddress = text(body.dropoffAddress).trim() || 'Lekki Phase 1';
      const pickupLocation = readOptionalLocation(body.pickupLocation);
      const dropoffLocation = readOptionalLocation(body.dropoffLocation);

      const order = {
        ...body,
        id: id('order'),
        code: orderCode(),
        senderId: user.uid,
        senderName: user.name,
        pickupAddress,
        dropoffAddress,
        pickupLocation,
        dropoffLocation,
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
      if(order.senderId!==user.uid){
        const historicalRead=req.method==='GET'&&order.delivererId===user.uid&&['completed','cancelled'].includes(order.status);
        if(!historicalRead)await delivererAccess.requireApproved(user);
      }
      if(req.method==='POST'&&['accept','stage','location'].includes(action))await delivererAccess.requireApproved(user);
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
        order.courierLocationUpdatedAt = now();
        const trail = Array.isArray(order.courierLocationTrail)
          ? order.courierLocationTrail
          : [];
        const lastTrailPoint = trail[trail.length - 1];
        if (
          !lastTrailPoint ||
          Number(lastTrailPoint.latitude) !== location.latitude ||
          Number(lastTrailPoint.longitude) !== location.longitude
        ) {
          trail.push({ ...location, updatedAt: order.courierLocationUpdatedAt });
          order.courierLocationTrail = trail.slice(-120);
        }
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

      if (req.method === 'GET' && action === 'contact') {
        if (!requireOrderAccess(user, order)) {
          json(res, 403, { error: 'You do not have access to this order.' });
          return;
        }
        const otherUserId = user.uid === order.senderId ? order.delivererId : order.senderId;
        const contact = otherUserId ? users.get(otherUserId) : null;
        if (!contact) {
          json(res, 404, { error: 'The other participant is not available yet.' });
          return;
        }
        json(res, 200, {
          contact: {
            uid: contact.uid,
            name: contact.name,
            phone: contact.phone,
            activeRole: contact.activeRole,
          },
        });
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
      if (isProduction || process.env.DISABLE_TEST_WALLET_TOPUPS === 'true') {
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
      if (isProduction) { json(res, 503, { error: 'Bank withdrawals are not connected yet. No funds were deducted.' }); return; }
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

    if (req.method === 'GET' && path === '/users/me/addresses') {
      json(res, 200, { addresses: savedAddresses.get(user.uid) || [] });
      return;
    }

    if (req.method === 'POST' && path === '/users/me/addresses') {
      const label = text(body.label, '', 80);
      const address = text(body.address, '', 280);
      if (!label || !address) {
        json(res, 400, { error: 'Label and address are required.' });
        return;
      }

      const list = savedAddresses.get(user.uid) || [];
      const addressId = text(body.id, '', 80) || id('addr');
      const existingIndex = list.findIndex((item) => item.id === addressId);
      const item = {
        id: addressId,
        label,
        address,
        createdAt: existingIndex === -1 ? now() : list[existingIndex].createdAt,
      };
      if (existingIndex === -1) {
        list.push(item);
      } else {
        list[existingIndex] = item;
      }
      savedAddresses.set(user.uid, list);
      await saveStore();
      json(res, 201, { address: item, addresses: list });
      return;
    }

    const addressDeleteMatch = path.match(/^\/users\/me\/addresses\/([^/]+)\/delete$/);
    if (req.method === 'POST' && addressDeleteMatch) {
      const list = savedAddresses.get(user.uid) || [];
      const next = list.filter((item) => item.id !== addressDeleteMatch[1]);
      savedAddresses.set(user.uid, next);
      await saveStore();
      json(res, 200, { addresses: next });
      return;
    }

    if (req.method === 'GET' && path === '/users/me/security') {
      json(res, 200, { settings: publicSecuritySettings(user.uid) });
      return;
    }

    if (req.method === 'PATCH' && path === '/users/me/security') {
      const current = securitySettings.get(user.uid) || {};
      const next = {
        ...current,
        biometricsEnabled: Boolean(body.biometricsEnabled),
      };

      if (Boolean(body.pinEnabled)) {
        const pin = String(body.pin || '');
        if (pin && !/^\d{4,8}$/.test(pin)) {
          json(res, 400, { error: 'PIN must be 4 to 8 digits.' });
          return;
        }
        if (pin) next.pinHash = hashPassword(pin);
        if (!next.pinHash) {
          json(res, 400, { error: 'Enter a PIN to enable PIN security.' });
          return;
        }
      } else {
        delete next.pinHash;
      }

      securitySettings.set(user.uid, next);
      await saveStore();
      json(res, 200, { settings: publicSecuritySettings(user.uid) });
      return;
    }

    if (req.method === 'GET' && path === '/support/tickets') {
      json(res, 200, { tickets: supportTickets.get(user.uid) || [] });
      return;
    }

    if (req.method === 'POST' && path === '/support/tickets') {
      const subject = text(body.subject, '', 120);
      const message = text(body.message, '', 1200);
      if (!subject || !message) {
        json(res, 400, { error: 'Subject and message are required.' });
        return;
      }

      const list = supportTickets.get(user.uid) || [];
      const ticket = {
        id: id('ticket'),
        subject,
        message,
        status: 'open',
        createdAt: now(),
      };
      list.push(ticket);
      supportTickets.set(user.uid, list);
      addNotification(
        user.uid,
        notification('Support request received', `${subject} has been sent to support.`, 'support'),
      );
      await saveStore();
      json(res, 201, { ticket, tickets: list });
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
    json(res, error.status || 500, { error: error.status ? error.message : 'The request could not be completed. Please retry.' });
  }
}

async function lockedStore(action) {
  if (!usePostgres) return action();
  const lock = await pgPool.connect();
  try {
    // Whole-store snapshots must be serialized across instances and refreshed
    // so another request's save cannot overwrite a verified payment.
    await lock.query("select pg_advisory_lock(hashtext('movetraq-legacy-store-v2'))");
    pendingWalletEntries = [];
    await loadStore();
    return await action();
  } finally {
    try { await lock.query("select pg_advisory_unlock(hashtext('movetraq-legacy-store-v2'))"); }
    finally { lock.release(); }
  }
}
const server = http.createServer((req, res) => {
  req.requestId = crypto.randomUUID();
  res.req = req;
  if (['POST', 'PATCH'].includes(req.method)) {
    req.rawBody = readRawBody(req);
    req.rawBody.catch(() => {});
  }
  const simple = req.method === 'OPTIONS' || (req.method === 'GET' && ['/health', '/health/db', '/home/context',
    '/payments/config',
    '/payments/paystack/return', '/payments/paystack/cancel'].includes(req.url?.split('?')[0]));
  if (simple) { handleRequest(req, res); return; }
  const action = () => lockedStore(async () => {
    let attempt;
    if (usePostgres && req.method !== 'OPTIONS' && !req.url?.startsWith('/internal/')) {
      attempt = await monitoring.beginAttempt(pgPool, req, authUser(req)?.uid);
    }
    try { await handleRequest(req, res); }
    finally {
      if (attempt) await monitoring.finishAttempt(pgPool, attempt, res.auditStatus || 500, res.auditResult);
    }
  });
  const task = requestQueue.then(action, action);
  requestQueue = task.catch(() => {});
  task.catch(() => {
    console.error(JSON.stringify({event:'mobile_request_persistence_unavailable',requestId:req.requestId}));
    if (!res.writableEnded) json(res, 503, { error: 'Wallet data is temporarily unavailable. Please retry.', requestId:req.requestId });
  });
});

async function start() {
  if (isProduction && jwtSecret === 'movetraq-local-secret') {
    throw new Error('JWT_SECRET must be set in production.');
  }
  if (isProduction && !databaseUrl) throw new Error('Persistent PostgreSQL is required in production.');
  await connectPostgres();
  await lockedStore(() => saveStore());
  if (usePostgres) {
    let running = false;
    setInterval(() => {
      if (running) return;
      try { walletPayments().ready(); } catch { return; }
      running = true;
      const task = requestQueue.then(() => lockedStore(() => monitoring.reconcilePending(pgPool, walletPayments())));
      requestQueue = task.catch(() => {});
      void task.catch(() => console.error(JSON.stringify({event:'payment_reconciliation_unavailable'})))
        .finally(() => { running = false; });
    }, 60000).unref();
  }

  server.listen(port, () => {
    console.log(`MoveTraq API listening on http://localhost:${port}`);
  });
}

start().catch((error) => {
  console.error(`MoveTraq API failed to start: ${error.message}`);
  process.exit(1);
});
