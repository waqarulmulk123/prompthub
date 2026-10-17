import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const config=JSON.parse(readFileSync('config/client.json','utf8'));
const base=config.SUPABASE_URL;
const key=config.SUPABASE_PUBLISHABLE_KEY;
for(const table of ['collections','saved_prompts','entitlements','brand_dna','community_remixes']) {
  const response=await fetch(`${base}/rest/v1/${table}?select=*`,{headers:{apikey:key}});
  assert([401,403].includes(response.status),`Anonymous access must fail for ${table}`);
}
for(const name of ['reverse-prompt','create-checkout','boost-prompt','community-remixes','delete-account']) {
  const response=await fetch(`${base}/functions/v1/${name}`,{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:'{}'});
  assert.equal(response.status,401,`${name} must reject unsigned requests`);
}
const webhook=await fetch(`${base}/functions/v1/revenuecat-webhook`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer invalid-test-secret'},body:JSON.stringify({event:{type:'TEST'}})});
assert.equal(webhook.status,401,'Webhook must reject invalid signatures');
const dropResponse=await fetch(base+'/rest/v1/rpc/daily_drop',{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:'{}'});
assert(dropResponse.ok);
assert.equal((await dropResponse.json()).prompts.length,3);
const notify=await fetch(base+'/functions/v1/daily-notify',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer invalid-test-secret'},body:'{}'});
assert.equal(notify.status,401,'Scheduled dispatcher must reject invalid credentials');
const manifest=await fetch(`${config.CATALOG_BASE_URL}/manifest.json`);
assert(manifest.ok);
assert.equal(manifest.headers.get('access-control-allow-origin'),'*');
assert((await manifest.json()).count>0);
console.log('PASS: private tables, authenticated endpoints, webhook signature, public catalog and CORS.');
