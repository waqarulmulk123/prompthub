alter table private.usage_events drop constraint usage_events_feature_check;
alter table private.usage_events add constraint usage_events_feature_check check(feature in('customization','reverse','booster','remix_upload'));
create or replace function private.consume_usage(p_feature text) returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();lim integer;used integer;v_id uuid;bonus boolean:=false;pro boolean;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501';end if;
 if p_feature not in('customization','reverse','booster','remix_upload') then raise exception 'Invalid feature';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));pro:=private.is_pro(u);
 lim:=case p_feature when 'reverse' then 2 when 'booster' then case when pro then 50 else 5 end when 'remix_upload' then 3 else 3 end;
 select count(*) into used from private.usage_events where user_id=u and feature=p_feature and not reward_credit and created_at>=(date_trunc('day',now() at time zone 'UTC') at time zone 'UTC');
 if (not pro or p_feature in('booster','remix_upload')) and used>=lim then
   if p_feature='reverse' then update private.creator_stats set reverse_credits=reverse_credits-1 where user_id=u and reverse_credits>0;if not found then raise exception 'Daily allowance reached';end if;bonus:=true;
   else raise exception 'Daily allowance reached';end if;
 end if;
 delete from private.usage_events where user_id=u and created_at<now()-interval '30 days';
 insert into private.usage_events(user_id,feature,reward_credit) values(u,p_feature,bonus) returning id into v_id;return v_id;
end; $$;
create function private.own_remix_path(p_id uuid) returns text language sql stable security definer set search_path='' as $$ select image_path from public.community_remixes where id=p_id and user_id=auth.uid(); $$;
create function public.own_remix_path(p_id uuid) returns text language sql security invoker set search_path='' as $$ select private.own_remix_path(p_id); $$;
revoke all on function private.own_remix_path(uuid),public.own_remix_path(uuid) from public,anon;
grant execute on function private.own_remix_path(uuid),public.own_remix_path(uuid) to authenticated;
