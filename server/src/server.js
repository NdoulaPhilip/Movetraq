const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { MongoClient } = require('mongodb');

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
const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URI || '';
const mongoDbName = process.env.MONGODB_DB || 'movetraq';
const mongoStateId = 'movetraq-store';

const users = new Map();
const credentials = new Map();
const orders = new Map();
const messages = new Map();
const walletTransactions = new Map();
const notifications = new Map();
let mongoClient = null;
let mongoDb = null;
let useMongo = false;

function mapToObject(map) {
  return Object.fromEntries(map.entries());
}

function loadMap(map, value) {
  if (!value || typeof value !== 'object') return;
  for (const [key, item] of Object.entries(value)) {
    map.set(key, item);
  }
}

function storeSnapshot() {
  return {
    users: mapToObject(users),
    credentials: mapToObject(credentials),
    orders: mapToObject(orders),
    messages: mapToObject(messages),
    walletTransactions: mapToObject(walletTransactions),
    notifications: mapToObject(notifications),
  };
}

async function connectMongo() {
  if (!mongoUri) {
    console.warn('MONGODB_URI is not set. Data will stay in memory and reset when the server restarts.');
    return;
  }
  mongoClient = new MongoClient(mongoUri);
  await mongoClient.connect();
  mongoDb = mongoClient.db(mongoDbName);
  useMongo = true;
  console.log(`MoveTraq API connected to MongoDB database "${mongoDbName}"`);
}

async function loadStore() {
  if (!useMongo) return;

  const store = await mongoDb.collection('appState').findOne({ _id: mongoStateId });
  if (!store) return;
  loadMap(users, store.users);
  loadMap(credentials, store.credentials);
  loadMap(orders, store.orders);
  loadMap(messages, store.messages);
  loadMap(walletTransactions, store.walletTransactions);
  loadMap(notifications, store.notifications);
}

async function saveStore() {
  if (!useMongo) return;

  const snapshot = storeSnapshot();
  await mongoDb.collection('appState').updateOne(
    { _id: mongoStateId },
    {
      $set: {
        ...snapshot,
        updatedAt: now(),
      },
    },
    { upsert: true },
  );
}

function now() {
  return new Date().toISOString();
}

function id(prefix) {
  return `${prefix}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
}

function json(res, status, body) {
  res.writeHead(status, {
    'content-type': 'application/json',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PATCH,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization',
  });
  res.end(JSON.stringify(body));
}

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.pbkdf2Sync(password, salt, 100000, 32, 'sha256').toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  const [salt, expected] = stored.split(':');
  const actual = hashPassword(password, salt).split(':')[1];
  return crypto.timingSafeEqual(Buffer.from(actual), Buffer.from(expected));
}

function base64url(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function signToken(userId) {
  const header = base64url({ alg: 'HS256', typ: 'JWT' });
  const payload = base64url({ sub: userId, iat: Math.floor(Date.now() / 1000) });
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
  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
    return null;
  }
  const decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
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
      return (
        order.senderId === user.uid ||
        order.delivererId === user.uid ||
        order.status === 'pendingOffer'
      );
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

const server = http.createServer(async (req, res) => {
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

    const body = ['POST', 'PATCH'].includes(req.method) ? await readBody(req) : {};

    if (req.method === 'POST' && path === '/auth/signup') {
      const email = String(body.email || '').trim().toLowerCase();
      const password = String(body.password || '');
      if (!email || password.length < 6) {
        json(res, 400, { error: 'Email and a 6 character password are required.' });
        return;
      }
      if ([...users.values()].some((user) => user.email.toLowerCase() === email)) {
        json(res, 409, { error: 'An account already exists for that email.' });
        return;
      }

      const user = {
        uid: id('user'),
        name: String(body.name || 'MoveTraq User').trim(),
        email,
        phone: String(body.phone || '').trim(),
        activeRole: 'sender',
        rating: 5,
        totalDeliveries: 128,
        memberTier: 'Gold',
        walletBalance: 42300,
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
      const login = String(body.emailOrPhone || '').trim().toLowerCase();
      const password = String(body.password || '');
      const user = [...users.values()].find(
        (item) => item.email.toLowerCase() === login || item.phone === body.emailOrPhone,
      );
      if (!user || !verifyPassword(password, credentials.get(user.email.toLowerCase()))) {
        json(res, 401, { error: 'Invalid email/phone or password.' });
        return;
      }
      json(res, 200, { token: signToken(user.uid), user });
      return;
    }

    if (req.method === 'POST' && path === '/auth/reset-password') {
      const rawLogin = String(body.emailOrPhone || '').trim();
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

    const user = requireAuth(req, res);
    if (!user) return;

    if (req.method === 'GET' && path === '/auth/me') {
      json(res, 200, { user });
      return;
    }

    if (req.method === 'PATCH' && path === '/users/me') {
      if (body.activeRole === 'sender' || body.activeRole === 'deliverer') {
        user.activeRole = body.activeRole;
      }
      if (typeof body.delivererOnline === 'boolean') {
        user.delivererOnline = body.delivererOnline;
      }
      await saveStore();
      json(res, 200, { user });
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

    if (req.method === 'GET' && path === '/orders') {
      json(res, 200, { orders: visibleOrders(user) });
      return;
    }

    if (req.method === 'POST' && path === '/orders') {
      const order = {
        ...body,
        id: id('order'),
        code: orderCode(),
        senderId: user.uid,
        senderName: user.name,
        payout: Number(body.payout || Math.max(0, Number(body.price || 0) - 500)),
        status: body.delivererId ? 'accepted' : body.status || 'pendingOffer',
        createdAt: now(),
        deliveredAt: null,
        releasedAt: null,
        dStage: 0,
      };
      orders.set(order.id, order);
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

      if (req.method === 'POST' && action === 'accept') {
        order.delivererId = body.delivererId || user.uid;
        order.delivererName = body.delivererName || user.name;
        order.status = 'accepted';
        order.dStage = 0;
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'stage') {
        const stage = Number(body.stage);
        const statuses = ['accepted', 'pickedUp', 'delivered'];
        if (!statuses[stage]) {
          json(res, 400, { error: 'Invalid delivery stage.' });
          return;
        }
        order.dStage = stage;
        order.status = statuses[stage];
        if (stage === 2) order.deliveredAt = now();
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'location') {
        order.courierLocation = {
          latitude: Number(body.latitude),
          longitude: Number(body.longitude),
        };
        order.simulatedLocation = false;
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'negotiate') {
        order.price = Number(body.price);
        order.status = 'negotiating';
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'confirm-price') {
        order.price = Number(body.price);
        order.status = 'pendingOffer';
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'release') {
        order.status = 'released';
        order.releasedAt = now();
        await saveStore();
        json(res, 200, { order });
        return;
      }

      if (req.method === 'POST' && action === 'cancel') {
        order.status = 'cancelled';
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
          const message = {
            id: id('msg'),
            senderId: String(body.senderId || user.uid),
            text: String(body.text || '').trim(),
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

    if (req.method === 'POST' && path === '/wallet/transactions') {
      const list = walletTransactions.get(user.uid) || [];
      list.push({
        id: id('tx'),
        type: body.type || 'topup',
        title: body.title || 'Wallet transaction',
        sub: body.sub || '',
        amount: Number(body.amount || 0),
        createdAt: now(),
      });
      walletTransactions.set(user.uid, list);
      user.walletBalance += Number(body.balanceDelta || 0);
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
  await connectMongo();
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
