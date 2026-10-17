import {authenticate,cors,env,json,readBody,rpc} from '../_shared/http.ts';
import {boundedImage} from '../_shared/image.ts';
const headers=()=>({apikey:env('SUPABASE_SERVICE_ROLE_KEY'),Authorization:`Bearer ${env('SUPABASE_SERVICE_ROLE_KEY')}`});
const fail=(message:string,status=400)=>json({error:message},status);
Deno.serve(async(request:Request)=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return fail('Method not allowed',405);
 let user;try{user=await authenticate(request);const status=await rpc('admin_status',{},user.authorization);if(!status.allowed||!status.verified)return fail('Administrator access and authenticator verification required',403);}catch{return fail('Sign in required',401);}
 let body;try{body=JSON.parse(await readBody(request,3000000));if(!body||typeof body!=='object'||Array.isArray(body))throw Error();}catch{return fail('Invalid request');}
 let uploaded:string|undefined;
 try{
  if(body.action==='delete_user'){
   if(body.payload?.confirmation!=='DELETE')return fail('Explicit deletion confirmation required');
   const target=await rpc('admin_manage',{p_action:'authorize_delete_user',p_payload:{user_id:body.payload.user_id}},user.authorization);
   const base=env('SUPABASE_URL');let cleared=false;
   for(let batch=0;batch<100;batch++){
    const list=await fetch(base+'/storage/v1/object/list/remix-submissions',{method:'POST',headers:{...headers(),'Content-Type':'application/json'},body:JSON.stringify({prefix:target.user_id+'/',limit:100,offset:0}),signal:AbortSignal.timeout(10000)});
    if(!list.ok)throw Error();const files=await list.json();if(!Array.isArray(files))throw Error();if(!files.length){cleared=true;break;}
    if(files.some((f:{name:string})=>!/^[a-f0-9-]+\.(png|jpg)$/.test(f.name)))throw Error();
    const remove=await fetch(base+'/storage/v1/object/remix-submissions',{method:'DELETE',headers:{...headers(),'Content-Type':'application/json'},body:JSON.stringify({prefixes:files.map((f:{name:string})=>target.user_id+'/'+f.name)}),signal:AbortSignal.timeout(15000)});if(!remove.ok)throw Error();
   }
   if(!cleared)throw Error();
   const deleted=await fetch(base+'/auth/v1/admin/users/'+target.user_id,{method:'DELETE',headers:{...headers(),'Content-Type':'application/json'},body:JSON.stringify({should_soft_delete:false}),signal:AbortSignal.timeout(15000)});
   if(!deleted.ok)throw Error();return json({deleted:true});
  }
  if(body.action==='save_prompt'&&body.image_base64){
   if(typeof body.image_base64!=='string'||body.image_base64.length>2700000||!/^[A-Za-z0-9+/]+={0,2}$/.test(body.image_base64))return fail('Invalid image');
   const bytes=Uint8Array.from(atob(body.image_base64),(c)=>c.charCodeAt(0));
   if(bytes.length<64||bytes.length>2000000||bytes[0]!==255||bytes[1]!==216||!boundedImage(bytes))return fail('Compressed JPEG under 2 MB required');
   const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(x=>x.toString(16).padStart(2,'0')).join('');
   uploaded=`catalog/${crypto.randomUUID()}.jpg`;
   const response=await fetch(`${env('SUPABASE_URL')}/storage/v1/object/catalog-media/${uploaded}`,{method:'POST',headers:{...headers(),'Content-Type':'image/jpeg'},body:bytes,signal:AbortSignal.timeout(15000)});
   if(!response.ok)throw Error('storage');
   body.payload={...body.payload,image_path:uploaded,image_hash:hash,image_url:null};
  }
  const result=await rpc('admin_manage',{p_action:body.action,p_payload:body.payload??{}},user.authorization);
  if(body.action==='snapshot'){
   await Promise.all([['catalog-media',result.prompts],['remix-submissions',result.remixes]].map(async([bucket,rows]:[string,Array<{image_path?:string,image_url?:string}>])=>{
    const paths=rows.filter(r=>r.image_path).map(r=>r.image_path);if(!paths.length)return;
    const r=await fetch(`${env('SUPABASE_URL')}/storage/v1/object/sign/${bucket}`,{method:'POST',headers:{...headers(),'Content-Type':'application/json'},body:JSON.stringify({expiresIn:900,paths}),signal:AbortSignal.timeout(10000)});
    if(r.ok){const signed=await r.json();for(const row of rows){const item=signed.find((s:{path:string,signedURL?:string})=>s.path===row.image_path);if(item?.signedURL)row.image_url=env('SUPABASE_URL')+'/storage/v1'+item.signedURL;}}
   }));
  }
  if(result.remove_image){const r=await fetch(`${env('SUPABASE_URL')}/storage/v1/object/catalog-media/${result.remove_image}`,{method:'DELETE',headers:headers(),signal:AbortSignal.timeout(10000)}).catch(()=>null);if(!r?.ok&&r?.status!==404)result.warning='Content saved; old media cleanup needs retry.';delete result.remove_image;}
  return json(result);
 }catch{
  if(uploaded)await fetch(`${env('SUPABASE_URL')}/storage/v1/object/catalog-media/${uploaded}`,{method:'DELETE',headers:headers(),signal:AbortSignal.timeout(10000)}).catch(()=>{});
  return fail('Action rejected. Check required fields, duplicate content, current version and permissions.',409);
 }
});
