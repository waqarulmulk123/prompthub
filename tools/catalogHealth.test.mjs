import {test} from 'node:test';
import assert from 'node:assert/strict';
import {healthyItems,validRecord,workingImage} from './catalogHealth.mjs';
const item={id:'pv_test',title:'Fashion',category:'fashion',raw_prompt:'Editorial',safety_reviewed:true,outputs:[{image_url:'https://images.unsplash.com/photo-1',aspect_ratio:.8}]};
test('exclude unreviewed, irrelevant categories, unsafe hosts and invalid ratios',()=>{
  assert.equal(validRecord(item),true);
  for (const patch of [{category:'spam'},{safety_reviewed:false},{outputs:[{image_url:'https://127.0.0.1/a',aspect_ratio:1}]},{outputs:[{image_url:item.outputs[0].image_url,aspect_ratio:Infinity}]}]) assert.equal(validRecord({...item,...patch}),false);
});
test('hide errors and HTML disguised as images; accept real image bytes',async()=>{
  assert.equal(await workingImage('x',async()=>{throw Error('offline')}),false);
  assert.equal(await workingImage('x',async()=>new Response('<html>bad</html>',{headers:{'content-type':'image/jpeg'}})),false);
  const request=async()=>new Response(new Uint8Array([255,216,255,224]),{headers:{'content-type':'image/jpeg'}});
  assert.equal(await workingImage('x',request),true);
  assert.equal((await healthyItems([item,{...item,id:'pv_bad',category:'spam'}],request)).length,1);
});
