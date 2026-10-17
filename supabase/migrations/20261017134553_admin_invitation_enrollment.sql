create table private.admin_invites(token_hash text primary key,email text not null references private.admin_emails(email) on delete cascade,expires_at timestamptz not null,used_at timestamptz);
create index admin_invites_email_idx on private.admin_invites(email);
alter table private.admin_invites enable row level security;
revoke all on private.admin_invites from public,anon,authenticated;
grant all on private.admin_invites to service_role;
create policy service_admin_invites on private.admin_invites for all to service_role using(true) with check(true);
create function private.issue_admin_invite(p_email text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_email text:=lower(btrim(p_email));v_token text:=encode(extensions.gen_random_bytes(32),'hex');v_expiry timestamptz:=now()+interval '24 hours';
begin
 if v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or length(v_email)>254 then raise exception 'Invalid email';end if;
 if exists(select 1 from auth.users where lower(email)=v_email) then raise exception 'Account already exists; sign in instead';end if;
 insert into private.admin_emails(email) values(v_email) on conflict do nothing;
 delete from private.admin_invites where email=v_email;
 insert into private.admin_invites(token_hash,email,expires_at) values(encode(extensions.digest(v_token,'sha256'),'hex'),v_email,v_expiry);
 return jsonb_build_object('token',v_token,'expires_at',v_expiry);
end $$;
revoke all on function private.issue_admin_invite(text) from public,anon,authenticated;
create function public.claim_admin_invite(p_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_email text;
begin
 if p_token !~ '^[a-f0-9]{64}$' then return null;end if;
 update private.admin_invites set used_at=now() where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and expires_at>now() and used_at is null returning email into v_email;
 return case when v_email is null then null else jsonb_build_object('email',v_email) end;
end $$;
create function public.release_admin_invite(p_token text) returns void language sql security definer set search_path='' as $$
 update private.admin_invites i set used_at=null where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and not exists(select 1 from auth.users u where lower(u.email)=i.email);
$$;
revoke all on function public.claim_admin_invite(text),public.release_admin_invite(text) from public,anon,authenticated;
grant execute on function public.claim_admin_invite(text),public.release_admin_invite(text) to service_role;
create or replace function public.admin_manage(p_action text,p_payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
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
  values(v_id,btrim(p_payload->>'title'),btrim(normalize(p_payload->>'raw_prompt',NFKC)),p_payload->>'category',p_payload->>'model',coalesce(p_payload->>'image_path',p.image_path),case when p_payload->>'image_path' is not null then null else p.image_url end,coalesce(p_payload->>'image_hash',p.image_hash),(coalesce(p_payload->>'aspect_ratio',p.aspect_ratio::text))::numeric,coalesce(p_payload->'tags','[]'),coalesce(p_payload->'variables','[]'),coalesce(p_payload->>'attribution',''),coalesce((p_payload->>'is_pro_only')::boolean,false),coalesce((p_payload->>'verified')::boolean,false),coalesce(p_payload->>'status','draft'),coalesce((p_payload->>'featured')::boolean,false),coalesce((p_payload->>'rights_confirmed')::boolean,false),coalesce((p_payload->>'safety_reviewed')::boolean,false))
  on conflict(id) do update set title=excluded.title,raw_prompt=excluded.raw_prompt,category=excluded.category,model=excluded.model,image_path=excluded.image_path,image_url=excluded.image_url,image_hash=excluded.image_hash,aspect_ratio=excluded.aspect_ratio,tags=excluded.tags,variables=excluded.variables,attribution=excluded.attribution,is_pro_only=excluded.is_pro_only,verified=excluded.verified,status=excluded.status,featured=excluded.featured,rights_confirmed=excluded.rights_confirmed,safety_reviewed=excluded.safety_reviewed,version=private.admin_catalog.version+1,updated_at=now();
  insert into private.premium_prompts(id,raw_prompt,variables) select id,raw_prompt,variables from private.admin_catalog where id=v_id and is_pro_only and status='published' on conflict(id) do update set raw_prompt=excluded.raw_prompt,variables=excluded.variables;
  if not exists(select 1 from private.admin_catalog where id=v_id and is_pro_only and status='published') then delete from private.premium_prompts where id=v_id;end if;
  result:=jsonb_build_object('id',v_id,'saved',true,'remove_image',case when p_payload->>'image_path' is not null and p_payload->>'image_path' is distinct from p.image_path then p.image_path end);
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
   if length(btrim(normalize(p_payload->>'raw_prompt',NFKC))) not between 150 and 10000 or length(btrim(p_payload->>'title')) not between 1 and 140 or not exists(select 1 from private.admin_categories where slug=p_payload->>'category') or coalesce((p_payload->>'reviewed')::boolean,false)=false then raise exception 'Reviewed original daily content required';end if;
   perform pg_advisory_xact_lock(17132448);
   v_slot:=coalesce(nullif(target,'')::integer,(select coalesce(max(slot),-1)+1 from private.drop_pool));
   if exists(select 1 from private.drop_days d cross join lateral jsonb_array_elements(d.prompts) e where lower(regexp_replace(btrim(e->>'raw_prompt'),'\s+',' ','g'))=lower(regexp_replace(btrim(normalize(p_payload->>'raw_prompt',NFKC)),'\s+',' ','g'))) then raise exception 'Daily text already published';end if;
   insert into private.drop_pool values(v_slot,jsonb_build_object('id','pool_'||v_slot,'title',btrim(p_payload->>'title'),'raw_prompt',btrim(normalize(p_payload->>'raw_prompt',NFKC)),'category',p_payload->>'category','outputs','[]'::jsonb,'variables','[]'::jsonb,'tags',jsonb_build_array('daily','original'),'is_pro_only',false,'likes_count',0,'attribution','Original PromptVault daily text template. No generated image is supplied.','license','CC0-1.0','safety_reviewed',true,'verified',false)) on conflict(slot) do update set prompt=excluded.prompt;target:=v_slot::text;
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
 elsif p_action='authorize_delete_user' then
  v_user:=(p_payload->>'user_id')::uuid;target:=v_user::text;
  if v_user=auth.uid() or exists(select 1 from auth.users u join private.admin_emails a on a.email=lower(u.email) where u.id=v_user) then raise exception 'Cannot delete administrator accounts here';end if;
  if not exists(select 1 from auth.users where id=v_user) then raise exception 'Account missing';end if;
  result:=jsonb_build_object('user_id',v_user);
 elsif p_action='invite' then target:=lower(btrim(p_payload->>'email'));result:=private.issue_admin_invite(target);
 elsif p_action='settings' then update private.admin_settings set announcement=btrim(p_payload->>'announcement');result:='{"saved":true}';
 else raise exception 'Unknown action';end if;
 insert into private.admin_audit(actor,action,target) values(auth.uid(),p_action,target);
 return result;
end $$;