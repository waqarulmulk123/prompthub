import {test} from 'node:test';
import assert from 'node:assert/strict';
import {healthyItems,validRecord,workingImage,uniqueItems} from './catalogHealth.mjs';
const item={id:'pv_test',title:'Fashion',category:'fashion',raw_prompt:'Editorial',safety_reviewed:true,outputs:[{image_url:'https://images.unsplash.com/photo-1',aspect_ratio:.8}]};
test('exclude unreviewed, irrelevant categories, unsafe hosts and invalid ratios',()=>{
  for (const value of [null,undefined,[],3,'spam']) assert.equal(validRecord(value),false);
  assert.equal(validRecord(item),true);
  for (const patch of [{category:'spam'},{safety_reviewed:false},{outputs:[{image_url:'https://127.0.0.1/a',aspect_ratio:1}]},{outputs:[{image_url:item.outputs[0].image_url,aspect_ratio:Infinity}]}]) assert.equal(validRecord({...item,...patch}),false);
});
test('deduplicate IDs, normalized prompts and source images across transforms',()=>{
  const next=(id,text,url)=>({...item,id,raw_prompt:text,outputs:[{image_url:url,aspect_ratio:1}]});
  const base='https://images.unsplash.com/photo-';
  const rows=[item,next('pv_2',' EDITORIAL  ',base+'2'),next('pv_3','Another',base+'1?w=400'),next('pv_4','Different',base+'4'),next('pv_4','Unique',base+'5')];
  assert.deepEqual(uniqueItems(rows).map(x=>x.id),['pv_test','pv_4']);
});
test('hide errors and HTML disguised as images; accept real image bytes',async()=>{
  assert.equal(await workingImage('x',async()=>{throw Error('offline')}),false);
  assert.equal(await workingImage('x',async()=>new Response('<html>bad</html>',{headers:{'content-type':'image/jpeg'}})),false);
  const request=async()=>new Response(new Uint8Array([255,216,255,224]),{headers:{'content-type':'image/jpeg'}});
  assert.equal(await workingImage('x',request),true);
  assert.equal((await healthyItems([item,{...item,id:'pv_bad',category:'spam'}],request)).length,1);
});
test('hide byte-identical images under different source URLs',async()=>{
  const request=async()=>new Response(new Uint8Array([255,216,255,224]),{headers:{'content-type':'image/jpeg'}});
  const copy={...item,id:'pv_copy',raw_prompt:'Another prompt',outputs:[{image_url:'https://images.unsplash.com/photo-alias',aspect_ratio:1}]};
  assert.equal((await healthyItems([item,copy],request)).length,1);
});
