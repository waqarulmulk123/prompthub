const imageHosts = new Set(['images.unsplash.com']);
export function validRecord(item) {
  return typeof item.id === 'string' && /^pv_[A-Za-z0-9_-]{1,90}$/.test(item.id)
    && typeof item.title === 'string' && item.title.trim().length > 0 && item.title.length <= 200
    && typeof item.raw_prompt === 'string' && item.raw_prompt.length <= 20000
    && ['fashion','men','women','product_ads','thumbnails','ui_design','typography','3d_icons','logos','portraits'].includes(item.category)
    && item.safety_reviewed === true && Array.isArray(item.outputs) && item.outputs.length > 0
    && item.outputs.length <= 4 && item.outputs.every(o => {
      try { const u = new URL(o.image_url); return u.protocol === 'https:' && !u.username && !u.password && !u.port && imageHosts.has(u.hostname) && Number.isFinite(o.aspect_ratio) && o.aspect_ratio >= .25 && o.aspect_ratio <= 4; } catch { return false; }
    });
}
export async function workingImage(url, request = fetch) {
  let reader;
  try {
    const response = await request(url, {redirect:'error', signal:AbortSignal.timeout(15000)});
    if (!response.ok || !new RegExp('^image/(jpeg|png|webp|avif)(;|$)', 'i').test(response.headers.get('content-type') ?? '')) return false;
    reader = response.body?.getReader();
    if (!reader) return false;
    let bytes = new Uint8Array();
    while (bytes.length < 16) {
      const part = await reader.read(); if (part.done) break;
      const joined = new Uint8Array(bytes.length + Math.min(part.value.length, 16)); joined.set(bytes); joined.set(part.value.subarray(0,16), bytes.length); bytes = joined;
    }
    return (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255)
      || (bytes[0] === 137 && new TextDecoder().decode(bytes.subarray(1,4)) === 'PNG')
      || (new TextDecoder().decode(bytes.subarray(0,4)) === 'RIFF' && new TextDecoder().decode(bytes.subarray(8,12)) === 'WEBP')
      || (new TextDecoder().decode(bytes.subarray(4,8)) === 'ftyp' && /avif|avis/.test(new TextDecoder().decode(bytes.subarray(8,16))));
  } catch { return false; }
  finally { await reader?.cancel().catch(() => {}); }
}
export async function healthyItems(items, request = fetch) {
  const checks = new Map();
  const valid = items.filter(validRecord);
  for (const item of valid) for (const output of item.outputs) checks.set(output.image_url, false);
  const urls = [...checks.keys()];
  for (let i=0; i<urls.length; i+=4) await Promise.all(urls.slice(i,i+4).map(async url => checks.set(url, await workingImage(url,request))));
  return valid.filter(item => item.outputs.every(o => checks.get(o.image_url)));
}
