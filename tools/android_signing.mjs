import {existsSync,readFileSync,writeFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';
if(existsSync('android/key.properties')) {console.log('Release signing already configured.');process.exit(0);}
const password=randomBytes(32).toString('hex');
const result=spawnSync('keytool',['-genkeypair','-v','-keystore','android/app/promptvault-upload.jks','-storetype','PKCS12','-alias','promptvault-upload','-keyalg','RSA','-keysize','4096','-validity','10000','-storepass:env','PROMPTVAULT_SIGNING_PASSWORD','-keypass:env','PROMPTVAULT_SIGNING_PASSWORD','-dname','CN=PromptVault AI'],{env:{...process.env,PROMPTVAULT_SIGNING_PASSWORD:password},encoding:'utf8'});
if(result.status!==0)throw new Error('Could not generate upload signing key.');
writeFileSync('android/key.properties',`storeFile=promptvault-upload.jks\nstorePassword=${password}\nkeyAlias=promptvault-upload\nkeyPassword=${password}\n`,{mode:0o600});
writeFileSync('.env',readFileSync('.env','utf8').trimEnd()+`\nANDROID_KEYSTORE_PASSWORD=${password}\nANDROID_KEY_ALIAS=promptvault-upload\n`,{mode:0o600});
console.log('Generated a local Android upload key. Back up the ignored keystore and .env securely.');
