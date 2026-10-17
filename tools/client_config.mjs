import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

// An allowlist prevents server secrets from entering Flutter's public bundle.
const allowed = ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY', 'CATALOG_BASE_URL',
  'REVENUECAT_ANDROID_PUBLIC_KEY', 'REVENUECAT_IOS_PUBLIC_KEY', 'WEB_CHECKOUT_URL', 'GOOGLE_AUTH_ENABLED', 'APPLE_AUTH_ENABLED'];
const values = {};
let text = '';
try { text = readFileSync('.env', 'utf8'); } catch (e) { if (e.code !== 'ENOENT') throw e; }
for (const line of text.split(/\r?\n/)) {
  const match = line.match(/^([A-Z_]+)=(.*)$/);
  if (match && allowed.includes(match[1])) values[match[1]] = match[2].trim().replace(/^(['"])(.*)\1$/, '$2');
}
for (const key of allowed) if (process.env[key]) values[key] = process.env[key];
if (values.SUPABASE_PUBLISHABLE_KEY && !values.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_')) {
  throw new Error('Use a Supabase publishable key; legacy and privileged keys are not accepted.');
}
mkdirSync('config', { recursive: true });
writeFileSync('config/client.json', JSON.stringify(values, null, 2));
console.log(`Prepared ${Object.values(values).filter(Boolean).length} public settings. No server secrets exported.`);
