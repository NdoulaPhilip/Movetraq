const { timingSafeEqual, randomUUID } = require('node:crypto');
function authorized(header, secret) {
  if (!secret || secret.length < 32 || typeof header !== 'string') return false;
  const a = Buffer.from(header); const b = Buffer.from(`Bearer ${secret}`);
  return a.length === b.length && timingSafeEqual(a, b);
}
function category(path) {
  if (/payment|wallet|escrow|payout/.test(path)) return 'finance';
  if (/message|notification/.test(path)) return 'communication';
  if (/support|dispute|report/.test(path)) return 'support';
  if (/deliverer|verification/.test(path)) return 'deliverers';
  if (/order/.test(path)) return 'orders';
  return 'accounts';
}
function safeRoute(path) {
  return path.split('/').map(part => /^(?:mt-[a-f0-9]{64}|(?:user|order|msg|tx|notif)_[A-Za-z0-9_-]+)$/.test(part) ? ':id' : part.replace(/[^a-zA-Z0-9:_-]/g, '').slice(0,64)).join('/').slice(0,240);
}
async function beginAttempt(pool, req, actor) {
  const path = new URL(req.url,'http://localhost').pathname;
  const id = req.requestId || randomUUID();
  await pool.query(`insert into mobile_request_attempts(id,actor_id,method,route,category,order_id,reference)
    values($1,$2,$3,$4,$5,$6,$7)`, [id,actor || null,req.method,safeRoute(path),category(path),
    path.match(/^\/orders\/([^/]+)/)?.[1]?.slice(0,128) || null,path.match(/mt-[a-f0-9]{64}/)?.[0] || null]);
  return id;
}
async function finishAttempt(pool,id,status,result={}) {
  await pool.query(`update mobile_request_attempts set status=$2,outcome=$3,error_code=$4,finished_at=now(),
    actor_id=coalesce($5,actor_id),reference=coalesce($6,reference),order_id=coalesce($7,order_id) where id=$1`,
    [id,status,status<400?'successful':status===401||status===403?'rejected':'failed',status>=400?`HTTP_${status}`:null,
      result.actor || null,result.reference || null,result.order || null]);
}
async function monitoringData(pool, params) {
  const view=params.get('view') || 'activity'; const page=Number(params.get('page') || 0);
  if (!['activity','attempts','payments','ledger','orders','users','messages','notifications','support_tickets','wallet_transactions','saved_addresses','security_settings'].includes(view)
    || !Number.isSafeInteger(page) || page<0 || page>100000) throw Object.assign(new Error('Invalid monitoring filter.'),{status:400});
  const args=[]; const clauses=[]; const add=(sql,value)=>{args.push(value);clauses.push(sql.replace('?',`$${args.length}`));};
  const q=params.get('q'); if(q && q.length>128)throw Object.assign(new Error('Search is too long.'),{status:400});
  let table, fields, sort;
  if(view==='activity'){table='mobile_activity';fields='*';sort='created_at desc,id desc';}
  else if(view==='attempts'){table='mobile_request_attempts';fields='*,started_at as created_at';sort='started_at desc,id desc';}
  else {table='mobile_operation_records';fields='*,observed_at as created_at';sort='observed_at desc,entity_id';add('entity=?',view);}
  if(q)add(view==='activity'?"concat_ws(' ',entity_id,user_id,order_id,reference,event_type) ilike ?":view==='attempts'?"concat_ws(' ',actor_id,reference,route,order_id) ilike ?":"concat_ws(' ',entity_id,user_id,order_id,record::text) ilike ?",`%${q.replace(/[\\%_]/g,'\\$&')}%`);
  const where=clauses.length?' where '+clauses.join(' and '):'';
  const total=(await pool.query(`select count(*)::int as count from ${table}${where}`,args)).rows[0].count;
  const rows=(await pool.query(`select ${fields} from ${table}${where} order by ${sort} limit 25 offset $${args.length+1}`,[...args,page*25])).rows;
  const stats=(await pool.query(`select (select count(*)::int from users) users,(select count(*)::int from orders) orders,
    (select count(*)::int from legacy_wallet_topups) payments,(select count(*)::int from legacy_wallet_topups where status='verified') verified_payments,
    (select count(*)::int from mobile_request_attempts where outcome='failed') failed_operations,
    (select count(*)::int from mobile_request_attempts where outcome='pending') incomplete_operations`)).rows[0];
  return {source:'mobile_postgres',view,rows,total,stats,checkedAt:new Date().toISOString()};
}
module.exports={authorized,beginAttempt,finishAttempt,monitoringData,safeRoute};
async function reconcilePending(pool,payments) {
  const rows=(await pool.query(`select reference from legacy_wallet_topups where status<>'verified'
    and checkout_url is not null and created_at>now()-interval '7 days'
    and coalesce(last_checked_at,created_at)<now()-interval '5 minutes'
    order by coalesce(last_checked_at,created_at) limit 2`)).rows;
  for(const row of rows){
    const id=await beginAttempt(pool,{method:'POST',url:`/payments/${row.reference}/verify`});
    try { await payments.verify(row.reference);await finishAttempt(pool,id,200,{reference:row.reference}); }
    catch { await finishAttempt(pool,id,503,{reference:row.reference}); }
  }
}
module.exports.reconcilePending=reconcilePending;
