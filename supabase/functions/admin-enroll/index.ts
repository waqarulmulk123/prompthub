import {cors,env,json,readBody,rpc} from '../_shared/http.ts';
Deno.serve(async(request:Request)=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return json({error:'Method not allowed'},405);
 let body;try{body=JSON.parse(await readBody(request,8000));if(!body||typeof body!=='object'||Array.isArray(body))throw Error();}catch{return json({error:'Invalid request'},400);}
 if(typeof body.token!=='string'||!/^[a-f0-9]{64}$/.test(body.token)||typeof body.password!=='string'||body.password.length<12||body.password.length>128)return json({error:'Valid invitation and a password of 12–128 characters required'},400);
 let invitation;try{invitation=await rpc('claim_admin_invite',{p_token:body.token});if(!invitation?.email)throw Error();}catch{return json({error:'Invitation is invalid, expired or already used. Sign in if you registered previously.'},403);}
 const key=env('SUPABASE_SERVICE_ROLE_KEY');
 try{
  const response=await fetch(env('SUPABASE_URL')+'/auth/v1/admin/users',{method:'POST',headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify({email:invitation.email,password:body.password,email_confirm:true}),signal:AbortSignal.timeout(15000)});
  if(!response.ok)throw Error();
  return json({registered:true,email:invitation.email});
 }catch{
  // A failed creation may be retried only if no account was created for this invitation.
  await rpc('release_admin_invite',{p_token:body.token}).catch(()=>{});
  return json({error:'Registration could not finish. Try signing in if your account was created, or retry this invitation.'},409);
 }
});
