export const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {status, headers: {...cors, 'Content-Type': 'application/json'}});
}
export function env(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server setting: ${name}`);
  return value;
}
export async function authenticate(request: Request) {
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) throw new Error('unauthorized');
  const response = await fetch(`${env('SUPABASE_URL')}/auth/v1/user`, {
    headers: {Authorization: authorization, apikey: env('SUPABASE_ANON_KEY')},
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error('unauthorized');
  const user = await response.json();
  if (!user.id || user.is_anonymous === true) throw new Error('unauthorized');
  return {id: user.id as string, authorization};
}
export async function rpc(name: string, body: unknown, authorization?: string) {
  const key = env(authorization ? 'SUPABASE_ANON_KEY' : 'SUPABASE_SERVICE_ROLE_KEY');
  const response = await fetch(`${env('SUPABASE_URL')}/rest/v1/rpc/${name}`, {
    method: 'POST', headers: {'Content-Type': 'application/json', apikey: key, Authorization: authorization ?? `Bearer ${key}`},
    body: JSON.stringify(body), signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error('database request rejected');
  return response.status === 204 ? null : response.json();
}
export async function readBody(request: Request, maximum = 100000) {
  const reader = request.body?.getReader();
  if (!reader) throw new Error('empty body');
  let size = 0;
  const parts: Uint8Array[] = [];
  while (true) {
    const {value, done} = await reader.read();
    if (done) break;
    size += value.length;
    if (size > maximum) { await reader.cancel(); throw new Error('body too large'); }
    parts.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const part of parts) {bytes.set(part, offset); offset += part.length;}
  return new TextDecoder().decode(bytes);
}
