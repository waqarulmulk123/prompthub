-- Additive schema for a fresh PromptVault project. User data is private by default.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (length(display_name) <= 80),
  updated_at timestamptz not null default now()
);
create table public.entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_pro boolean not null default false,
  expires_at timestamptz,
  provider text,
  event_at timestamptz not null default '-infinity',
  updated_at timestamptz not null default now()
);
create table public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  is_private boolean not null default true check (is_private),
  created_at timestamptz not null default now(),
  unique (id, user_id)
);
create table public.saved_prompts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  collection_id uuid,
  prompt_id text not null check (length(prompt_id) between 1 and 100),
  custom_variables jsonb not null default '{}' check (jsonb_typeof(custom_variables) = 'object' and octet_length(custom_variables::text) <= 16000),
  created_at timestamptz not null default now(),
  unique (user_id, prompt_id),
  foreign key (collection_id, user_id) references public.collections(id, user_id) on delete cascade
);
create index collections_user_idx on public.collections(user_id);
create index saved_prompts_collection_idx on public.saved_prompts(collection_id, user_id);

create table private.usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  feature text not null check (feature in ('customization','reverse')),
  created_at timestamptz not null default now()
);
create index usage_events_user_day_idx on private.usage_events(user_id, feature, created_at);
create table private.premium_prompts (
  id text primary key,
  raw_prompt text not null,
  variables jsonb not null default '[]'
);
create table private.payment_events (
  provider text not null,
  event_id text not null,
  received_at timestamptz not null default now(),
  primary key (provider, event_id)
);

alter table public.profiles enable row level security;
alter table public.entitlements enable row level security;
alter table public.collections enable row level security;
alter table public.saved_prompts enable row level security;
alter table private.usage_events enable row level security;
alter table private.premium_prompts enable row level security;
alter table private.payment_events enable row level security;

revoke all on public.profiles, public.entitlements, public.collections, public.saved_prompts from anon, authenticated;
grant select, insert on public.profiles to authenticated;
grant update(display_name, updated_at) on public.profiles to authenticated;
grant select on public.entitlements to authenticated;
grant select, insert, update, delete on public.collections to authenticated;
grant select, delete on public.saved_prompts to authenticated;
grant all on public.profiles, public.entitlements, public.collections, public.saved_prompts to service_role;

create policy profiles_read on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy entitlements_read on public.entitlements for select to authenticated using ((select auth.uid()) = user_id);
create policy collections_read on public.collections for select to authenticated using ((select auth.uid()) = user_id);
create policy collections_insert on public.collections for insert to authenticated with check ((select auth.uid()) = user_id);
create policy collections_update on public.collections for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy collections_delete on public.collections for delete to authenticated using ((select auth.uid()) = user_id);
create policy bookmarks_read on public.saved_prompts for select to authenticated using ((select auth.uid()) = user_id);
create policy bookmarks_delete on public.saved_prompts for delete to authenticated using ((select auth.uid()) = user_id);

-- Privileged helpers are in a non-exposed schema, with a fixed search path.
create function private.is_pro(p_user_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.entitlements where user_id = p_user_id and is_pro and (expires_at is null or expires_at > now()));
$$;
revoke all on function private.is_pro(uuid) from public, anon, authenticated;

create function public.save_prompt(p_prompt_id text, p_variables jsonb default '{}', p_collection_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_pro boolean;
begin
  if v_user is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if length(p_prompt_id) not between 1 and 100 or p_variables is null or jsonb_typeof(p_variables) <> 'object' or octet_length(p_variables::text) > 16000 then raise exception 'Invalid input'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));
  v_pro := private.is_pro(v_user);
  if not v_pro and p_variables <> '{}'::jsonb then raise exception 'Saved custom presets require Pro'; end if;
  if p_collection_id is not null and not exists(select 1 from public.collections where id = p_collection_id and user_id = v_user) then raise exception 'Board unavailable' using errcode = '42501'; end if;
  if not v_pro and not exists(select 1 from public.saved_prompts where user_id = v_user and prompt_id = p_prompt_id)
    and (select count(*) from public.saved_prompts where user_id = v_user) >= 10 then raise exception 'Free bookmark limit reached'; end if;
  insert into public.saved_prompts(user_id, collection_id, prompt_id, custom_variables) values(v_user,p_collection_id,p_prompt_id,p_variables)
    on conflict(user_id,prompt_id) do update set collection_id=excluded.collection_id, custom_variables=excluded.custom_variables;
end;
$$;
revoke all on function public.save_prompt(text,jsonb,uuid) from public, anon;
grant execute on function public.save_prompt(text,jsonb,uuid) to authenticated;

create function public.consume_usage(p_feature text) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_limit int; v_id uuid;
begin
  if v_user is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_feature not in ('customization','reverse') then raise exception 'Invalid feature'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));
  v_limit := case when p_feature='reverse' then 2 else 3 end;
  if not private.is_pro(v_user) and (select count(*) from private.usage_events where user_id=v_user and feature=p_feature and created_at >= date_trunc('day',now() at time zone 'UTC') at time zone 'UTC') >= v_limit then raise exception 'Daily allowance reached'; end if;
  delete from private.usage_events where user_id=v_user and created_at < now() - interval '30 days';
  insert into private.usage_events(user_id,feature) values(v_user,p_feature) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.consume_usage(text) from public, anon;
grant execute on function public.consume_usage(text) to authenticated;

create function public.refund_usage(p_user_id uuid,p_request_id uuid) returns void language sql security definer set search_path = '' as $$
  delete from private.usage_events where user_id=p_user_id and id=p_request_id;
$$;
revoke all on function public.refund_usage(uuid,uuid) from public, anon, authenticated;
grant execute on function public.refund_usage(uuid,uuid) to service_role;

create function public.get_premium_prompt(p_prompt_id text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_result jsonb;
begin
  if v_user is null or not private.is_pro(v_user) then raise exception 'Pro required' using errcode='42501'; end if;
  select jsonb_build_object('raw_prompt',raw_prompt,'variables',variables) into v_result from private.premium_prompts where id=p_prompt_id;
  if v_result is null then raise exception 'Prompt unavailable'; end if;
  return v_result;
end;
$$;
revoke all on function public.get_premium_prompt(text) from public, anon;
grant execute on function public.get_premium_prompt(text) to authenticated;

create function public.apply_entitlement(p_provider text,p_event_id text,p_user_id uuid,p_active boolean,p_expires_at timestamptz,p_event_at timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into private.payment_events(provider,event_id) values(p_provider,p_event_id) on conflict do nothing;
  if not found then return; end if;
  insert into public.entitlements(user_id,is_pro,expires_at,provider,event_at) values(p_user_id,p_active,p_expires_at,p_provider,p_event_at)
  on conflict(user_id) do update set is_pro=excluded.is_pro, expires_at=excluded.expires_at, provider=excluded.provider, event_at=excluded.event_at, updated_at=now()
  where public.entitlements.event_at <= excluded.event_at;
end;
$$;
revoke all on function public.apply_entitlement(text,text,uuid,boolean,timestamptz,timestamptz) from public, anon, authenticated;
grant execute on function public.apply_entitlement(text,text,uuid,boolean,timestamptz,timestamptz) to service_role;
