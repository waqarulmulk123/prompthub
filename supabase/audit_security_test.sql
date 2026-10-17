begin;
create temporary table audit_user as select gen_random_uuid() id;
insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,created_at,updated_at)
select id,'00000000-0000-0000-0000-000000000000'::uuid,'authenticated','authenticated','audit-'||id||'@example.invalid',now(),now(),now() from audit_user;
do $$ declare u uuid:=(select id from audit_user);begin
 perform public.submit_remix(u,'pv_001','Audit',u::text||'/one.jpg',repeat('a',64));
 begin
  perform public.submit_remix(u,'pv_001','Duplicate',u::text||'/two.jpg',repeat('a',64));
  raise exception 'Duplicate community image accepted';
 exception when unique_violation then null;end;
 perform public.apply_entitlement('revenuecat','a',u,true,now()+interval '10 days',now()-interval '5 minutes');
 perform public.apply_entitlement('lemonsqueezy','b',u,true,now()+interval '20 days',now()-interval '4 minutes');
 perform public.apply_entitlement('revenuecat','c',u,false,now(),now()-interval '3 minutes');
 if not private.is_pro(u) then raise exception 'One provider revoked another active provider';end if;
 perform public.apply_entitlement('lemonsqueezy','d',u,false,now(),now()-interval '2 minutes');
 if private.is_pro(u) then raise exception 'Expired purchases still granted access';end if;
 perform public.apply_entitlement('lemonsqueezy','old',u,true,null,now()-interval '10 minutes');
 if private.is_pro(u) then raise exception 'Old event restored access';end if;
 perform public.apply_entitlement('revenuecat','c',u,true,null,now());
 if private.is_pro(u) then raise exception 'Duplicate event changed access';end if;
end $$;
-- Account deletion cascades all owned app records, including provider states.
delete from auth.users where id=(select id from audit_user);
do $$ begin
 if exists(select 1 from private.provider_entitlements where user_id=(select id from audit_user)) then raise exception 'Provider data remained after deletion';end if;
 perform public.apply_entitlement('revenuecat','deleted-account-event',(select id from audit_user),true,null,now());
 if exists(select 1 from public.entitlements where user_id=(select id from audit_user)) then raise exception 'Webhook recreated deleted user';end if;
end $$;
-- Force inventory exhaustion in this rollback-only transaction; never recycle an old drop.
delete from private.drop_claims;
delete from private.drop_days;
delete from private.drop_pool;
insert into private.drop_pool values(1,jsonb_build_object('id','test','raw_prompt','already used','outputs','[]'::jsonb));
select private.ensure_drop();
do $$ begin if exists(select 1 from private.drop_days) then raise exception 'Incomplete drop was published';end if;end $$;
rollback;
