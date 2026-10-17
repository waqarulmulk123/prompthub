import {json,readBody,rpc} from '../_shared/http.ts';

Deno.serve(async(request:Request)=>{
  if(request.method!=='POST')return json({error:'Method not allowed'},405);
  const secret=Deno.env.get('LEMONSQUEEZY_WEBHOOK_SECRET');
  if(!secret)return json({error:'Webhook is not configured'},503);
  let raw;
  try{raw=await readBody(request);}catch{return json({error:'Invalid request'},400);}
  const signature=request.headers.get('x-signature')??'';
  if(!/^[a-f0-9]{64}$/i.test(signature))return json({error:'Invalid signature'},401);
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
  const signed=Uint8Array.from(signature.match(/../g)!,pair=>parseInt(pair,16));
  if(!await crypto.subtle.verify('HMAC',key,signed,new TextEncoder().encode(raw)))return json({error:'Invalid signature'},401);
  try{
    const body=JSON.parse(raw);
    const userId=body.meta?.custom_data?.user_id;
    const event=body.meta?.event_name;
    const attributes=body.data?.attributes;
    const store=Deno.env.get('LEMONSQUEEZY_STORE_ID');
    const variants=[Deno.env.get('LEMONSQUEEZY_MONTHLY_VARIANT_ID'),Deno.env.get('LEMONSQUEEZY_YEARLY_VARIANT_ID')].filter(Boolean);
    if(!store||!variants.length)return json({error:'Merchant products are not configured'},503);
    if(!/^[0-9a-f-]{36}$/i.test(userId??'')||String(attributes?.store_id)!==store||!variants.includes(String(attributes?.variant_id)))return json({error:'Unrecognized purchase'},400);
    if(!['subscription_created','subscription_updated','subscription_cancelled','subscription_resumed','subscription_expired','subscription_paused','subscription_unpaused'].includes(event))return json({received:true,ignored:true});
    const expires=attributes.ends_at??attributes.renews_at??null;
    const active=['active','on_trial','cancelled'].includes(attributes.status)&&(expires===null||new Date(expires).getTime()>Date.now());
    const eventAt=attributes.updated_at??attributes.created_at;
    if(!Number.isFinite(new Date(eventAt).getTime()))return json({error:'Invalid event time'},400);
    const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(raw));
    const id=Array.from(new Uint8Array(digest)).map(x=>x.toString(16).padStart(2,'0')).join('');
    await rpc('apply_entitlement',{p_provider:'lemonsqueezy',p_event_id:id,p_user_id:userId,p_active:active,p_expires_at:expires,p_event_at:eventAt});
    return json({received:true});
  }catch{return json({error:'Could not process event'},400);}
});
