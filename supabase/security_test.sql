begin;
insert into auth.users(id, email) values
 ('10000000-0000-4000-8000-000000000001','promptvault-test-a@example.invalid'),
 ('10000000-0000-4000-8000-000000000002','promptvault-test-b@example.invalid');
insert into public.collections(id,user_id,name) values ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','Other user private board');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$
declare n int; blocked boolean;
begin
  select count(*) into n from public.collections;
  if n <> 0 then raise exception 'FAIL: cross-user board visible'; end if;
  blocked := false;
  begin
    insert into public.entitlements(user_id,is_pro) values(auth.uid(),true);
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'FAIL: user could grant Pro'; end if;
  blocked := false;
  begin
    perform public.save_prompt('pv_001','{}','20000000-0000-4000-8000-000000000002');
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'FAIL: cross-user board accepted'; end if;
  for n in 1..10 loop perform public.save_prompt('test_'||n,'{}',null); end loop;
  blocked := false;
  begin perform public.save_prompt('test_11','{}',null);
  exception when raise_exception then blocked := true; end;
  if not blocked then raise exception 'FAIL: free bookmark limit bypassed'; end if;
  blocked := false;
  begin perform public.save_prompt('test_1','{"Subject":"changed"}',null);
  exception when raise_exception then blocked := true; end;
  if not blocked then raise exception 'FAIL: Pro presets not protected'; end if;
  perform public.consume_usage('reverse');
  perform public.consume_usage('reverse');
  blocked := false;
  begin perform public.consume_usage('reverse');
  exception when raise_exception then blocked := true; end;
  if not blocked then raise exception 'FAIL: reverse allowance bypassed'; end if;
  blocked := false;
  begin perform public.get_premium_prompt('private_prompt');
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'FAIL: paid prompt available to free user'; end if;
end;
$$;
reset role;
select 'PASS: private boards, cross-user writes, Pro escalation, bookmarks, presets, daily quota, premium access' as result;
rollback;
