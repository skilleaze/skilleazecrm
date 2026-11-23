-- Skilleaze HQ · Puttur consultants: orders vs converted enquiries audit + link repair (safe to run again)

-- 1. Link any Puttur order to its enquiry when the same consultant has an enquiry with the same phone (last 10 digits)
with cand as (
  select o.id as order_id, e.id as enq_id,
         row_number() over (partition by o.id order by abs(extract(epoch from (o.created_at - e.created_at)))) as rk
  from orders o
  join enquiries e on e.cse_id = o.cse_id
   and right(regexp_replace(coalesce(e.phone, ''), '\D', '', 'g'), 10) = right(regexp_replace(coalesce(o.phone, ''), '\D', '', 'g'), 10)
   and length(regexp_replace(coalesce(o.phone, ''), '\D', '', 'g')) >= 8
  where o.branch = 'puttur' and coalesce(o.extra->>'enqId', '') = '' and o.date >= '2026-11-02'
)
update orders o set extra = jsonb_set(coalesce(o.extra, '{}'::jsonb), '{enqId}', to_jsonb(c.enq_id), true)
from cand c where c.order_id = o.id and c.rk = 1;

-- 2. Mark linked enquiries as converted (keeps their history)
update enquiries e set status = 'CONFIRMED',
       extra = jsonb_set(coalesce(e.extra, '{}'::jsonb), '{orderId}', to_jsonb(coalesce(e.extra->>'orderId', o.id)), true)
from orders o
where o.branch = 'puttur' and o.extra->>'enqId' = e.id and coalesce(o.pay_status, '') <> 'REFUNDED'
  and (e.status <> 'CONFIRMED' or coalesce(e.extra->>'orderId', '') = '');

-- 3. Audit report per consultant · Nov 2026
with o as (
  select o.id, o.cse_id, nullif(o.extra->>'enqId', '') as enq_id, o.pay_status
  from orders o where o.branch = 'puttur' and o.date between '2026-11-01' and '2026-11-30' and not coalesce(o.summary, false)
)
select coalesce(s.name, o.cse_id) as consultant,
       count(*)                                                     as total_orders,
       count(*) filter (where enq_id is not null)                   as enquiry_based_orders,
       count(*) filter (where enq_id is null)                       as direct_orders,
       count(distinct enq_id)                                       as unique_converted_enquiries,
       count(*) filter (where enq_id is not null) - count(distinct enq_id) as repeat_orders_same_enquiry,
       count(*) filter (where enq_id is not null and not exists (select 1 from enquiries e where e.id = o.enq_id)) as linked_to_missing_enquiry,
       count(*) filter (where enq_id is not null and exists (select 1 from enquiries e where e.id = o.enq_id and e.cse_id <> o.cse_id)) as enquiry_of_other_consultant,
       count(*) filter (where pay_status = 'REFUNDED')              as refunded
from o
left join lateral (select x->>'name' as name from app_kv, jsonb_array_elements(value->'staff') x where key = 'puttur' and x->>'id' = o.cse_id limit 1) s on true
group by 1 order by total_orders desc;
