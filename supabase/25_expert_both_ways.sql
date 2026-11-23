-- Skilleaze HQ · keep the expert on the order and the dashboard link always in step (run once, safe to run again)

-- 1. Copy every dashboard link back onto its order (fixes orders that show "not assigned" but are linked)
update orders o set extra = jsonb_set(
    jsonb_set(coalesce(o.extra, '{}'::jsonb), '{wx}', coalesce(o.extra->'wx', '{}'::jsonb) || x.wx, true),
    '{expert}', to_jsonb(coalesce(nullif(o.extra->>'expert', ''), x.wx->>'cv', x.first_expert)), true)
from (select order_id, jsonb_object_agg(service_type, expert_code) as wx, min(expert_code) as first_expert from order_experts group by order_id) x
where x.order_id = o.id
  and (coalesce(o.extra->>'expert', '') = '' or exists (select 1 from jsonb_each_text(x.wx) w where coalesce(o.extra->'wx'->>w.key, '') <> w.value));

-- 2. From now on: whenever an expert is linked (agent, operations, or the expert picking it up), write it onto the order too
create or replace function sync_order_from_expert() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    update orders set extra = jsonb_set(coalesce(extra, '{}'::jsonb), '{wx}', coalesce(extra->'wx', '{}'::jsonb) - old.service_type, true)
    where id = old.order_id and coalesce(extra->'wx'->>old.service_type, '') = old.expert_code;
    return old;
  end if;
  update orders set extra = jsonb_set(
      jsonb_set(coalesce(extra, '{}'::jsonb), '{wx}', coalesce(extra->'wx', '{}'::jsonb) || jsonb_build_object(new.service_type, new.expert_code), true),
      '{expert}', to_jsonb(case when new.service_type = 'cv' or coalesce(extra->>'expert', '') = '' then new.expert_code else extra->>'expert' end), true)
  where id = new.order_id
    and (coalesce(extra->'wx'->>new.service_type, '') is distinct from new.expert_code
         or (new.service_type = 'cv' and coalesce(extra->>'expert', '') is distinct from new.expert_code));
  return new;
end $$;
drop trigger if exists trg_sync_order_from_expert on order_experts;
create trigger trg_sync_order_from_expert after insert or update or delete on order_experts for each row execute function sync_order_from_expert();

-- 3. Check Delta / Zahir again
select o.id, o.date, o.name, o.status,
       coalesce(o.extra->'wx'->>'cv', o.extra->>'expert') as expert_on_order,
       (select string_agg(oe.service_type || ':' || oe.expert_code, ', ') from order_experts oe where oe.order_id = o.id) as dashboard_link
from orders o
where o.agent_code = 'DELTA' and o.date >= '2026-11-01'
order by o.created_at desc
limit 40;
