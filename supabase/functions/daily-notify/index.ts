import {env,json,rpc} from '../_shared/http.ts';
Deno.serve(async(request:Request)=>{
 if(request.method!=='POST')return json({error:'Method not allowed'},405);
 const secret=Deno.env.get('DROP_DISPATCH_SECRET');
 const supplied=request.headers.get('Authorization')?.replace(/^Bearer /,'')??'';
 if(!secret)return json({error:'Notifications are not configured'},503);
 const digest=async(value:string)=>new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)));
 const a=await digest(secret),b=await digest(supplied);let difference=0;for(let i=0;i<a.length;i++)difference|=a[i]^b[i];
 if(difference!==0)return json({error:'Unauthorized'},401);
 const appId=Deno.env.get('ONESIGNAL_APP_ID'),key=Deno.env.get('ONESIGNAL_REST_API_KEY');
 if(!appId||!key)return json({error:'Notification delivery is not configured'},503);
 try {
  const payload=await rpc('daily_notification_payload',{});
  if(!payload)return json({skipped:true});
  const response=await fetch('https://api.onesignal.com/notifications',{method:'POST',headers:{Authorization:'Key '+key,'Content-Type':'application/json'},signal:AbortSignal.timeout(20000),body:JSON.stringify({app_id:appId,idempotency_key:payload.idempotency_key,target_channel:'push',included_segments:['Subscribed Users'],headings:{en:payload.title},contents:{en:payload.body},url:'https://promptvault-ai.pages.dev/'})});
  const result=await response.json();
  if(!response.ok)return json({error:'Notification provider unavailable'},502);
  // Empty audience is a valid no-delivery outcome; never report it as a delivered push.
  if(!result.id)return json({skipped:true,reason:'No subscribed audience'});
  await rpc('mark_drop_notified',{p_day:payload.day});return json({accepted:true,id:result.id});
 }catch{return json({error:'Notification dispatch unavailable'},502);}
});
