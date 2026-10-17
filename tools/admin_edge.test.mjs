import {test} from 'node:test';
import assert from 'node:assert/strict';
let handler;
globalThis.Deno={env:{get:n=>({SUPABASE_URL:'https://test.supabase.co',SUPABASE_ANON_KEY:'anon',SUPABASE_SERVICE_ROLE_KEY:'service'}[n])},serve:fn=>handler=fn};
await import('../supabase/functions/admin-console/index.ts');
const admin=handler;
await import('../supabase/functions/catalog-content/index.ts');
const catalog=handler;
const originalFetch=globalThis.fetch;
const request=(body,auth=true)=>new Request('https://test.invalid',{method:'POST',headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer test'}:{})},body:JSON.stringify(body)});
test('admin API requires a live approved account and MFA; editable metadata grants nothing',async()=>{
 try{
  for(const status of [{allowed:false,verified:true},{allowed:true,verified:false}]){
   globalThis.fetch=async url=>Response.json(url.endsWith('/auth/v1/user')?{id:'test',user_metadata:{role:'admin'}}:status);
   assert.equal((await admin(request({action:'snapshot'},false))).status,401);
   assert.equal((await admin(request({action:'snapshot'}))).status,403);
  }
  globalThis.fetch=async url=>Response.json(url.endsWith('/auth/v1/user')?{id:'test'}:{allowed:true,verified:true});
  for(const value of [null,[],false,3])assert.equal((await admin(request(value))).status,400);
 }finally{globalThis.fetch=originalFetch;}
});
test('failed catalog write removes its newly uploaded media',async()=>{
 const calls=[];
 try{
  globalThis.fetch=async(url,opts={})=>{
   calls.push({url,opts});
   if(url.endsWith('/auth/v1/user'))return Response.json({id:'test'});
   if(url.endsWith('/rpc/admin_status'))return Response.json({allowed:true,verified:true});
   if(url.endsWith('/rpc/admin_manage'))return new Response('duplicate',{status:409});
   return Response.json({});
  };
  const bytes=Buffer.alloc(80);bytes.set([255,216,255,192,0,17,8,0,1,0,1],0);
  assert.equal((await admin(request({action:'save_prompt',payload:{},image_base64:bytes.toString('base64')}))).status,409);
  assert.equal(calls.filter(c=>c.opts.method==='DELETE'&&c.url.includes('/catalog-media/catalog/')).length,1);
 }finally{globalThis.fetch=originalFetch;}
});
test('public catalog signs only media selected by the trusted publication RPC',async()=>{
 try{
  globalThis.fetch=async(url,opts={})=>{
   if(url.endsWith('/rpc/published_catalog'))return Response.json({categories:{fashion:'Fashion'},announcement:'',prompts:[{id:'pv_one',image_path:'catalog/test.jpg',outputs:[{image_url:''}]}]});
   assert.deepEqual(JSON.parse(opts.body).paths,['catalog/test.jpg']);
   return Response.json([{path:'catalog/test.jpg',signedURL:'/object/sign/catalog-media/catalog/test.jpg?token=test'}]);
  };
  const response=await catalog(new Request('https://test.invalid'));const data=await response.json();
  assert.equal(response.status,200);assert.equal(data.prompts[0].image_path,undefined);
  assert.ok(data.prompts[0].outputs[0].image_url.startsWith('https://test.supabase.co/storage/v1/object/sign/catalog-media/'));
 }finally{globalThis.fetch=originalFetch;}
});
