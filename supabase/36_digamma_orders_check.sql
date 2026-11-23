-- 36_digamma_orders_check.sql · 14 Nov 2026 · READ ONLY: changes nothing.
-- Finds what happened to DIGAMMA's orders on 14 Nov 2026.

-- 1. Every DIGAMMA order dated or created on 14 Nov (what the server has)
select id, date, created_at at time zone 'Asia/Kolkata' as created_ist, name, phone, services, price, paid, pay_status,
       coalesce(extra->>'via', via) as paid_into, extra->>'proofStatus' as proof, status, summary
from orders
where agent_code = 'DIGAMMA' and (date = '2026-11-14' or (created_at at time zone 'Asia/Kolkata')::date = '2026-11-14')
order by created_at;

-- 2. Were any DIGAMMA orders deleted on 13–14 Nov? (who, when, why)
select id, order_date, name, phone, price, status, deleted_by, deleted_at at time zone 'Asia/Kolkata' as deleted_ist, reason
from order_delete_log
where agent_code = 'DIGAMMA' and (order_date >= '2026-11-13' or deleted_at >= '2026-11-13')
order by deleted_at;

-- 3. Any DIGAMMA order moved to another agent or re-dated since 13 Nov
select id, agent_code, date, extra->>'agent' as agent_in_record, extra->>'date' as date_in_record, name, price
from orders
where (extra->>'agent' = 'DIGAMMA' or agent_code = 'DIGAMMA') and (agent_code is distinct from extra->>'agent' or date::text is distinct from extra->>'date')
  and updated_at >= '2026-11-13';

-- 4. DIGAMMA punches on the server for 13–14 Nov (if 14 Nov is missing, the punch never reached the server either)
select id, person_key, extra->>'date' as day, to_timestamp((extra->>'in')::bigint / 1000) at time zone 'Asia/Kolkata' as punch_in_ist,
       extra->>'mode' as mode, created_at at time zone 'Asia/Kolkata' as saved_ist
from hr_records
where kind = 'punch' and (person_key ilike '%DIGAMMA%' or person_key ilike '%MUNAVVIR%') and extra->>'date' >= '2026-11-13'
order by created_at;
