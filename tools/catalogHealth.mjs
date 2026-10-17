import policy from './catalog_policy.mjs';
import {createHash} from 'node:crypto';
const imageHosts = new Set(['images.unsplash.com']);
export function validRecord(item) {
  return item !== null && typeof item === 'object' && typeof item.id === 'string' && /^pv_[A-Za-z0-9_-]{1,90}$/.test(item.id)
    && typeof item.title === 'string' && item.title.trim().length > 0 && item.title.length <= 200
    && typeof item.raw_prompt === 'string' && item.raw_prompt.length <= 20000 && (item.is_pro_only === true || item.raw_prompt.trim().length > 0)
    && ['fashion','men','women','product_ads','thumbnails','ui_design','typography','3d_icons','logos','portraits'].includes(item.category)
    && item.safety_reviewed === true && Array.isArray(item.outputs) && item.outputs.length > 0
    && item.outputs.length <= 4 && item.outputs.every(o => {
      try { const u = new URL(o.image_url); return u.protocol === 'https:' && !u.username && !u.password && !u.port && imageHosts.has(u.hostname) && Number.isFinite(o.aspect_ratio) && o.aspect_ratio >= .25 && o.aspect_ratio <= 4; } catch { return false; }
    });
}
export const promptIdentity = text => text.normalize('NFKC').trim().replace(/\s+/gu, ' ').toLowerCase();
export const imageIdentity = url => {const u = new URL(url); return u.origin + u.pathname.replace(/\/+$/, '');};
export function uniqueItems(items) {
  const ids = new Set(), prompts = new Set(), images = new Set();
  return items.filter(validRecord).filter(item => {
    const prompt = promptIdentity(item.raw_prompt);
    const outputs = item.outputs.map(o => imageIdentity(o.image_url));
    if (!policy.publishable(!ids.has(item.id), policy.publishable(!prompt || !prompts.has(prompt), new Set(outputs).size === outputs.length && !outputs.some(key => images.has(key))))) return false;
    ids.add(item.id); if (prompt) prompts.add(prompt); outputs.forEach(key => images.add(key));
    return true;
  });
}
async function imageInfo(url, request = fetch) {
  let reader;
  try {
    const response = await request(url, {redirect:'error', signal:AbortSignal.timeout(15000)});
    reader = response.body?.getReader();
    if (!response.ok || Number(response.headers.get('content-length')) > 8000000 || !new RegExp('^image/(jpeg|png|webp|avif)(;|$)', 'i').test(response.headers.get('content-type') ?? '')) return null;
    if (!reader) return false;
    let bytes = new Uint8Array(), size = 0;
    const hash = createHash('sha256');
    while (true) {
      const part = await reader.read(); if (part.done) break;
      size += part.value.length; if (size > 8000000) return null;
      hash.update(part.value);
      const head = part.value.subarray(0, Math.max(0,16-bytes.length));
      const joined = new Uint8Array(bytes.length + head.length); joined.set(bytes); joined.set(head, bytes.length); bytes = joined;
    }
    const valid = (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255)
      || (bytes[0] === 137 && new TextDecoder().decode(bytes.subarray(1,4)) === 'PNG')
      || (new TextDecoder().decode(bytes.subarray(0,4)) === 'RIFF' && new TextDecoder().decode(bytes.subarray(8,12)) === 'WEBP')
      || (new TextDecoder().decode(bytes.subarray(4,8)) === 'ftyp' && /avif|avis/.test(new TextDecoder().decode(bytes.subarray(8,16))));
    return valid ? hash.digest('hex') : null;
  } catch { return null; }
  finally { await reader?.cancel().catch(() => {}); }
}
export async function workingImage(url, request = fetch) {return Boolean(await imageInfo(url,request));}
export async function healthyItems(items, request = fetch) {
  const checks = new Map();
  const valid = uniqueItems(items);
  for (const item of valid) for (const output of item.outputs) checks.set(output.image_url, false);
  const urls = [...checks.keys()];
  for (let i=0; i<urls.length; i+=4) await Promise.all(urls.slice(i,i+4).map(async url => checks.set(url, await imageInfo(url,request))));
  const seen = new Set();
  return valid.filter(item => {
    const hashes = item.outputs.map(o=>checks.get(o.image_url));
    if (hashes.some(h=>!h||seen.has(h)) || new Set(hashes).size!==hashes.length) return false;
    hashes.forEach(h=>seen.add(h)); return true;
  });
}
