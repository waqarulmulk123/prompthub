import {authenticate,cors,env,json,readBody} from '../_shared/http.ts';

// Only the validated session determines which account may be deleted.
Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: cors});
  if (request.method !== 'POST') return json({error: 'Method not allowed'}, 405);
  let user;
  try { user = await authenticate(request); } catch { return json({error: 'Sign in first'}, 401); }
  try {
    const body = JSON.parse(await readBody(request, 1000));
    if (body?.confirmation !== 'DELETE') return json({error: 'Explicit deletion confirmation required'}, 400);
  } catch { return json({error: 'Invalid request'}, 400); }
  const base = env('SUPABASE_URL');
  const key = env('SUPABASE_SERVICE_ROLE_KEY');
  const headers = {Authorization: `Bearer ${key}`, apikey: key, 'Content-Type': 'application/json'};
  try {
    // Remove stored images before the FK cascade; retry safely after partial storage failure.
    let cleared = false;
    for (let batch = 0; batch < 100; batch++) {
      const listed = await fetch(`${base}/storage/v1/object/list/remix-submissions`, {method: 'POST', headers, body: JSON.stringify({prefix: user.id + '/', limit: 100, offset: 0}), signal: AbortSignal.timeout(10000)});
      if (!listed.ok) throw Error('Storage unavailable');
      const objects = await listed.json();
      if (!Array.isArray(objects)) throw Error('Invalid storage response');
      if (objects.length === 0) {cleared = true; break;}
      if (objects.some((o: {name: string}) => !/^[a-f0-9-]+\.(png|jpg)$/.test(o.name))) throw Error('Unexpected storage path');
      const removed = await fetch(`${base}/storage/v1/object/remix-submissions`, {method: 'DELETE', headers, body: JSON.stringify({prefixes: objects.map((o: {name: string}) => `${user.id}/${o.name}`)}), signal: AbortSignal.timeout(15000)});
      if (!removed.ok) throw Error('Storage deletion failed');
    }
    if (!cleared) throw Error('Retry deletion to continue cleanup');
    const deleted = await fetch(`${base}/auth/v1/admin/users/${user.id}`, {method: 'DELETE', headers, body: JSON.stringify({should_soft_delete: false}), signal: AbortSignal.timeout(15000)});
    if (!deleted.ok) throw Error('Account deletion failed');
    return json({deleted: true});
  } catch { return json({error: 'Deletion could not finish. Retry to complete deletion.'}, 503); }
});
