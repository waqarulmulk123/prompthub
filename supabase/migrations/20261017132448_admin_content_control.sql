-- Owner-managed publishing. No user-editable metadata participates in authorization.
create table private.admin_emails(email text primary key check(email=lower(email)), created_at timestamptz not null default now());
create table private.admin_categories(slug text primary key check(slug ~ '^[a-z0-9_]{1,40}$'),label text not null check(length(label) between 1 and 60),active boolean not null default true);
insert into private.admin_categories values ('fashion','Fashion',true),('men','Men',true),('women','Women',true),('product_ads','Product ads',true),('thumbnails','Thumbnails',true),('ui_design','UI / Web',true),('typography','Typography',true),('3d_icons','3D icons',true),('logos','Brand logos',true),('portraits','Portraits',true);
create table private.admin_catalog(
 id text primary key check(id ~ '^pv_[A-Za-z0-9_-]{1,90}$'),title text not null check(length(btrim(title)) between 1 and 140),raw_prompt text not null check(length(btrim(raw_prompt)) between 10 and 10000),
 category text not null references private.admin_categories(slug), model text not null check(model in('chatgpt_4o','gemini_nano_banana','midjourney','flux')),
 image_path text unique check(image_path is null or image_path ~ '^catalog/[a-f0-9-]{36}\.jpg$'),image_url text,
 image_hash text not null unique,prompt_key text generated always as(lower(regexp_replace(btrim(raw_prompt),'\s+',' ','g'))) stored unique,
 aspect_ratio numeric not null check(aspect_ratio between 0.25 and 4),tags jsonb not null default '[]' check(jsonb_typeof(tags)='array' and jsonb_array_length(tags)<=20),
 variables jsonb not null default '[]' check(jsonb_typeof(variables)='array' and jsonb_array_length(variables)<=30),
 attribution text not null default '' check(length(attribution)<=500),is_pro_only boolean not null default false,verified boolean not null default false,
 status text not null default 'draft' check(status in('draft','published','archived')),featured boolean not null default false,
 rights_confirmed boolean not null default false,safety_reviewed boolean not null default false,version integer not null default 1,updated_at timestamptz not null default now(),
 check(image_path is not null or image_url ~ '^https://images\.unsplash\.com/photo-[a-zA-Z0-9-]+\?'),
 check(status<>'published' or (rights_confirmed and safety_reviewed))
);
create table private.admin_audit(id bigint generated always as identity primary key,actor uuid,action text not null,target text,created_at timestamptz not null default now());
create index admin_audit_actor_idx on private.admin_audit(actor);
create table private.admin_settings(id boolean primary key default true check(id),announcement text not null default '' check(length(announcement)<=300));
insert into private.admin_settings default values;
create table private.admin_grants(user_id uuid primary key references auth.users on delete cascade,expires_at timestamptz not null);
do $$ declare t text;begin foreach t in array array['admin_emails','admin_categories','admin_catalog','admin_audit','admin_settings','admin_grants'] loop execute format('alter table private.%I enable row level security',t);execute format('revoke all on private.%I from public,anon,authenticated',t);execute format('grant all on private.%I to service_role',t);execute format('create policy service_admin on private.%I for all to service_role using(true) with check(true)',t);end loop;end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('catalog-media','catalog-media',false,2000000,array['image/jpeg']) on conflict(id) do nothing;

create function public.admin_status() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('allowed',exists(select 1 from auth.users u join private.admin_emails a on a.email=lower(u.email) where u.id=auth.uid() and u.email_confirmed_at is not null and coalesce(u.banned_until,'-infinity')<now() and exists(select 1 from auth.sessions s where s.id=(auth.jwt()->>'session_id')::uuid and s.user_id=u.id)), 'verified',auth.jwt()->>'aal'='aal2');
$$;
revoke all on function public.admin_status() from public,anon;
grant execute on function public.admin_status() to authenticated;
create function private.require_admin() returns void language plpgsql stable security definer set search_path='' as $$
declare s jsonb:=public.admin_status();begin if not coalesce((s->>'allowed')::boolean,false) or not coalesce((s->>'verified')::boolean,false) then raise exception 'Verified administrator required' using errcode='42501';end if;end $$;
revoke all on function private.require_admin() from public,anon,authenticated;

create function public.admin_manage(p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare p private.admin_catalog;result jsonb;target text;v_id text;v_slot integer;v_user uuid;v_page integer:=greatest(0,least(coalesce((p_payload->>'page')::integer,0),10000));
begin
 perform private.require_admin();
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>100000 then raise exception 'Invalid payload';end if;
 if p_action='snapshot' then
  return jsonb_build_object('prompts',(select coalesce(jsonb_agg(to_jsonb(r)-'prompt_key'-'image_hash'),'[]') from (select * from private.admin_catalog where title ilike '%'||left(coalesce(p_payload->>'search',''),100)||'%' order by updated_at desc,id limit 50 offset v_page*50) r),
   'prompt_count',(select count(*) from private.admin_catalog),'categories',(select coalesce(jsonb_agg(to_jsonb(c) order by label),'[]') from private.admin_categories c),
   'daily',(select coalesce(jsonb_agg(jsonb_build_object('slot',slot,'title',prompt->>'title','raw_prompt',prompt->>'raw_prompt','category',prompt->>'category','published',exists(select 1 from private.drop_days d cross join lateral jsonb_array_elements(d.prompts) e where lower(regexp_replace(btrim(e->>'raw_prompt'),'\s+',' ','g'))=lower(regexp_replace(btrim(prompt->>'raw_prompt'),'\s+',' ','g')))) order by slot),'[]') from private.drop_pool),
   'remixes',(select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (select id,user_id,prompt_id,caption,image_path,status,created_at from public.community_remixes order by created_at desc limit 50 offset v_page*50) r),
   'users',(select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (select u.id,u.email,u.created_at,u.email_confirmed_at,u.banned_until,private.is_pro(u.id) is_pro,g.expires_at grant_expires_at from auth.users u left join private.admin_grants g on g.user_id=u.id order by u.created_at desc limit 50 offset v_page*50) r),
   'admins',(select coalesce(jsonb_agg(email order by email),'[]') from private.admin_emails),'announcement',(select announcement from private.admin_settings),
   'audit',(select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (select * from private.admin_audit order by id desc limit 50 offset v_page*50) r));
 elsif p_action='save_prompt' then
  v_id:=coalesce(nullif(p_payload->>'id',''),'pv_admin_'||replace(gen_random_uuid()::text,'-',''));target:=v_id;
  select * into p from private.admin_catalog where id=v_id for update;
  if found and p.version<>coalesce((p_payload->>'version')::integer,-1) then raise exception 'Content changed; reload before saving';end if;
  insert into private.admin_catalog(id,title,raw_prompt,category,model,image_path,image_url,image_hash,aspect_ratio,tags,variables,attribution,is_pro_only,verified,status,featured,rights_confirmed,safety_reviewed)
  values(v_id,btrim(p_payload->>'title'),btrim(p_payload->>'raw_prompt'),p_payload->>'category',p_payload->>'model',coalesce(p_payload->>'image_path',p.image_path),case when p_payload->>'image_path' is not null then null else p.image_url end,coalesce(p_payload->>'image_hash',p.image_hash),(coalesce(p_payload->>'aspect_ratio',p.aspect_ratio::text))::numeric,coalesce(p_payload->'tags','[]'),coalesce(p_payload->'variables','[]'),coalesce(p_payload->>'attribution',''),coalesce((p_payload->>'is_pro_only')::boolean,false),coalesce((p_payload->>'verified')::boolean,false),coalesce(p_payload->>'status','draft'),coalesce((p_payload->>'featured')::boolean,false),coalesce((p_payload->>'rights_confirmed')::boolean,false),coalesce((p_payload->>'safety_reviewed')::boolean,false))
  on conflict(id) do update set title=excluded.title,raw_prompt=excluded.raw_prompt,category=excluded.category,model=excluded.model,image_path=excluded.image_path,image_url=excluded.image_url,image_hash=excluded.image_hash,aspect_ratio=excluded.aspect_ratio,tags=excluded.tags,variables=excluded.variables,attribution=excluded.attribution,is_pro_only=excluded.is_pro_only,verified=excluded.verified,status=excluded.status,featured=excluded.featured,rights_confirmed=excluded.rights_confirmed,safety_reviewed=excluded.safety_reviewed,version=private.admin_catalog.version+1,updated_at=now();
  insert into private.premium_prompts(id,raw_prompt,variables) select id,raw_prompt,variables from private.admin_catalog where id=v_id and is_pro_only and status='published' on conflict(id) do update set raw_prompt=excluded.raw_prompt,variables=excluded.variables;
  if not exists(select 1 from private.admin_catalog where id=v_id and is_pro_only and status='published') then delete from private.premium_prompts where id=v_id;end if;
  result:=jsonb_build_object('id',v_id,'saved',true,'remove_image',case when p_payload->>'image_path' is not null then p.image_path end);
 elsif p_action='delete_prompt' then
  target:=p_payload->>'id';select * into p from private.admin_catalog where id=target;delete from private.admin_catalog where id=target and version=(p_payload->>'version')::integer;
  if not found then raise exception 'Content changed or missing';end if;
  delete from private.premium_prompts where id=target;result:=jsonb_build_object('deleted',true,'remove_image',p.image_path);
 elsif p_action='category' then
  target:=p_payload->>'slug';if target='all' then raise exception 'Reserved category';end if;
  insert into private.admin_categories values(target,btrim(p_payload->>'label'),(p_payload->>'active')::boolean) on conflict(slug) do update set label=excluded.label,active=excluded.active;result:='{"saved":true}';
 elsif p_action='daily' then
  target:=p_payload->>'slot';
  if p_payload->>'operation'='delete' then delete from private.drop_pool where slot=target::integer;
  else
   if length(btrim(p_payload->>'raw_prompt')) not between 150 and 10000 or length(btrim(p_payload->>'title')) not between 1 and 140 or not exists(select 1 from private.admin_categories where slug=p_payload->>'category') or coalesce((p_payload->>'reviewed')::boolean,false)=false then raise exception 'Reviewed original daily content required';end if;
   perform pg_advisory_xact_lock(17132448);
   v_slot:=coalesce(nullif(target,'')::integer,(select coalesce(max(slot),-1)+1 from private.drop_pool));
   if exists(select 1 from private.drop_days d cross join lateral jsonb_array_elements(d.prompts) e where lower(regexp_replace(btrim(e->>'raw_prompt'),'\s+',' ','g'))=lower(regexp_replace(btrim(p_payload->>'raw_prompt'),'\s+',' ','g'))) then raise exception 'Daily text already published';end if;
   insert into private.drop_pool values(v_slot,jsonb_build_object('id','pool_'||v_slot,'title',btrim(p_payload->>'title'),'raw_prompt',btrim(p_payload->>'raw_prompt'),'category',p_payload->>'category','outputs','[]'::jsonb,'variables','[]'::jsonb,'tags',jsonb_build_array('daily','original'),'is_pro_only',false,'likes_count',0,'attribution','Original PromptVault daily text template. No generated image is supplied.','license','CC0-1.0','safety_reviewed',true,'verified',false)) on conflict(slot) do update set prompt=excluded.prompt;target:=v_slot::text;
  end if;result:='{"saved":true}';
 elsif p_action='review_remix' then target:=p_payload->>'id';perform public.review_remix(target::uuid,(p_payload->>'approve')::boolean);result:='{"saved":true}';
 elsif p_action='grant_pro' then
  v_user:=(p_payload->>'user_id')::uuid;target:=v_user::text;
  if p_payload->>'operation'='revoke' then delete from private.admin_grants where user_id=v_user;
  else insert into private.admin_grants values(v_user,now()+make_interval(days=>greatest(1,least((p_payload->>'days')::integer,366)))) on conflict(user_id) do update set expires_at=excluded.expires_at;end if;result:='{"saved":true}';
 elsif p_action='admin' then
  target:=lower(btrim(p_payload->>'email'));if target !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or length(target)>254 then raise exception 'Invalid email';end if;
  if p_payload->>'operation'='revoke' then
   if target=(select lower(email) from auth.users where id=auth.uid()) then raise exception 'Cannot revoke your own access';end if;
   delete from private.admin_emails where email=target;
  else insert into private.admin_emails(email) values(target) on conflict do nothing;end if;result:='{"saved":true}';
 elsif p_action='settings' then update private.admin_settings set announcement=btrim(p_payload->>'announcement');result:='{"saved":true}';
 else raise exception 'Unknown action';end if;
 insert into private.admin_audit(actor,action,target) values(auth.uid(),p_action,target);
 return result;
end $$;
revoke all on function public.admin_manage(text,jsonb) from public,anon;
grant execute on function public.admin_manage(text,jsonb) to authenticated;

create or replace function private.is_pro(p_user_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.entitlements where user_id=p_user_id and is_pro and (expires_at is null or expires_at>now())) or exists(select 1 from private.weekly_winners where user_id=p_user_id and expires_at>now()) or exists(select 1 from private.admin_grants where user_id=p_user_id and expires_at>now());
$$;
create function public.published_catalog() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('prompts',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'raw_prompt',case when p.is_pro_only then '' else p.raw_prompt end,'category',p.category,'outputs',jsonb_build_array(jsonb_build_object('model',p.model,'image_url',coalesce(p.image_url,''),'aspect_ratio',p.aspect_ratio,'blur_hash','')),'image_path',p.image_path,'variables',case when p.is_pro_only then '[]'::jsonb else p.variables end,'is_pro_only',p.is_pro_only,'likes_count',0,'tags',p.tags,'attribution',p.attribution,'verified',p.verified,'featured',p.featured) order by p.featured desc,p.updated_at desc,p.id),'[]') from private.admin_catalog p join private.admin_categories c on c.slug=p.category where p.status='published' and c.active), 'categories',(select coalesce(jsonb_object_agg(slug,label),'{}') from private.admin_categories where active),'announcement',(select announcement from private.admin_settings));
$$;
revoke all on function public.published_catalog() from public,anon,authenticated;
grant execute on function public.published_catalog() to service_role;
