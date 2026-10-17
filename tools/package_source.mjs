import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const files=execFileSync('git',['ls-files','--cached','--others','--exclude-standard','-z'],{encoding:'utf8'}).split('\0').filter(Boolean);
const groups=[];
const binaries=[];
let group=[],size=0;
for(const path of files){
  if(path!=='.env.example'&&/(^|\/)\.env(?:\.|$)|(^|\/)key\.properties$|\.(jks|keystore|pem|p8)$/.test(path))throw new Error(`Secret file selected: ${path}`);
  const bytes=readFileSync(path);
  if(/\.(png|jpg|jpeg|gif|ico|jar)$/.test(path)){binaries.push({path,size:bytes.length});continue;}
  const content=bytes.toString('utf8');
  if(size+content.length>26000&&group.length){groups.push(group);group=[];size=0;}
  group.push({path,mode:'100644',type:'blob',content});size+=content.length;
}
if(group.length)groups.push(group);
mkdirSync('build',{recursive:true});
groups.forEach((items,i)=>writeFileSync(`build/github-tree-${i}.json`,JSON.stringify(items)));
writeFileSync('build/github-binaries.json',JSON.stringify(binaries));
console.log(JSON.stringify({groups:groups.length,binary:binaries.length,textFiles:files.length-binaries.length}));
