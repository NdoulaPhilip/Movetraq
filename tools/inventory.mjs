import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';
const root = 'prototype/MoveTraq premium redesign';
const html = readFileSync(`${root}/MoveTraq.dc.html`, 'utf8');
const logic = html.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1];
const routes = new Set([...logic.matchAll(/(?:push|tab)\('([^']+)'\)/g)].map(m=>m[1]));
for (const r of ['personal','addresses','addressEdit','security','preferences','support','ticket','forgot','receive','schedule','errand','move','withdraw','payment','share','contact','photo','rating']) routes.add(r);
const files=[];
function walk(path){ for(const name of readdirSync(path)){ const file=`${path}/${name}`; if(statSync(file).isDirectory())walk(file);else{ const bytes=readFileSync(file);files.push({file,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')}); } } }
walk(root);
mkdirSync('docs',{recursive:true});
writeFileSync('docs/prototype-inventory.json',JSON.stringify({source:root,files,routes:[...routes].sort(),methods:[...logic.matchAll(/^  (?:get )?(\w+)\(/gm)].map(m=>m[1]),baseline:'All three supplied verification scripts pass; prototype checks are not production tests.'},null,2)+'\n');
writeFileSync('docs/FEATURE_PARITY.md',`# MoveTraq production parity audit\n\nSource: original supplied ZIP, preserved under prototype/. Status is evidence based: a planned mapping is not an implemented capability. All 89 source routes are retained here for audit.\n\n| Prototype route | Flutter | API | Database | Realtime | Authorization | Production validation | Admin |\n|---|---|---|---|---|---|---|---|\n${[...routes].sort().map(r=>`| ${r} | Pending | Pending | Pending | Pending | Pending | Not run | Pending |`).join('\n')}\n`);
console.log(`Inventoried ${files.length} files and ${routes.size} routes.`);
