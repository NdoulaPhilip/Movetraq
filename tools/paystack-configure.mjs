// Configure only the existing development API; never prints credential values.
import fs from 'node:fs';
import dotenv from '../backend/node_modules/dotenv/lib/main.js';
const env=dotenv.parse(fs.readFileSync(new URL('../backend/.env',import.meta.url)));
if(!env.PAYSTACK_SECRET_KEY?.startsWith('sk_test_'))throw new Error('A Paystack test secret key is required.');
const checked=await fetch('https://api.paystack.co/bank?country=nigeria&perPage=1',{headers:{Authorization:`Bearer ${env.PAYSTACK_SECRET_KEY}`},signal:AbortSignal.timeout(20000)});
if(!checked.ok || !(await checked.json()).status)throw new Error(`Paystack credential validation failed (${checked.status}).`);
console.log('Paystack test credential accepted.');
if(process.argv.includes('--deploy')){
 if(!env.RENDER_API_KEY)throw new Error('Render API credential is required.');
 const service='srv-db1bk2u0tbcc73ae81s0';
 async function render(path,method,body){const response=await fetch(`https://api.render.com/v1${path}`,{method,headers:{Authorization:`Bearer ${env.RENDER_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(30000)});if(!response.ok)throw new Error(`Render operation failed (${response.status}).`);return response.json();}
 await render(`/services/${service}/env-vars/PAYSTACK_SECRET_KEY`,'PUT',{value:env.PAYSTACK_SECRET_KEY});
 const deployment=await render(`/services/${service}/deploys`,'POST',{});
 console.log(JSON.stringify({service,deployment:deployment.id,status:deployment.status}));
}
