alter table private.drop_days add column notification_key uuid not null default gen_random_uuid();
alter table private.drop_days add column notified_at timestamptz;
create function public.daily_notification_payload() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.ensure_drop();
 select jsonb_build_object('day',day,'idempotency_key',notification_key,'title','Your daily creative drop is ready','body','Three original prompts just unlocked. Claim today’s drop to keep it in your vault.') into result from private.drop_days where day=private.drop_day() and notified_at is null and now()>=opens_at and now()<opens_at+interval '10 minutes';
 return result;
end; $$;
create function public.mark_drop_notified(p_day date) returns void language sql security definer set search_path='' as $$ update private.drop_days set notified_at=now() where day=p_day; $$;
revoke all on function public.daily_notification_payload(),public.mark_drop_notified(date) from public,anon,authenticated;
grant execute on function public.daily_notification_payload(),public.mark_drop_notified(date) to service_role;
create extension if not exists pg_net with schema extensions;
select cron.schedule('promptvault-daily-notification','1,6 * * * *',$job$
 select net.http_post(url:='https://wtzpoahcqyxayxvumneu.supabase.co/functions/v1/daily-notify',headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='promptvault_daily_dispatch' limit 1)),body:='{}'::jsonb) where exists(select 1 from vault.decrypted_secrets where name='promptvault_daily_dispatch');
$job$);
