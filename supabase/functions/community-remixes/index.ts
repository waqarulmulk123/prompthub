import {authenticate,cors,env,json,readBody,rpc} from '../_shared/http.ts';
import {boundedImage} from '../_shared/image.ts';
const storageHeaders=()=>({apikey:env('SUPABASE_SERVICE_ROLE_KEY'),Authorization:`Bearer ${env('SUPABASE_SERVICE_ROLE_KEY')}`});
Deno.serve(async(request:Request)=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return json({error:'Method not allowed'},405);
 let body;try{body=JSON.parse(await readBody(request,2800000));if(!body||typeof body!=='object'||Array.isArray(body))throw Error();}catch{return json({error:'Invalid request'},400);}
 if(body.action==='list'){
  if(typeof body.prompt_id!=='string'||body.prompt_id.length>100)return json({error:'Invalid prompt'},400);
  let authorization;try{authorization=(await authenticate(request)).authorization;}catch{/* Public approved gallery. */}
  try{const rows=await rpc('list_remixes',{p_prompt:body.prompt_id,p_offset:Number.isInteger(body.offset)?Math.max(0,body.offset):0},authorization);
   const items=await Promise.all(rows.map(async(row:{image_path:string})=>{const response=await fetch(`${env('SUPABASE_URL')}/storage/v1/object/sign/remix-submissions/${row.image_path}`,{method:'POST',headers:{...storageHeaders(),'Content-Type':'application/json'},body:JSON.stringify({expiresIn:900}),signal:AbortSignal.timeout(10000)});if(!response.ok)return null;const signed=await response.json();return {...row,image_url:env('SUPABASE_URL')+'/storage/v1'+signed.signedURL};}));return json({items:items.filter(Boolean)});
  }catch{return json({error:'Gallery unavailable'},503);}
 }
 let user;try{user=await authenticate(request);}catch{return json({error:'Sign in to submit a remix'},401);}
 if(body.action==='delete') {
  if(typeof body.id!=='string'||!/^[-a-f0-9]{36}$/.test(body.id))return json({error:'Invalid remix'},400);
  try{const path=await rpc('own_remix_path',{p_id:body.id},user.authorization);if(!path)return json({deleted:true});const response=await fetch(env('SUPABASE_URL')+'/storage/v1/object/remix-submissions/'+path,{method:'DELETE',headers:storageHeaders(),signal:AbortSignal.timeout(10000)});if(!response.ok&&response.status!==404)throw Error();await rpc('delete_remix',{p_id:body.id},user.authorization);return json({deleted:true});}catch{return json({error:'Deletion unavailable. Please retry.'},503);}
 }
 if(body.action!=='submit'||body.rights_confirmed!==true||typeof body.prompt_id!=='string'||!/^(pv_[A-Za-z0-9_-]+|drop_[0-9]{8}_[1-3])$/.test(body.prompt_id)||typeof body.caption!=='string'||body.caption.length>300||typeof body.image_base64!=='string'||body.image_base64.length>2700000||!/^[A-Za-z0-9+/]+={0,2}$/.test(body.image_base64))return json({error:'Valid image, prompt and ownership confirmation required'},400);
 let bytes:Uint8Array;try{bytes=Uint8Array.from(atob(body.image_base64),(c)=>c.charCodeAt(0));}catch{return json({error:'Invalid image'},400);}
 const png=bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71;const jpeg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
 if(bytes.length<64||bytes.length>2000000||!png&&!jpeg||!boundedImage(bytes))return json({error:'Upload a PNG or JPEG under 2 MB and 4096 pixels per side'},400);
 const digest=await crypto.subtle.digest('SHA-256',bytes);
 const contentHash=Array.from(new Uint8Array(digest)).map(x=>x.toString(16).padStart(2,'0')).join('');
 let reservation:string;try{reservation=await rpc('consume_usage',{p_feature:'remix_upload'},user.authorization);}catch{return json({error:'Daily submission limit reached'},429);}
 const path=`${user.id}/${crypto.randomUUID()}.${png?'png':'jpg'}`;const endpoint=`${env('SUPABASE_URL')}/storage/v1/object/remix-submissions/${path}`;
 try{const response=await fetch(endpoint,{method:'POST',headers:{...storageHeaders(),'Content-Type':png?'image/png':'image/jpeg'},body:bytes,signal:AbortSignal.timeout(15000)});if(!response.ok)throw Error();const id=await rpc('submit_remix',{p_user:user.id,p_prompt:body.prompt_id,p_caption:body.caption.trim(),p_path:path,p_hash:contentHash});return json({id,status:'pending'});}
 catch{await rpc('refund_usage',{p_user_id:user.id,p_request_id:reservation}).catch(()=>{});await fetch(endpoint,{method:'DELETE',headers:storageHeaders(),signal:AbortSignal.timeout(10000)}).catch(()=>{});return json({error:'Upload unavailable or daily submission limit reached'},429);}
});
