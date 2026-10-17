begin;
create temporary table creator_test_ids as select gen_random_uuid() a,gen_random_uuid() b;
grant select on creator_test_ids to authenticated;
insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,created_at,updated_at)
select a,'00000000-0000-0000-0000-000000000000'::uuid,'authenticated','authenticated','creator-a-'||a||'@example.invalid',now(),now()-interval '2 days',now() from creator_test_ids
union all select b,'00000000-0000-0000-0000-000000000000'::uuid,'authenticated','authenticated','creator-b-'||b||'@example.invalid',now(),now()-interval '2 days',now() from creator_test_ids;
insert into private.creator_stats(user_id,last_day,streak) select a,private.drop_day()-1,6 from creator_test_ids;
select set_config('request.jwt.claim.sub',(select a::text from creator_test_ids),true);
set local role authenticated;
do $$ declare result jsonb;i integer;begin
 result:=public.claim_drop((public.daily_drop()->>'day')::date);
 if (result->>'streak')::int<>7 or (result->>'reverse_credits')::int<>3 then raise exception 'Streak reward failed';end if;
 result:=public.claim_drop((public.daily_drop()->>'day')::date);
 if (result->>'reverse_credits')::int<>3 then raise exception 'Duplicate claim awarded twice';end if;
 if jsonb_array_length(public.drop_vault(false,0))<>1 then raise exception 'Permanent vault missing';end if;
 begin perform public.claim_drop(current_date-100);raise exception 'Expired claim accepted';exception when raise_exception then if sqlerrm='Expired claim accepted' then raise;end if;end;
 begin perform public.save_brand('A','B','C');raise exception 'Free brand write accepted';exception when insufficient_privilege then null;end;
 for i in 1..5 loop perform public.consume_usage('reverse');end loop;
 if (public.daily_drop()->>'reverse_credits')::int<>0 then raise exception 'Bonus scans not consumed';end if;
 begin perform public.consume_usage('reverse');raise exception 'Quota bypass';exception when raise_exception then if sqlerrm='Quota bypass' then raise;end if;end;
 for i in 1..5 loop perform public.consume_usage('booster');end loop;
 begin perform public.consume_usage('booster');raise exception 'Booster quota bypass';exception when raise_exception then if sqlerrm='Booster quota bypass' then raise;end if;end;
end $$;
reset role;
select public.refund_usage(a,(select id from private.usage_events where user_id=a and reward_credit limit 1)) from creator_test_ids;
do $$begin if (select reverse_credits from private.creator_stats where user_id=(select a from creator_test_ids))<>1 then raise exception 'Reward refund failed';end if;end $$;
insert into public.entitlements(user_id,is_pro,provider) select a,true,'test' from creator_test_ids;
set local role authenticated;
select public.save_brand('Aura Matcha','Sage and cream','Nordic sunlight');
do $$begin if not public.effective_pro() then raise exception 'Pro status failed';end if;end $$;
reset role;
insert into public.community_remixes(id,user_id,prompt_id,caption,image_path,rights_confirmed) select a,a,'pv_001','Test pending',a||'/test.jpg',true from creator_test_ids;
set local role authenticated;
do $$begin
 if jsonb_array_length(public.list_remixes('pv_001',0))<>0 then raise exception 'Pending remix exposed';end if;
 begin perform public.review_remix((select a from creator_test_ids),true);raise exception 'Self moderation allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
select public.review_remix(a,true) from creator_test_ids;
select set_config('request.jwt.claim.sub',(select b::text from creator_test_ids),true);
set local role authenticated;
do $$begin
 if exists(select 1 from public.brand_dna) then raise exception 'Private brand leaked';end if;
 if jsonb_array_length(public.drop_vault(false,0))<>0 then raise exception 'Private claims leaked';end if;
 perform public.vote_remix((select a from creator_test_ids));
 perform public.vote_remix((select a from creator_test_ids));
 if (public.list_remixes('pv_001',0)->0->>'votes')::int<>1 then raise exception 'Duplicate vote counted';end if;
 perform public.block_remix_creator((select a from creator_test_ids));
 if jsonb_array_length(public.list_remixes('pv_001',0))<>0 then raise exception 'Blocked creator visible';end if;
end $$;
reset role;
rollback;
