import {readFileSync,writeFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
const allowed=['ONESIGNAL_APP_ID','ONESIGNAL_REST_API_KEY','DROP_DISPATCH_SECRET','GEMINI_API_KEY','GEMINI_MODEL','REVENUECAT_WEBHOOK_SECRET','LEMONSQUEEZY_WEBHOOK_SECRET',
  'LEMONSQUEEZY_API_KEY','LEMONSQUEEZY_STORE_ID','LEMONSQUEEZY_MONTHLY_VARIANT_ID','LEMONSQUEEZY_YEARLY_VARIANT_ID'];
let local=readFileSync('.env','utf8');
const values={};
for(const line of local.split(/\r?\n/)) {
  const match=line.match(/^([A-Z_]+)=(.*)$/);
  if(match&&allowed.includes(match[1])&&match[2].trim())values[match[1]]=match[2].trim();
}
for(const key of allowed)if(process.env[key])values[key]=process.env[key];
for(const key of ['DROP_DISPATCH_SECRET','REVENUECAT_WEBHOOK_SECRET','LEMONSQUEEZY_WEBHOOK_SECRET']){
  if(!values[key])values[key]=randomBytes(32).toString('hex');
}
values.GEMINI_MODEL??='gemini-3.8-flash';
for(const [key,value] of Object.entries(values)){
  const pattern=new RegExp(`^${key}=.*$`,'m');
  local=pattern.test(local)?local.replace(pattern,`${key}=${value}`):`${local.trimEnd()}\n${key}=${value}\n`;
}
writeFileSync('.env',local,{mode:0o600});
writeFileSync('.env.server',Object.entries(values).map(([k,v])=>`${k}=${v}`).join('\n'),{mode:0o600});
console.log(`Prepared ${Object.keys(values).length} server settings; values kept private.`);
