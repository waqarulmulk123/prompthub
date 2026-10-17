import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import assert from 'node:assert/strict';
// Editorial data stays separate from public schema/source. History and claims are preserved.
const data=JSON.parse(readFileSync(process.argv[2]??'config/editorial.private.json','utf8'));
assert(data.reviewed===true&&data.license==='CC0-1.0','Reviewed original content required');
assert(Array.isArray(data.daily)&&data.daily.length>=3&&data.daily.length<=90&&Array.isArray(data.packs)&&data.packs.length<=30);
const records=[...data.daily,...data.packs],categories=new Set(['product_ads','thumbnails','ui_design','typography','3d_icons','logos','fashion','men','women','portraits']);
for(const p of records)assert(typeof p.title==='string'&&p.title.length>0&&p.title.length<=140&&typeof p.raw_prompt==='string'&&p.raw_prompt.length>=150&&p.raw_prompt.length<=10000&&categories.has(p.category),'Invalid editorial entry');
assert(new Set(records.map(p=>p.raw_prompt.normalize('NFKC').trim().replace(/\s+/gu,' ').toLowerCase())).size===records.length,'Duplicate editorial text');
const quote=text=>"'"+String(text).replaceAll("'","''")+"'";
const json=value=>quote(JSON.stringify(value))+'::jsonb';
const daily=data.daily.map((p,i)=>'('+i+','+json({...p,id:'pool_'+i,outputs:[],variables:[],is_pro_only:false,likes_count:0,tags:['daily','original'],attribution:'Original PromptVault daily text template. No generated image is supplied.',license:'CC0-1.0',safety_reviewed:true,verified:false})+')');
const packs=data.packs.map((p,i)=>{
  const variables=[];
  for(const m of p.raw_prompt.matchAll(/\[([^:\[\]]+):\s*([^\[\]]+)\]/g))if(!variables.some(v=>v.key===m[1].trim()))variables.push({key:m[1].trim(),default_value:m[2].trim(),suggestions:[]});
  return '('+quote('pv_pro_'+String(i+1).padStart(3,'0'))+','+quote(p.raw_prompt)+','+json(variables)+')';
});
let sql='begin;\nset local standard_conforming_strings=on;\ndelete from private.drop_pool;\ninsert into private.drop_pool(slot,prompt) values\n'+daily.join(',\n')+';\n';
if(packs.length)sql+='insert into private.premium_prompts(id,raw_prompt,variables) values\n'+packs.join(',\n')+'\non conflict(id) do update set raw_prompt=excluded.raw_prompt,variables=excluded.variables;\n';
sql+='commit;\n';
mkdirSync('config',{recursive:true});writeFileSync('config/editorial.private.sql',sql,{mode:0o600});
console.log(JSON.stringify({daily:data.daily.length,commercialPacks:data.packs.length,preparedPrivately:true}));
