-- Skilleaze HQ · assigned orders always reach the expert (run once, safe to run again)

-- 1. One spelling for every expert code everywhere
update profiles set expert_code = upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) where role = 'expert' and expert_code is not null;
insert into experts (code, name)
select distinct upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')), upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) from order_experts where expert_code is not null
on conflict (code) do nothing;
update order_experts set expert_code = upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) where expert_code <> upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g'));
update expert_agents set expert_code = upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) where expert_code <> upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g'));

-- 2. Rebuild missing assignment rows from each order's saved details (no duplicates)
insert into order_experts (order_id, service_type, expert_code)
select o.id, 'cv', upper(regexp_replace(trim(o.extra->>'expert'), '\s+', ' ', 'g'))
from orders o
where coalesce(o.extra->>'expert', '') <> '' and o.date >= '2026-11-01'
  and not exists (select 1 from order_experts e where e.order_id = o.id)
on conflict do nothing;
insert into order_experts (order_id, service_type, expert_code)
select o.id, w.key, upper(regexp_replace(trim(w.value), '\s+', ' ', 'g'))
from orders o, jsonb_each_text(coalesce(o.extra->'wx', '{}'::jsonb)) w
where coalesce(w.value, '') <> '' and o.date >= '2026-11-01' and w.key in ('cv','linkedin','portfolio','jobportal','interview')
on conflict (order_id, service_type) do update set expert_code = excluded.expert_code;

-- 3. Matching ignores capital letters and extra spaces
create or replace function my_expert() returns text language sql stable security definer set search_path = public as $$
  select upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) from profiles where id = auth.uid() and role = 'expert' and active $$;
create or replace function my_assigned_orders() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(order_id), '{}') from order_experts
  where upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) = (select upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) from profiles where id = auth.uid() and active) $$;
create or replace function my_expert_agents() returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(agent_code), '{}') from expert_agents
  where upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) = (select upper(regexp_replace(trim(expert_code), '\s+', ' ', 'g')) from profiles where id = auth.uid() and active) $$;

-- 4. Every new assignment is saved in the same spelling
create or replace function norm_expert_code() returns trigger language plpgsql as $$
begin
  if new.expert_code is not null then new.expert_code := upper(regexp_replace(trim(new.expert_code), '\s+', ' ', 'g')); end if;
  return new;
end $$;
drop trigger if exists trg_norm_expert on order_experts;
create trigger trg_norm_expert before insert or update on order_experts for each row execute function norm_expert_code();
drop trigger if exists trg_norm_expert_map on expert_agents;
create trigger trg_norm_expert_map before insert or update on expert_agents for each row execute function norm_expert_code();

-- 5. Assigning an expert marks the order as changed so the expert's screen refreshes
create or replace function touch_order_from_expert() returns trigger language plpgsql security definer set search_path = public as $$
begin update orders set updated_at = now() where id = coalesce(new.order_id, old.order_id); return coalesce(new, old); end $$;
drop trigger if exists trg_touch_order_from_expert on order_experts;
create trigger trg_touch_order_from_expert after insert or update or delete on order_experts for each row execute function touch_order_from_expert();

-- 6. Check: every expert login and how many November orders are assigned to them
select p.username, p.expert_code, p.active,
       (select count(*) from order_experts e join orders o on o.id = e.order_id where e.expert_code = p.expert_code and o.date >= '2026-11-01') as november_assigned
from profiles p where p.role = 'expert'
order by november_assigned desc, p.username;
