import { env } from './config/env.js';
import { createApp } from './app.js';
import { logger } from './utils/logger.js';
import { startLocationRetention } from './jobs/location-retention.js';

const app = createApp();
const stopLocationRetention = startLocationRetention();

const server = app.listen(env.PORT, () => {
  logger.info({ port: env.PORT }, 'MoveTraq backend listening');
});

let shuttingDown = false;
function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;
  stopLocationRetention();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
