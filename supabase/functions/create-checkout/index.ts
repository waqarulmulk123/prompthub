import {authenticate,cors,env,json,readBody} from '../_shared/http.ts';

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok',{headers:cors});
  if (request.method !== 'POST') return json({error:'Method not allowed'},405);
  let user;
  try {user=await authenticate(request);} catch {return json({error:'Sign in first'},401);}
  const key=Deno.env.get('LEMONSQUEEZY_API_KEY');
  if (!key) return json({error:'Checkout is not configured yet'},503);
  try {
    const {plan}=JSON.parse(await readBody(request,1000));
    if (!['monthly','yearly'].includes(plan)) return json({error:'Invalid plan'},400);
    const variant=env(plan==='monthly'?'LEMONSQUEEZY_MONTHLY_VARIANT_ID':'LEMONSQUEEZY_YEARLY_VARIANT_ID');
    const response=await fetch('https://api.lemonsqueezy.com/v1/checkouts',{
      method:'POST',headers:{Authorization:`Bearer ${key}`,Accept:'application/vnd.api+json','Content-Type':'application/vnd.api+json'},signal:AbortSignal.timeout(15000),
      body:JSON.stringify({data:{type:'checkouts',attributes:{checkout_data:{custom:{user_id:user.id}}},relationships:{store:{data:{type:'stores',id:env('LEMONSQUEEZY_STORE_ID')}},variant:{data:{type:'variants',id:variant}}}}}),
    });
    if(!response.ok) throw new Error('Checkout unavailable');
    const body=await response.json();
    return json({url:body.data.attributes.url});
  } catch {return json({error:'Could not create checkout'},502);}
});
