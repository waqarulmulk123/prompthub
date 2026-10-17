import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve,sep} from 'node:path';
import {spawnSync} from 'node:child_process';

test('private seeding validates inventory, escapes text and never logs contents',()=>{
 const directory=mkdtempSync(join(tmpdir(),'promptvault-private-'));
 try {
  mkdirSync(join(directory,'config'));
  const prompt="Original studio image of [Product: O'Brien's ceramic cup], using [Light: soft daylight], a restrained palette and clean commercial composition. Show precise materials, contact shadows and natural texture. ";
  const source={reviewed:true,license:'CC0-1.0',daily:[0,1,2].map(i=>({title:'Original '+i,category:'product_ads',raw_prompt:prompt+'Variation '+i})),packs:[{title:'Pack',category:'product_ads',raw_prompt:prompt+prompt}]};
  const fixture=join(directory,'config','fixture.json');writeFileSync(fixture,JSON.stringify(source));
  const run=()=>spawnSync(process.execPath,[resolve('tools/prepare_private_content.mjs'),fixture],{cwd:directory,encoding:'utf8'});
  const result=run();assert.equal(result.status,0);assert(!result.stdout.includes("O'Brien"));
  const sql=readFileSync(join(directory,'config','editorial.private.sql'),'utf8');
  assert(sql.includes("O''Brien''s"));assert(!sql.includes('delete from private.drop_days'));
  const variableText=sql.slice(sql.indexOf('insert into private.premium_prompts'));
  assert.equal((variableText.match(/"key":"Product"/g)??[]).length,1);
  source.daily[1].raw_prompt=source.daily[0].raw_prompt;writeFileSync(fixture,JSON.stringify(source));assert.notEqual(run().status,0);
 } finally {
  assert(resolve(directory).startsWith(resolve(tmpdir())+sep));rmSync(directory,{recursive:true,force:true});
 }
});
