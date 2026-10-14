import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../utils/logger.js';

export function startLocationRetention() {
  let running = false;
  const timer = setInterval(async () => {
    if (running) return;
    running = true;
    try {
      const { error } = await supabaseAdmin.rpc('clear_expired_delivery_locations');
      if (error) logger.error({ code: error.code }, 'Location retention failed');
    } catch { logger.error('Location retention is unavailable'); }
    finally { running = false; }
  }, 60000);
  timer.unref();
  return () => clearInterval(timer);
}
