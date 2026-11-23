-- Skilleaze HQ · link every Puttur order to its enquiry, now and automatically from now on (safe to run again)

-- 1. Enquiry already points to the order, but the order doesn't point back (or the other way round)
update orders o set extra = jsonb_set(coalesce(o.extra, '{}'::jsonb), '{enqId}', to_jsonb(e.id), true)
from enquiries e
where o.branch = 'puttur' and coalesce(o.extra->>'enqId', '') = ''
  and (e.order_id = o.id or e.extra->>'orderId' = o.id);

update enquiries e set order_id = o.id,
  extra = jsonb_set(jsonb_set(coalesce(e.extra, '{}'::jsonb), '{orderId}', to_jsonb(o.id), true), '{status}', '"CONFIRMED"', true),
  status = 'CONFIRMED'
from orders o
where o.branch = 'puttur' and o.extra->>'enqId' = e.id and coalesce(e.order_id, '') = '';

-- 2. Orders entered directly although the same consultant already had that customer's enquiry (same phone): link them, one to one
with cand as (
  select distinct on (o.id) o.id as oid, e.id as eid
  from orders o
  join enquiries e on e.cse_id = o.cse_id
   and right(regexp_replace(coalesce(e.phone, ''), '\D', '', 'g'), 9) = right(regexp_replace(coalesce(o.phone, ''), '\D', '', 'g'), 9)
   and length(regexp_replace(coalesce(o.phone, ''), '\D', '', 'g')) >= 9
  where o.branch = 'puttur' and not o.summary and coalesce(o.extra->>'enqId', '') = ''
    and coalesce(e.order_id, '') = '' and coalesce(e.extra->>'deleted', 'false') <> 'true'
  order by o.id, e.created_at),
uniq as (select distinct on (eid) oid, eid from cand order by eid, oid)
, upd_o as (update orders o set extra = jsonb_set(coalesce(o.extra, '{}'::jsonb), '{enqId}', to_jsonb(u.eid), true) from uniq u where o.id = u.oid returning o.id)
update enquiries e set order_id = u.oid, status = 'CONFIRMED',
  extra = jsonb_set(jsonb_set(jsonb_set(coalesce(e.extra, '{}'::jsonb), '{orderId}', to_jsonb(u.oid), true), '{status}', '"CONFIRMED"', true),
          '{log}', coalesce(e.extra->'log', '[]'::jsonb) || jsonb_build_array(jsonb_build_object('at', (extract(epoch from now()) * 1000)::bigint, 'status', 'CONFIRMED', 'note', 'Linked to order ' || u.oid || ' (same customer number)', 'by', 'SYSTEM')), true)
from uniq u where e.id = u.eid;

-- 3. From now on: an order a consultant enters directly links itself to their open enquiry with the same number
create or replace function link_order_enquiry() returns trigger language plpgsql security definer set search_path = public as $$
declare eid text; ph text := right(regexp_replace(coalesce(new.phone, ''), '\D', '', 'g'), 9);
begin
  if pg_trigger_depth() > 1 or new.branch <> 'puttur' or new.summary or coalesce(new.extra->>'enqId', '') <> '' or length(ph) < 9 then return new; end if;
  select e.id into eid from enquiries e
  where e.cse_id = new.cse_id and coalesce(e.order_id, '') = '' and coalesce(e.extra->>'deleted', 'false') <> 'true'
    and right(regexp_replace(coalesce(e.phone, ''), '\D', '', 'g'), 9) = ph
  order by e.created_at limit 1;
  if eid is null then return new; end if;
  new.extra := jsonb_set(coalesce(new.extra, '{}'::jsonb), '{enqId}', to_jsonb(eid), true);
  update enquiries set order_id = new.id, status = 'CONFIRMED',
    extra = jsonb_set(jsonb_set(coalesce(extra, '{}'::jsonb), '{orderId}', to_jsonb(new.id), true), '{status}', '"CONFIRMED"', true)
  where id = eid;
  return new;
end $$;
drop trigger if exists trg_link_order_enquiry on orders;
create trigger trg_link_order_enquiry before insert on orders for each row execute function link_order_enquiry();

-- 4. Audit per consultant (this month): every figure comes straight from the records
with o as (
  select o.cse_id, o.id, o.price, o.paid, o.extra->>'pay' as pay,
         coalesce(nullif(o.extra->>'enqId', ''), (select e.id from enquiries e where e.order_id = o.id limit 1)) as enq
  from orders o where o.branch = 'puttur' and not o.summary and o.date >= date_trunc('month', current_date)::date)
select coalesce(s->>'name', o.cse_id) as consultant,
       count(*) as total_orders,
       count(*) filter (where enq is not null) as from_enquiries,
       count(*) filter (where enq is null) as direct_orders,
       count(distinct enq) as converted_enquiries,
       count(*) filter (where enq is not null) - count(distinct enq) as duplicate_conversions,
       sum(case when pay = 'REFUNDED' then 0 else coalesce(paid, 0) end) as collected
from o
left join lateral (select x from app_kv k, jsonb_array_elements(coalesce(k.value->'staff', '[]'::jsonb)) x where k.key = 'puttur' and x->>'id' = o.cse_id limit 1) st(s) on true
group by 1 order by 2 desc;
