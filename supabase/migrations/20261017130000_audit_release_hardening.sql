-- A cancellation/expiry from one store must not revoke another active purchase.
create table private.provider_entitlements (
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check(provider in ('revenuecat','lemonsqueezy')),
  is_pro boolean not null,
  expires_at timestamptz,
  event_at timestamptz not null,
  primary key(user_id,provider)
);
alter table private.provider_entitlements enable row level security;
revoke all on private.provider_entitlements from public,anon,authenticated;
grant all on private.provider_entitlements to service_role;
create policy service_provider_entitlements on private.provider_entitlements for all to service_role using(true) with check(true);
insert into private.provider_entitlements(user_id,provider,is_pro,expires_at,event_at)
 select user_id,provider,is_pro,expires_at,event_at from public.entitlements where provider in('revenuecat','lemonsqueezy');
create or replace function public.apply_entitlement(p_provider text,p_event_id text,p_user_id uuid,p_active boolean,p_expires_at timestamptz,p_event_at timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare active boolean; expiry timestamptz;
begin
 if p_provider not in('revenuecat','lemonsqueezy') or p_event_id is null or length(p_event_id)>200 or p_event_at is null then raise exception 'Invalid payment event';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,0));
 -- Deleted accounts cannot be recreated by a later webhook retry.
 if not exists(select 1 from auth.users where id=p_user_id) then return;end if;
 insert into private.payment_events(provider,event_id) values(p_provider,p_event_id) on conflict do nothing;
 if not found then return;end if;
 insert into private.provider_entitlements(user_id,provider,is_pro,expires_at,event_at) values(p_user_id,p_provider,p_active,p_expires_at,p_event_at)
 on conflict(user_id,provider) do update set is_pro=excluded.is_pro,expires_at=excluded.expires_at,event_at=excluded.event_at
 where private.provider_entitlements.event_at<=excluded.event_at;
 select count(*)>0,case when bool_or(expires_at is null) then null else max(expires_at) end into active,expiry
 from private.provider_entitlements where user_id=p_user_id and is_pro and (expires_at is null or expires_at>now());
 insert into public.entitlements(user_id,is_pro,expires_at,provider,event_at) values(p_user_id,active,expiry,'combined',p_event_at)
 on conflict(user_id) do update set is_pro=excluded.is_pro,expires_at=excluded.expires_at,provider=excluded.provider,event_at=greatest(public.entitlements.event_at,excluded.event_at),updated_at=now();
end; $$;
revoke all on function public.apply_entitlement(text,text,uuid,boolean,timestamptz,timestamptz) from public,anon,authenticated;
grant execute on function public.apply_entitlement(text,text,uuid,boolean,timestamptz,timestamptz) to service_role;

-- Daily prompts are original text editions; no recycled photographic previews.
create index creator_blocks_blocked_user_idx on private.creator_blocks(blocked_user);
create index drop_claims_day_idx on private.drop_claims(day);
create index remix_reports_user_idx on private.remix_reports(user_id);
create index weekly_winners_user_idx on private.weekly_winners(user_id);
update private.drop_pool set prompt=jsonb_set(prompt,'{outputs}','[]');
update private.drop_days set prompts=(select jsonb_agg(jsonb_set(p,'{outputs}','[]') order by n) from jsonb_array_elements(prompts) with ordinality a(p,n));
create unique index drop_pool_unique_text on private.drop_pool(lower(regexp_replace(btrim(prompt->>'raw_prompt'),'\s+',' ','g')));
create or replace function private.ensure_drop() returns void language plpgsql security definer set search_path='' as $$
declare d date:=private.drop_day();data jsonb;
begin
 if exists(select 1 from private.drop_days where day=d) then return;end if;
 perform pg_advisory_xact_lock(710017);
 if exists(select 1 from private.drop_days where day=d) then return;end if;
 select jsonb_agg(prompt||jsonb_build_object('id','drop_'||to_char(d,'YYYYMMDD')||'_'||position,'is_pro_only',false) order by position) into data from (
  select p.prompt,row_number() over(order by p.slot) position from private.drop_pool p
  where not exists(select 1 from private.drop_days history cross join lateral jsonb_array_elements(history.prompts) old where lower(regexp_replace(btrim(old->>'raw_prompt'),'\s+',' ','g'))=lower(regexp_replace(btrim(p.prompt->>'raw_prompt'),'\s+',' ','g')))
  order by p.slot limit 3
 ) selected;
 -- Hide the feature until three fresh reviewed entries exist; never sell recycled drops.
 if jsonb_array_length(data) is distinct from 3 then return;end if;
 insert into private.drop_days values(d,(d+time '09:00') at time zone 'America/New_York',((d+1)+time '09:00') at time zone 'America/New_York',data);
end; $$;
