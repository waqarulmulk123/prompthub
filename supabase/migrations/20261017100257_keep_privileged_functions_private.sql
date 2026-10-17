-- Keep privileged implementations outside the exposed API schema.
alter function public.save_prompt(text,jsonb,uuid) set schema private;
alter function public.consume_usage(text) set schema private;
alter function public.get_premium_prompt(text) set schema private;
grant usage on schema private to authenticated;
grant execute on function private.save_prompt(text,jsonb,uuid), private.consume_usage(text), private.get_premium_prompt(text) to authenticated;

create function public.save_prompt(p_prompt_id text,p_variables jsonb default '{}',p_collection_id uuid default null)
returns void language sql security invoker set search_path = '' as $$ select private.save_prompt(p_prompt_id,p_variables,p_collection_id); $$;
create function public.consume_usage(p_feature text) returns uuid language sql security invoker set search_path = '' as $$ select private.consume_usage(p_feature); $$;
create function public.get_premium_prompt(p_prompt_id text) returns jsonb language sql security invoker set search_path = '' as $$ select private.get_premium_prompt(p_prompt_id); $$;
revoke all on function public.save_prompt(text,jsonb,uuid), public.consume_usage(text), public.get_premium_prompt(text) from public, anon;
grant execute on function public.save_prompt(text,jsonb,uuid), public.consume_usage(text), public.get_premium_prompt(text) to authenticated;
revoke all on function public.rls_auto_enable() from public, anon, authenticated;
create policy service_usage on private.usage_events for all to service_role using (true) with check (true);
create policy service_premium on private.premium_prompts for all to service_role using (true) with check (true);
create policy service_events on private.payment_events for all to service_role using (true) with check (true);
