-- Server-authoritative drops, permanent claims, rewards, Brand DNA and moderation.
create table private.drop_pool (slot integer primary key, prompt jsonb not null);
create table private.drop_days (day date primary key, opens_at timestamptz not null, expires_at timestamptz not null, prompts jsonb not null);
create table private.drop_claims (user_id uuid references auth.users on delete cascade, day date references private.drop_days, claimed_at timestamptz not null default now(), primary key(user_id,day));
create table private.creator_stats (user_id uuid primary key references auth.users on delete cascade, last_day date, streak integer not null default 0, reverse_credits integer not null default 0 check(reverse_credits>=0));
create table private.weekly_winners (week date primary key, user_id uuid not null references auth.users on delete cascade, remix_id uuid not null, expires_at timestamptz not null);
create table public.brand_dna (user_id uuid primary key references auth.users on delete cascade, product text not null check(length(btrim(product)) between 1 and 200), colors text not null check(length(btrim(colors)) between 1 and 200), vibe text not null check(length(btrim(vibe)) between 1 and 300), updated_at timestamptz not null default now());
create table public.community_remixes (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users on delete cascade, prompt_id text not null check(length(prompt_id) between 1 and 100), caption text not null check(length(caption)<=300), image_path text not null unique, status text not null default 'pending' check(status in('pending','approved','rejected')), rights_confirmed boolean not null check(rights_confirmed), created_at timestamptz not null default now());
create index community_prompt_idx on public.community_remixes(prompt_id,status,created_at desc);
create index community_user_idx on public.community_remixes(user_id,created_at desc);
create table private.remix_votes (remix_id uuid references public.community_remixes on delete cascade, user_id uuid references auth.users on delete cascade, created_at timestamptz not null default now(), primary key(remix_id,user_id));
create index remix_votes_user_idx on private.remix_votes(user_id,created_at);
alter table private.drop_pool enable row level security;
alter table private.drop_days enable row level security;
alter table private.drop_claims enable row level security;
alter table private.creator_stats enable row level security;
alter table private.weekly_winners enable row level security;
alter table private.remix_votes enable row level security;
alter table public.brand_dna enable row level security;
alter table public.community_remixes enable row level security;
revoke all on public.brand_dna,public.community_remixes from anon,authenticated;
grant select on public.brand_dna,public.community_remixes to authenticated;
grant delete on public.brand_dna to authenticated;
grant all on public.brand_dna,public.community_remixes to service_role;
create policy brand_read on public.brand_dna for select to authenticated using((select auth.uid())=user_id);
create policy brand_delete on public.brand_dna for delete to authenticated using((select auth.uid())=user_id);
create policy remix_owner_read on public.community_remixes for select to authenticated using((select auth.uid())=user_id);
create policy service_pool on private.drop_pool for all to service_role using(true) with check(true);
create policy service_days on private.drop_days for all to service_role using(true) with check(true);
create policy service_claims on private.drop_claims for all to service_role using(true) with check(true);
create policy service_stats on private.creator_stats for all to service_role using(true) with check(true);
create policy service_winners on private.weekly_winners for all to service_role using(true) with check(true);
create policy service_votes on private.remix_votes for all to service_role using(true) with check(true);

create or replace function private.is_pro(p_user_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.entitlements where user_id=p_user_id and is_pro and (expires_at is null or expires_at>now())) or exists(select 1 from private.weekly_winners where user_id=p_user_id and expires_at>now());
$$;
create function private.effective_pro() returns boolean language sql stable security definer set search_path='' as $$ select private.is_pro(auth.uid()); $$;
create function public.effective_pro() returns boolean language sql security invoker set search_path='' as $$ select private.effective_pro(); $$;
revoke all on function private.effective_pro(),public.effective_pro() from public,anon;
grant execute on function private.effective_pro(),public.effective_pro() to authenticated;

create function private.drop_day() returns date language sql stable set search_path='' as $$ select ((now() at time zone 'America/New_York')-interval '9 hours')::date; $$;
revoke all on function private.drop_day() from public,anon,authenticated;
create function private.ensure_drop() returns void language plpgsql security definer set search_path='' as $$
declare d date:=private.drop_day(); n integer; data jsonb;
begin
 perform pg_advisory_xact_lock(710017);
 if exists(select 1 from private.drop_days where day=d) then return;end if;
 select count(*) into n from private.drop_pool;
 if n<3 then return;end if;
 select jsonb_agg(prompt||jsonb_build_object('id','drop_'||to_char(d,'YYYYMMDD')||'_'||position,'is_pro_only',false) order by position) into data from (
 select prompt,row_number() over(order by mod(slot+(d-date '2026-01-01')*3,n)) as position from private.drop_pool order by mod(slot+(d-date '2026-01-01')*3,n) limit 3) selected;
 insert into private.drop_days values(d,(d+time '09:00') at time zone 'America/New_York',((d+1)+time '09:00') at time zone 'America/New_York',data);
end; $$;
revoke all on function private.ensure_drop() from public,anon,authenticated;

create function private.daily_drop() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; stats private.creator_stats;
begin
 perform private.ensure_drop();
 select * into stats from private.creator_stats where user_id=auth.uid();
 select jsonb_build_object('day',day,'expires_at',expires_at,'server_time',now(),'prompts',prompts,'claimed',exists(select 1 from private.drop_claims c where c.user_id=auth.uid() and c.day=d.day),'streak',case when stats.last_day>=private.drop_day()-1 then coalesce(stats.streak,0) else 0 end,'reverse_credits',coalesce(stats.reverse_credits,0)) into result from private.drop_days d where day=private.drop_day();
 return result;end; $$;
create function public.daily_drop() returns jsonb language sql security invoker set search_path='' as $$ select private.daily_drop(); $$;
revoke all on function private.daily_drop(),public.daily_drop() from public;
grant usage on schema private to anon;
grant execute on function private.daily_drop(),public.daily_drop() to anon,authenticated;

create function private.claim_drop(p_day date) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();s private.creator_stats; bonus integer:=0;
begin
 if u is null then raise exception 'Sign in to claim' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 perform private.ensure_drop();
 if p_day is null or p_day<>private.drop_day() or not exists(select 1 from private.drop_days where day=p_day and now()>=opens_at and now()<expires_at) then raise exception 'Drop expired';end if;
 insert into private.creator_stats(user_id) values(u) on conflict do nothing;
 insert into private.drop_claims(user_id,day) values(u,p_day) on conflict do nothing;
 if not found then return private.daily_drop();end if;
 select * into s from private.creator_stats where user_id=u for update;
 s.streak:=case when s.last_day=p_day-1 then s.streak+1 else 1 end;
 if mod(s.streak,7)=0 then bonus:=3;end if;
 update private.creator_stats set last_day=p_day,streak=s.streak,reverse_credits=reverse_credits+bonus where user_id=u;
 return private.daily_drop()||jsonb_build_object('reward_scans',bonus);
end; $$;
create function public.claim_drop(p_day date) returns jsonb language sql security invoker set search_path='' as $$ select private.claim_drop(p_day); $$;
revoke all on function private.claim_drop(date),public.claim_drop(date) from public,anon;
grant execute on function private.claim_drop(date),public.claim_drop(date) to authenticated;

create function private.drop_vault(p_archive boolean default false,p_offset integer default 0) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('day',day,'claimed',claimed,'prompts',case when claimed or private.is_pro(auth.uid()) then prompts else (select jsonb_agg((p-'raw_prompt'-'variables')||jsonb_build_object('raw_prompt','','variables','[]'::jsonb,'is_pro_only',true)) from jsonb_array_elements(prompts) p) end) order by day desc),'[]'::jsonb) from (select d.*,exists(select 1 from private.drop_claims c where c.user_id=auth.uid() and c.day=d.day) claimed from private.drop_days d where auth.uid() is not null and (p_archive and d.day<private.drop_day() or exists(select 1 from private.drop_claims c where c.user_id=auth.uid() and c.day=d.day)) order by day desc limit 10 offset greatest(0,least(p_offset,10000))) days;
$$;
create function public.drop_vault(p_archive boolean default false,p_offset integer default 0) returns jsonb language sql security invoker set search_path='' as $$ select private.drop_vault(p_archive,p_offset); $$;
revoke all on function private.drop_vault(boolean,integer),public.drop_vault(boolean,integer) from public,anon;
grant execute on function private.drop_vault(boolean,integer),public.drop_vault(boolean,integer) to authenticated;
create function private.drop_prompt(p_id text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 select p into result from private.drop_days d cross join lateral jsonb_array_elements(d.prompts) p where p->>'id'=p_id and (d.day=private.drop_day() or private.is_pro(auth.uid()) or exists(select 1 from private.drop_claims c where c.user_id=auth.uid() and c.day=d.day)) limit 1;
 return result;end; $$;
create function public.drop_prompt(p_id text) returns jsonb language sql security invoker set search_path='' as $$ select private.drop_prompt(p_id); $$;
revoke all on function private.drop_prompt(text),public.drop_prompt(text) from public;
grant execute on function private.drop_prompt(text),public.drop_prompt(text) to anon,authenticated;

create function private.save_brand(p_product text,p_colors text,p_vibe text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not private.is_pro(auth.uid()) then raise exception 'Brand DNA requires Pro' using errcode='42501';end if;
 insert into public.brand_dna(user_id,product,colors,vibe) values(auth.uid(),btrim(p_product),btrim(p_colors),btrim(p_vibe)) on conflict(user_id) do update set product=excluded.product,colors=excluded.colors,vibe=excluded.vibe,updated_at=now();
end; $$;
create function public.save_brand(p_product text,p_colors text,p_vibe text) returns void language sql security invoker set search_path='' as $$ select private.save_brand(p_product,p_colors,p_vibe); $$;
revoke all on function private.save_brand(text,text,text),public.save_brand(text,text,text) from public,anon;
grant execute on function private.save_brand(text,text,text),public.save_brand(text,text,text) to authenticated;

alter table private.usage_events add column reward_credit boolean not null default false;
alter table private.usage_events drop constraint usage_events_feature_check;
alter table private.usage_events add constraint usage_events_feature_check check(feature in('customization','reverse','booster'));
create or replace function private.consume_usage(p_feature text) returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();lim integer;used integer;v_id uuid;bonus boolean:=false;pro boolean;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501';end if;
 if p_feature not in('customization','reverse','booster') then raise exception 'Invalid feature';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));pro:=private.is_pro(u);
 lim:=case p_feature when 'reverse' then 2 when 'booster' then case when pro then 50 else 5 end else 3 end;
 select count(*) into used from private.usage_events where user_id=u and feature=p_feature and not reward_credit and created_at>=(date_trunc('day',now() at time zone 'UTC') at time zone 'UTC');
 if (not pro or p_feature='booster') and used>=lim then
   if p_feature='reverse' then
     update private.creator_stats set reverse_credits=reverse_credits-1 where user_id=u and reverse_credits>0;
     if not found then raise exception 'Daily allowance reached';end if;bonus:=true;
   else raise exception 'Daily allowance reached';end if;
 end if;
 delete from private.usage_events where user_id=u and created_at<now()-interval '30 days';
 insert into private.usage_events(user_id,feature,reward_credit) values(u,p_feature,bonus) returning id into v_id;return v_id;
end; $$;
create or replace function public.refund_usage(p_user_id uuid,p_request_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare bonus boolean;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,0));
 delete from private.usage_events where user_id=p_user_id and id=p_request_id returning reward_credit into bonus;
 if bonus then update private.creator_stats set reverse_credits=reverse_credits+1 where user_id=p_user_id;end if;
end; $$;

create function private.vote_remix(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null and created_at<now()-interval '1 day') then raise exception 'Voting requires a verified account older than one day' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 if not exists(select 1 from public.community_remixes where id=p_id and status='approved' and user_id<>auth.uid()) then raise exception 'Remix unavailable';end if;
 if (select count(*) from private.remix_votes where user_id=auth.uid() and created_at>now()-interval '1 day')>=30 then raise exception 'Vote limit reached';end if;
 insert into private.remix_votes values(p_id,auth.uid(),now()) on conflict do nothing;
end; $$;
create function public.vote_remix(p_id uuid) returns void language sql security invoker set search_path='' as $$ select private.vote_remix(p_id); $$;
revoke all on function private.vote_remix(uuid),public.vote_remix(uuid) from public,anon;
grant execute on function private.vote_remix(uuid),public.vote_remix(uuid) to authenticated;
create function private.list_remixes(p_prompt text,p_offset integer default 0) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(row_to_json(r)),'[]'::jsonb) from (select m.id,m.caption,m.image_path,(select count(*) from private.remix_votes v where v.remix_id=m.id) votes,exists(select 1 from private.weekly_winners w where w.remix_id=m.id) creator_of_week from public.community_remixes m where status='approved' and prompt_id=p_prompt order by votes desc,m.created_at desc limit 10 offset greatest(0,least(p_offset,10000))) r;
$$;
create function public.list_remixes(p_prompt text,p_offset integer default 0) returns jsonb language sql security invoker set search_path='' as $$ select private.list_remixes(p_prompt,p_offset); $$;
revoke all on function private.list_remixes(text,integer),public.list_remixes(text,integer) from public;
grant execute on function private.list_remixes(text,integer),public.list_remixes(text,integer) to anon,authenticated;
create function public.submit_remix(p_user uuid,p_prompt text,p_caption text,p_path text) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,2));
 if (select count(*) from public.community_remixes where user_id=p_user and created_at>now()-interval '1 day')>=3 then raise exception 'Submission limit reached';end if;
 if p_path not like p_user::text||'/%' then raise exception 'Invalid path';end if;
 insert into public.community_remixes(user_id,prompt_id,caption,image_path,rights_confirmed) values(p_user,p_prompt,p_caption,p_path,true) returning id into v_id;return v_id;
end; $$;
revoke all on function public.submit_remix(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.submit_remix(uuid,text,text,text) to service_role;
create function public.review_remix(p_id uuid,p_approve boolean) returns void language sql security definer set search_path='' as $$ update public.community_remixes set status=case when p_approve then 'approved' else 'rejected' end where id=p_id; $$;
revoke all on function public.review_remix(uuid,boolean) from public,anon,authenticated;
grant execute on function public.review_remix(uuid,boolean) to service_role;
create function private.award_week() returns void language plpgsql security definer set search_path='' as $$
declare w date:=date_trunc('week',private.drop_day())::date-7;winner record;
begin
 perform pg_advisory_xact_lock(710018);
 if exists(select 1 from private.weekly_winners where week=w) then return;end if;
 select m.id,m.user_id,count(*) votes into winner from public.community_remixes m join private.remix_votes v on v.remix_id=m.id where m.status='approved' and v.created_at>=(w+time '09:00') at time zone 'America/New_York' and v.created_at<((w+7)+time '09:00') at time zone 'America/New_York' group by m.id,m.user_id,m.created_at having count(*)>=3 order by votes desc,m.created_at,m.id limit 1;
 if found then insert into private.weekly_winners values(w,winner.user_id,winner.id,now()+interval '7 days');end if;
end; $$;
revoke all on function private.award_week() from public,anon,authenticated;
-- Private uploads are never public until moderation; only the Edge Function writes/signs.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('remix-submissions','remix-submissions',false,2000000,array['image/jpeg','image/png']) on conflict(id) do nothing;
-- Hourly evaluation covers the 9am boundary through daylight-saving changes.
create extension if not exists pg_cron;
select cron.schedule('promptvault-daily-drop','0 * * * *',$$ select private.ensure_drop(); $$);
select cron.schedule('promptvault-weekly-creator','5 * * * *',$$ select private.award_week(); $$);

-- Seed reviewed editorial content privately with tools/prepare_private_content.mjs.
