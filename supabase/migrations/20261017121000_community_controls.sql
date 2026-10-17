create table private.remix_reports(remix_id uuid references public.community_remixes on delete cascade,user_id uuid references auth.users on delete cascade,created_at timestamptz not null default now(),primary key(remix_id,user_id));
create table private.creator_blocks(user_id uuid references auth.users on delete cascade,blocked_user uuid references auth.users on delete cascade,primary key(user_id,blocked_user));
alter table private.remix_reports enable row level security;
alter table private.creator_blocks enable row level security;
create policy service_reports on private.remix_reports for all to service_role using(true) with check(true);
create policy service_blocks on private.creator_blocks for all to service_role using(true) with check(true);
create function private.report_remix(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in' using errcode='42501';end if;
 if not exists(select 1 from public.community_remixes where id=p_id and status='approved') then raise exception 'Remix unavailable';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,3));
 insert into private.remix_reports values(p_id,auth.uid(),now()) on conflict do nothing;
 -- Hide from the reporter immediately. Three established accounts return it to review.
 if (select count(*) from private.remix_reports r join auth.users u on u.id=r.user_id where r.remix_id=p_id and u.email_confirmed_at is not null and u.created_at<now()-interval '1 day')>=3 then update public.community_remixes set status='pending' where id=p_id;end if;
end; $$;
create function public.report_remix(p_id uuid) returns void language sql security invoker set search_path='' as $$ select private.report_remix(p_id); $$;
create function private.block_remix_creator(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in' using errcode='42501';end if;
 insert into private.creator_blocks select auth.uid(),user_id from public.community_remixes where id=p_id and user_id<>auth.uid() on conflict do nothing;
end; $$;
create function public.block_remix_creator(p_id uuid) returns void language sql security invoker set search_path='' as $$ select private.block_remix_creator(p_id); $$;
create function private.delete_remix(p_id uuid) returns void language sql security definer set search_path='' as $$ delete from public.community_remixes where id=p_id and user_id=auth.uid(); $$;
create function public.delete_remix(p_id uuid) returns void language sql security invoker set search_path='' as $$ select private.delete_remix(p_id); $$;
revoke all on function private.report_remix(uuid),public.report_remix(uuid),private.block_remix_creator(uuid),public.block_remix_creator(uuid),private.delete_remix(uuid),public.delete_remix(uuid) from public,anon;
grant execute on function private.report_remix(uuid),public.report_remix(uuid),private.block_remix_creator(uuid),public.block_remix_creator(uuid),private.delete_remix(uuid),public.delete_remix(uuid) to authenticated;
create or replace function private.list_remixes(p_prompt text,p_offset integer default 0) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(row_to_json(r)),'[]'::jsonb) from (select m.id,m.caption,m.image_path,(select count(*) from private.remix_votes v where v.remix_id=m.id) votes,exists(select 1 from private.weekly_winners w where w.remix_id=m.id) creator_of_week from public.community_remixes m where status='approved' and prompt_id=p_prompt and not exists(select 1 from private.creator_blocks b where b.user_id=auth.uid() and b.blocked_user=m.user_id) and not exists(select 1 from private.remix_reports r where r.user_id=auth.uid() and r.remix_id=m.id) order by votes desc,m.created_at desc limit 10 offset greatest(0,least(p_offset,10000))) r;
$$;
