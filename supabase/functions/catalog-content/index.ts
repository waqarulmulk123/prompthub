import {cors,env,json,rpc} from '../_shared/http.ts';
Deno.serve(async(request:Request)=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:{...cors,'Access-Control-Allow-Methods':'GET, OPTIONS'}});
 if(request.method!=='GET')return json({error:'Method not allowed'},405);
 try{
  const result=await rpc('published_catalog',{});
  const paths=result.prompts.filter((p:{image_path?:string})=>p.image_path).map((p:{image_path:string})=>p.image_path);
  if(paths.length){
   const key=env('SUPABASE_SERVICE_ROLE_KEY');
   const response=await fetch(env('SUPABASE_URL')+'/storage/v1/object/sign/catalog-media',{method:'POST',headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify({expiresIn:604800,paths}),signal:AbortSignal.timeout(15000)});
   if(!response.ok)throw Error();
   const signed=await response.json();const urls=new Map(signed.filter((r:{signedURL?:string})=>r.signedURL).map((r:{path:string,signedURL:string})=>[r.path,env('SUPABASE_URL')+'/storage/v1'+r.signedURL]));
   result.prompts=result.prompts.filter((p:{image_path?:string,outputs:unknown[]})=>{if(!p.image_path)return true;const url=urls.get(p.image_path);if(!url)return false;(p.outputs[0] as {image_url:unknown}).image_url=url;return true;});
  }
  for(const p of result.prompts)delete p.image_path;
  return new Response(JSON.stringify(result),{headers:{...cors,'Content-Type':'application/json','Cache-Control':'public, max-age=60'}});
 }catch{return json({error:'Catalog temporarily unavailable'},503);}
});
