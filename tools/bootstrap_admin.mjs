import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const response=await fetch('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.118.0/dist/umd/supabase.js',{signal:AbortSignal.timeout(30000)});
if(!response.ok)throw Error('Admin SDK download failed');
const bytes=Buffer.from(await response.arrayBuffer());
if(createHash('sha256').update(bytes).digest('hex')!=='ee3be8de192b97cb1d73d1e95d6b82bb1f6b658c0f97c4ef757fc331996ed3d3')throw Error('Admin SDK integrity mismatch');
await mkdir('admin/vendor',{recursive:true});await writeFile('admin/vendor/supabase.js',bytes);
console.log('Pinned admin SDK verified and ready.');
