-- Skilleaze HQ · make every expert assignment reach the expert (run once, safe to run again)

-- 0. Every expert login must exist in the experts list (otherwise assignments are rejected)
insert into experts (code, name) select distinct p.expert_code, p.full_name from profiles p where p.role = 'expert' and p.expert_code is not null and not exists (select 1 from experts e where e.code = p.expert_code);

-- 1. Server-side safety net: whenever an order is saved, its expert(s) are written to order_experts
create or replace function sync_order_experts() returns trigger language plpgsql security definer set search_path = public as $$
declare k text; v text; code text; wx jsonb;
begin
  wx := coalesce(new.extra->'wx', '{}'::jsonb);
  if (wx = '{}'::jsonb) and coalesce(new.extra->>'expert', '') <> '' then wx := jsonb_build_object('cv', new.extra->>'expert'); end if;
  for k, v in select key, value from jsonb_each_text(wx) loop
    if k not in ('cv','linkedin','portfolio','jobportal','interview') then continue; end if;
    if coalesce(trim(v), '') = '' then
      delete from order_experts where order_id = new.id and service_type = k;
    else
      select e.code into code from experts e where upper(regexp_replace(trim(e.code), '\s+', ' ', 'g')) = upper(regexp_replace(trim(v), '\s+', ' ', 'g')) limit 1;
      if code is not null then
        insert into order_experts (order_id, service_type, expert_code) values (new.id, k, code)
        on conflict (order_id, service_type) do update set expert_code = excluded.expert_code where order_experts.expert_code is distinct from excluded.expert_code;
      end if;
    end if;
  end loop;
  return new;
end $$;
drop trigger if exists trg_sync_order_experts on orders;
create trigger trg_sync_order_experts after insert or update of extra on orders for each row execute function sync_order_experts();

-- 2. Repair: fill any missing assignments from the orders themselves (November onwards)
insert into order_experts (order_id, service_type, expert_code)
select o.id, w.key, e.code
from orders o
cross join lateral jsonb_each_text(case when coalesce(o.extra->'wx', '{}'::jsonb) = '{}'::jsonb and coalesce(o.extra->>'expert','') <> '' then jsonb_build_object('cv', o.extra->>'expert') else coalesce(o.extra->'wx', '{}'::jsonb) end) w
join experts e on upper(regexp_replace(trim(e.code), '\s+', ' ', 'g')) = upper(regexp_replace(trim(w.value), '\s+', ' ', 'g'))
where o.date >= '2026-11-01' and w.key in ('cv','linkedin','portfolio','jobportal','interview') and trim(w.value) <> ''
on conflict (order_id, service_type) do update set expert_code = excluded.expert_code where order_experts.expert_code is distinct from excluded.expert_code;

-- 3. Check (one table): each expert's November orders vs what reaches her dashboard, plus names that match no expert
select 'expert' as kind, e.code as name,
  (select count(*) from orders o where o.date >= '2026-11-01' and exists (select 1 from jsonb_each_text(coalesce(o.extra->'wx','{}'::jsonb) || jsonb_build_object('x', coalesce(o.extra->>'expert',''))) w where upper(trim(w.value)) = e.code)) as orders_naming_her,
  (select count(*) from order_experts oe join orders o on o.id = oe.order_id where oe.expert_code = e.code and o.date >= '2026-11-01') as on_dashboard,
  (select string_agg(p.username || case when p.active then '' else ' (inactive)' end, ', ') from profiles p where p.expert_code = e.code) as login
from experts e
where e.code ilike '%ALMISHA%' or e.code ilike '%HASEENA%'
union all
select 'no match' as kind, coalesce(o.extra->'wx'->>'cv', o.extra->>'expert') as name, count(*), 0, null
from orders o
where o.date >= '2026-11-01' and coalesce(o.extra->'wx'->>'cv', o.extra->>'expert', '') <> ''
  and not exists (select 1 from experts e where upper(regexp_replace(trim(e.code), '\s+', ' ', 'g')) = upper(regexp_replace(trim(coalesce(o.extra->'wx'->>'cv', o.extra->>'expert')), '\s+', ' ', 'g')))
group by 2
order by 1, 2;
