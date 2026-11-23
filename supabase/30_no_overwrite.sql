-- Skilleaze HQ · stop old copies overwriting newer data, and restore wrongly deleted orders (safe to run again)

-- 1. Save changed details one by one (keeps the expert's status and the assigned expert intact)
create or replace function patch_extra(p_table text, p_id text, p_set jsonb, p_unset text[])
returns void language plpgsql security invoker set search_path = public as $$
begin
  if p_table not in ('orders','transfers','expenses','ad_days','customer_issues','hr_records','enquiries') then
    raise exception 'not allowed';
  end if;
  execute format('update %I set extra = (coalesce(extra, ''{}''::jsonb) || coalesce($1, ''{}''::jsonb)) - coalesce($2, ''{}''::text[]) where id::text = $3', p_table)
  using p_set, p_unset, p_id;
end $$;
grant execute on function patch_extra(text, text, jsonb, text[]) to authenticated;

-- 2. Bring back orders deleted in the last 7 days by a non-management account (old copies on a phone)
with gone as (
  select distinct on (l.row_id) l.row_id, l.old_data, l.at, l.user_id
  from activity_log l
  where l.table_name = 'orders' and l.action = 'DELETE' and l.at > now() - interval '7 days'
    and l.old_data is not null
    and not exists (select 1 from profiles p where p.id = l.user_id and p.role in ('management','manager'))
    and l.user_id is not null
  order by l.row_id, l.at desc
)
insert into orders
select (jsonb_populate_record(null::orders, g.old_data)).*
from gone g
where not exists (select 1 from orders o where o.id = g.row_id)
  and coalesce((g.old_data->>'date')::date, '2026-11-02') >= '2026-11-02'
on conflict (id) do nothing;

-- 3. Re-link restored and existing orders to their experts' dashboards
insert into order_experts (order_id, service_type, expert_code)
select o.id, w.key, w.value
from orders o, jsonb_each_text(coalesce(o.extra->'wx', '{}'::jsonb)) w
where o.date >= '2026-11-02' and w.value <> ''
on conflict (order_id, service_type) do nothing;

-- 4. Check: Lambda + Shafeeda this month
select o.id, o.date, o.name, o.status,
       coalesce(o.extra->'wx'->>'cv', o.extra->>'expert') as expert_on_order,
       (select string_agg(oe.service_type || ':' || oe.expert_code, ', ') from order_experts oe where oe.order_id = o.id) as dashboard_link
from orders o
where o.agent_code = 'LAMBDA' and o.date >= '2026-11-02'
order by o.created_at desc;
