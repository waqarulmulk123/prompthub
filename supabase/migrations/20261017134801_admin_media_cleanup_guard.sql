do $guard$
declare definition text:=pg_get_functiondef('public.admin_manage(text,jsonb)'::regprocedure);
 old_rule text:='p_payload->>''image_path'' is not null then p.image_path';
 new_rule text:='p_payload->>''image_path'' is not null and p_payload->>''image_path'' is distinct from p.image_path then p.image_path';
begin
 if position(new_rule in definition)>0 then return;end if;
 if position(old_rule in definition)=0 then raise exception 'Unexpected administrator function version';end if;
 execute replace(definition,old_rule,new_rule);
end $guard$;
