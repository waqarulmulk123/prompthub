import {env, json, readBody, rpc} from '../_shared/http.ts';

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return json({error: 'Method not allowed'}, 405);
  const secret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
  if (!secret) return json({error: 'Webhook is not configured'}, 503);
  const received = request.headers.get('authorization') ?? '';
  const expected = `Bearer ${secret}`;
  // Compare digests to avoid string comparisons with prefix-dependent timing.
  const digest = async (value: string) => new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)));
  const [a,b] = await Promise.all([digest(received),digest(expected)]);
  if (a.reduce((n,x,i) => n | (x ^ b[i]), 0) !== 0) return json({error: 'Unauthorized'}, 401);
  try {
    const {event} = JSON.parse(await readBody(request));
    if (event?.type === 'TEST') return json({received:true});
    if (!event?.id || !/^[0-9a-f-]{36}$/i.test(event.app_user_id ?? '') || !Number.isFinite(event.event_timestamp_ms)) return json({error:'Invalid event'},400);
    const recognized = ['INITIAL_PURCHASE','RENEWAL','UNCANCELLATION','NON_RENEWING_PURCHASE','EXPIRATION','CANCELLATION','BILLING_ISSUE','SUBSCRIPTION_PAUSED','PRODUCT_CHANGE'];
    if (!recognized.includes(event.type) || !event.entitlement_ids?.includes('pro')) return json({received:true,ignored:true});
    // Cancellation does not revoke paid time; expiry decides whether access is still active.
    const expiry = event.expiration_at_ms ? new Date(event.expiration_at_ms).toISOString() : null;
    const active = event.type !== 'EXPIRATION' && (expiry == null || event.expiration_at_ms > Date.now());
    await rpc('apply_entitlement', {p_provider:'revenuecat',p_event_id:event.id,p_user_id:event.app_user_id,p_active:active,p_expires_at:expiry,p_event_at:new Date(event.event_timestamp_ms).toISOString()});
    return json({received:true});
  } catch { return json({error:'Could not process event'},400); }
});
