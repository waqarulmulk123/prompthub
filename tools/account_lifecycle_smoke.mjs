import {readFileSync,writeFileSync} from 'node:fs';
// Use only a disposable fixture created by the database test operator.
const config=JSON.parse(readFileSync('config/client.json','utf8'));
const fixture=JSON.parse(readFileSync(process.argv[2]??'build/account-lifecycle.json','utf8'));
if(!/^audit-[a-f0-9-]{36}@example\.invalid$/.test(fixture.email)||!fixture.id||!fixture.password)throw Error('Disposable fixture required');
const base=config.SUPABASE_URL,key=config.SUPABASE_PUBLISHABLE_KEY;
async function checked(path,options={}){const r=await fetch(base+path,{...options,signal:AbortSignal.timeout(20000)});if(!r.ok)throw Error('Lifecycle request failed: '+r.status+' '+path.split('?')[0]);return r;}
const signed=await (await checked('/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({email:fixture.email,password:fixture.password})})).json();
if(signed.user.id!==fixture.id)throw Error('Fixture owner mismatch');
const headers={apikey:key,Authorization:'Bearer '+signed.access_token,'Content-Type':'application/json'};
try {
 await checked('/rest/v1/rpc/save_prompt',{method:'POST',headers,body:JSON.stringify({p_prompt_id:'pv_001',p_variables:{}})});
 const pixel='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==';
 await checked('/functions/v1/community-remixes',{method:'POST',headers,body:JSON.stringify({action:'submit',prompt_id:'pv_001',caption:'Disposable lifecycle audit',rights_confirmed:true,image_base64:pixel})});
 const repeated=await fetch(base+'/functions/v1/community-remixes',{method:'POST',headers,body:JSON.stringify({action:'submit',prompt_id:'pv_001',caption:'Duplicate audit',rights_confirmed:true,image_base64:pixel}),signal:AbortSignal.timeout(20000)});
 if(repeated.ok)throw Error('Duplicate image accepted');
 const images=await (await checked('/rest/v1/community_remixes?select=image_path&user_id=eq.'+fixture.id,{headers})).json();
 if(images.length!==1)throw Error('Duplicate submission row created');
 if(!images[0]?.image_path)throw Error('Test upload missing');
 await checked('/functions/v1/delete-account',{method:'POST',headers,body:JSON.stringify({confirmation:'DELETE'})});
 const oldSession=await fetch(base+'/auth/v1/user',{headers,signal:AbortSignal.timeout(10000)});
 if(oldSession.ok)throw Error('Deleted account session was accepted');
 writeFileSync('build/account-lifecycle-result.json',JSON.stringify({user_id:fixture.id,image_path:images[0].image_path,accountDeletion:true,oldSessionRejected:true,duplicateImageRejected:true}));
 console.log(JSON.stringify({accountDeletion:true,oldSessionRejected:true}));
} finally {
 await fetch(base+'/functions/v1/delete-account',{method:'POST',headers,body:JSON.stringify({confirmation:'DELETE'}),signal:AbortSignal.timeout(20000)}).catch(()=>{});
}
