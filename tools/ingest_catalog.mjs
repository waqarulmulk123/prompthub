import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import policy from './catalog_policy.mjs';
import {healthyItems} from './catalogHealth.mjs';
const allowedLicenses = new Set(['CC0-1.0','CC-BY-4.0','MIT']);
const sources = JSON.parse(readFileSync('catalog/sources.json','utf8'));
// Rebuild from owned templates, never retain imports from a failed/removed source.
const seed = JSON.parse(readFileSync('assets/catalog/feed_page_1.json','utf8')).prompts;
const results = await Promise.allSettled(sources.map(async source => {
  const url = new URL(source.url);
  if (url.protocol !== 'https:' || url.hostname !== 'raw.githubusercontent.com' || url.username || url.password || url.port) throw new Error('Unapproved source');
  if (!allowedLicenses.has(source.license) || !source.attribution || !source.license_url) throw new Error('Missing license');
  const response = await fetch(url,{redirect:'error',signal:AbortSignal.timeout(20000)});
  if (!response.ok || Number(response.headers.get('content-length')) > 5000000) throw new Error('Unavailable source');
  const reader=response.body.getReader(); const chunks=[]; let size=0;
  try { while(true) {const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>5000000)throw new Error('Oversized source');chunks.push(value);} } finally {await reader.cancel().catch(()=>{});}
  const text=Buffer.concat(chunks).toString('utf8');
  const body = JSON.parse(text); const records = Array.isArray(body) ? body : body.prompts;
  if (!Array.isArray(records) || records.length > 10000) throw new Error('Invalid source');
  return records.filter(record => policy.publishable(true,record.safety_reviewed===true)).map(record => ({...record,source_url:source.url,license:source.license,attribution:source.attribution}));
}));
const merged = new Map(seed.map(p => [p.id,p]));
for (const result of results) if (result.status === 'fulfilled') for (const item of result.value) {
  if (merged.has(item.id)) continue;
  item.raw_prompt = policy.public_text(item.is_pro_only === true,item.raw_prompt ?? '');
  if (item.is_pro_only) item.variables=[];
  merged.set(item.id,item);
}
const items = await healthyItems([...merged.values()]);
items.sort((a,b) => Math.max(0,Number(b.likes_count)||0)-Math.max(0,Number(a.likes_count)||0));
mkdirSync('catalog',{recursive:true});
const pages=[];
for (let i=0;i<items.length;i+=100) {
  const name='feed_page_'+(Math.floor(i/100)+1)+'.json';
  writeFileSync('catalog/'+name,JSON.stringify({prompts:items.slice(i,i+100)},null,2)); pages.push(name);
}
if (!pages.length) {pages.push('feed_page_1.json');writeFileSync('catalog/feed_page_1.json',JSON.stringify({prompts:[]}));}
writeFileSync('catalog/manifest.json',JSON.stringify({version:Date.now(),pages,count:items.length},null,2));
console.log(JSON.stringify({published:items.length,hidden:merged.size-items.length,failedSources:results.filter(r=>r.status==='rejected').length}));
