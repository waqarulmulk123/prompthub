begin;
do $$ begin
 if has_function_privilege('anon','public.admin_manage(text,jsonb)','EXECUTE') or has_function_privilege('anon','public.admin_status()','EXECUTE') or has_function_privilege('authenticated','public.published_catalog()','EXECUTE') then raise exception 'Admin or private catalog function exposed';end if;
 if exists(select 1 from pg_tables where schemaname='private' and tablename like 'admin_%' and not rowsecurity) then raise exception 'Admin table lacks RLS';end if;
 if exists(select 1 from jsonb_array_elements(public.published_catalog()->'prompts') p where (p->>'is_pro_only')::boolean and (p->>'raw_prompt'<>'' or p->'variables'<>'[]'::jsonb)) then raise exception 'Paid text exposed publicly';end if;
 if exists(select 1 from storage.buckets where id='catalog-media' and public) then raise exception 'Draft media bucket is public';end if;
end $$;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('aaaaaaaa-1234-4321-8234-aaaaaaaaaaaa','admin-transaction@example.invalid',now(),'{"role":"admin"}');
insert into auth.sessions(id,user_id,created_at,updated_at) values('bbbbbbbb-1234-4321-8234-bbbbbbbbbbbb','aaaaaaaa-1234-4321-8234-aaaaaaaaaaaa',now(),now());
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-1234-4321-8234-aaaaaaaaaaaa","role":"authenticated","aal":"aal2","session_id":"bbbbbbbb-1234-4321-8234-bbbbbbbbbbbb"}',true);
do $$ begin
 if (public.admin_status()->>'allowed')::boolean then raise exception 'Editable metadata granted access';end if;
 begin perform public.admin_manage('snapshot','{}');raise exception 'Unapproved user allowed';exception when insufficient_privilege then null;end;
end $$;
insert into private.admin_emails(email) values('admin-transaction@example.invalid');
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-1234-4321-8234-aaaaaaaaaaaa","role":"authenticated","aal":"aal1","session_id":"bbbbbbbb-1234-4321-8234-bbbbbbbbbbbb"}',true);
do $$ begin begin perform public.admin_manage('settings','{"announcement":"should fail"}');raise exception 'MFA bypass';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-1234-4321-8234-aaaaaaaaaaaa","role":"authenticated","aal":"aal2","session_id":"bbbbbbbb-1234-4321-8234-bbbbbbbbbbbb"}',true);
select public.admin_manage('category','{"slug":"audit_category","label":"Audit category","active":true}');
select public.admin_manage('settings','{"announcement":"transactional test"}');
do $$ begin
 if public.published_catalog()->>'announcement'<>'transactional test' then raise exception 'Settings not published';end if;
 if public.published_catalog()->'categories'->>'audit_category'<>'Audit category' then raise exception 'Dynamic category missing';end if;
 begin perform public.admin_manage('admin','{"email":"admin-transaction@example.invalid","operation":"revoke"}');raise exception 'Own access could be revoked';exception when raise_exception then if sqlerrm='Own access could be revoked' then raise;end if;end;
end $$;
do $$ declare payload jsonb;result jsonb;invitation jsonb;begin
 payload:='{"id":"pv_sql_media_guard","title":"Media guard regression","raw_prompt":"An original bounded SQL regression prompt for private image edit checks.","category":"audit_category","model":"chatgpt_4o","image_path":"catalog/ffffffff-1234-4321-8234-ffffffffffff.jpg","image_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","aspect_ratio":1,"rights_confirmed":true,"safety_reviewed":true}';
 perform public.admin_manage('save_prompt',payload);
 result:=public.admin_manage('save_prompt',payload||'{"version":1}');
 if result->>'remove_image' is not null then raise exception 'Unchanged image would be deleted';end if;
 begin perform public.admin_manage('save_prompt',payload||'{"id":"pv_sql_duplicate_prompt","image_path":"catalog/eeeeeeee-1234-4321-8234-eeeeeeeeeeee.jpg","image_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}');raise exception 'Duplicate prompt accepted';exception when unique_violation then null;end;
 begin perform public.admin_manage('save_prompt',payload||'{"id":"pv_sql_duplicate_image","raw_prompt":"Different original text for checking image uniqueness constraints.","image_path":"catalog/dddddddd-1234-4321-8234-dddddddddddd.jpg"}');raise exception 'Duplicate image hash accepted';exception when unique_violation then null;end;
 if has_function_privilege('anon','public.claim_admin_invite(text)','EXECUTE') or has_function_privilege('authenticated','public.release_admin_invite(text)','EXECUTE') then raise exception 'Invitation function exposed';end if;
 invitation:=private.issue_admin_invite('admin-invitation-transaction@example.invalid');
 if public.claim_admin_invite(invitation->>'token')->>'email'<>'admin-invitation-transaction@example.invalid' then raise exception 'Invitation email mismatch';end if;
 if public.claim_admin_invite(invitation->>'token') is not null then raise exception 'Invitation replay accepted';end if;
end $$;
delete from auth.sessions where id='bbbbbbbb-1234-4321-8234-bbbbbbbbbbbb';
do $$ begin if (public.admin_status()->>'allowed')::boolean then raise exception 'Revoked session accepted';end if;end $$;
rollback;
