import {mkdtempSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const directory=mkdtempSync(join(tmpdir(),'promptvault-config-'));
try {
  writeFileSync(join(directory,'.env'),'SUPABASE_URL=https://example.supabase.co\nSUPABASE_PUBLISHABLE_KEY=sb_publishable_test\nGEMINI_API_KEY=server-only-sentinel\nSUPABASE_SERVICE_ROLE_KEY=never-export-this\n');
  const result=spawnSync(process.execPath,[resolve('tools/client_config.mjs')],{cwd:directory,env:{PATH:process.env.PATH},encoding:'utf8'});
  assert.equal(result.status,0);
  const client=readFileSync(join(directory,'config/client.json'),'utf8');
  assert(!client.includes('server-only-sentinel'));
  assert(!client.includes('never-export-this'));
  assert.deepEqual(Object.keys(JSON.parse(client)).sort(),['SUPABASE_PUBLISHABLE_KEY','SUPABASE_URL']);
  writeFileSync(join(directory,'.env'),'SUPABASE_PUBLISHABLE_KEY=sb_secret_invalid\n');
  const rejected=spawnSync(process.execPath,[resolve('tools/client_config.mjs')],{cwd:directory,env:{PATH:process.env.PATH},encoding:'utf8'});
  assert.notEqual(rejected.status,0);
  console.log('PASS: only publishable settings reach Flutter; privileged keys rejected.');
} finally {rmSync(directory,{recursive:true,force:true});}
