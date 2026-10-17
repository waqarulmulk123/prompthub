import {readFileSync,existsSync,mkdirSync,writeFileSync,renameSync} from 'node:fs';
import {dirname} from 'node:path';
import {createHash} from 'node:crypto';
const assets=JSON.parse(readFileSync('tools/assets_manifest.json','utf8'));
const hash=(bytes)=>createHash('sha256').update(bytes).digest('hex');
await Promise.all(assets.map(async asset=>{
  if(existsSync(asset.path)&&hash(readFileSync(asset.path))===asset.sha256)return;
  const response=await fetch(asset.url,{signal:AbortSignal.timeout(60000)});
  if(!response.ok)throw new Error(`Asset fetch failed: ${asset.path}`);
  const bytes=Buffer.from(await response.arrayBuffer());
  if(hash(bytes)!==asset.sha256)throw new Error(`Asset checksum mismatch: ${asset.path}`);
  mkdirSync(dirname(asset.path),{recursive:true});
  writeFileSync(asset.path+'.download',bytes);renameSync(asset.path+'.download',asset.path);
}));
console.log(`Verified ${assets.length} pinned font and SQLite assets.`);
