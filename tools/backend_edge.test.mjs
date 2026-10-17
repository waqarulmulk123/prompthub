import {test} from 'node:test';
import assert from 'node:assert/strict';
import {boundedImage} from '../supabase/functions/_shared/image.ts';

let handler;
const userId='11111111-1111-4111-8111-111111111111';
globalThis.Deno={env:{get:name=>({SUPABASE_URL:'https://test.supabase.co',SUPABASE_ANON_KEY:'test-anon',SUPABASE_SERVICE_ROLE_KEY:'test-service',GEMINI_API_KEY:'test-gemini'}[name])},serve:fn=>{handler=fn;}};
await import('../supabase/functions/delete-account/index.ts');const deletion=handler;
await import('../supabase/functions/community-remixes/index.ts');const community=handler;
await import('../supabase/functions/reverse-prompt/index.ts');const reverse=handler;
const request=body=>new Request('https://test.invalid',{method:'POST',headers:{Authorization:'Bearer test','Content-Type':'application/json'},body:JSON.stringify(body)});
const originalFetch=globalThis.fetch;
test('server rejects compressed image bombs and malformed dimensions',()=>{
  const pixel=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==','base64');
  assert.equal(boundedImage(pixel),true);
  const bomb=Buffer.from(pixel);bomb.writeUInt32BE(100000,16);
  assert.equal(boundedImage(bomb),false);
  assert.equal(boundedImage(Uint8Array.from([255,216,255,224,0,0])),false);
});
test('delete account requires authentication and explicit confirmation',async()=>{
  try {
    globalThis.fetch=async()=>Response.json({id:userId});
    assert.equal((await deletion(new Request('https://test.invalid',{method:'POST'}))).status,401);
    assert.equal((await deletion(request({confirmation:'KEEP'}))).status,400);
  } finally {globalThis.fetch=originalFetch;}
});
test('delete only session-owned files before deleting the authenticated user',async()=>{
  const calls=[];let listCount=0;
  try {
    globalThis.fetch=async(url,options={})=>{
      calls.push({url,method:options.method??'GET',body:options.body?JSON.parse(options.body):null});
      if(url.endsWith('/auth/v1/user'))return Response.json({id:userId});
      if(url.includes('/object/list/'))return Response.json(listCount++===0?[{name:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.jpg'}]:[]);
      return Response.json({});
    };
    assert.equal((await deletion(request({confirmation:'DELETE',user_id:'another-user'}))).status,200);
    const deletes=calls.filter(c=>c.method==='DELETE');
    assert.equal(deletes.length,2);
    assert.deepEqual(deletes[0].body.prefixes,[userId+'/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.jpg']);
    assert.ok(deletes[1].url.endsWith('/admin/users/'+userId));
  } finally {globalThis.fetch=originalFetch;}
});
test('storage failure leaves account intact for a safe retry',async()=>{
  const calls=[];
  try {
    globalThis.fetch=async(url)=>{calls.push(url);return url.endsWith('/auth/v1/user')?Response.json({id:userId}):new Response('failed',{status:503});};
    assert.equal((await deletion(request({confirmation:'DELETE'}))).status,503);
    assert.ok(calls.every(url=>!url.includes('/admin/users/')));
  } finally {globalThis.fetch=originalFetch;}
});
test('malformed JSON values produce client errors rather than crashes',async()=>{
  try {
    globalThis.fetch=async()=>Response.json({id:userId});
    for(const value of [null,[],false,3,'spam']){
      assert.equal((await community(request(value))).status,400);
      assert.equal((await reverse(request(value))).status,400);
    }
  } finally {globalThis.fetch=originalFetch;}
});
