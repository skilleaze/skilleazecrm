-- Skilleaze HQ · Alpha cash flow reconciliation (READ ONLY — changes nothing)
-- Run each block separately in SQL Editor and send me the results.

-- ── 1. Balance by period, exactly as the CRM calculates it ─────────────────
with o as (
  select date,
    case when pay_status = 'REFUNDED' then 0 else price end as rev,
    case when extra->>'balanceVia' is not null then coalesce((extra->>'firstPaid')::numeric, paid) else paid end as first_amt,
    price, pay_status, coalesce(extra->>'via', via, 'personal') as via, extra->>'balanceVia' as bvia,
    coalesce(extra->>'t', '') as t, coalesce((extra->>'comm')::numeric, 0) as comm
  from orders where agent_code = 'ALPHA'),
oo as (
  select date,
    (case when via = 'personal' and pay_status <> 'REFUNDED' then first_amt else 0 end)
  + (case when bvia = 'personal' and pay_status <> 'REFUNDED' then price - first_amt else 0 end) as personal,
    rev,
    case when t = 'L' then comm
         when t like 'D%' then rev * (1 - substring(t from 2)::numeric) / 2
         else rev / 2 end as share, t
  from o),
ad as (
  select date, aed * 29.4 as inr, coalesce(extra->>'t', tier, '') as t from ad_days where agent_code = 'ALPHA'),
adsh as (
  select date, inr,
    case when t = 'L' then 0 when t like 'D%' then -inr * (1 - substring(t from 2)::numeric) / 2 else -inr / 2 end as share
  from ad),
tr as (
  select date, amount, coalesce(status, extra->>'status', 'verified') as st from transfers where agent_code = 'ALPHA'),
p as (select d, case when d < '2026-10-01' then '1 · up to 30 Sep' when d < '2026-11-01' then '2 · October' else '3 · November' end as period from (
  select date d from oo union select date from adsh union select date from tr) x)
select period,
  round(sum((select coalesce(sum(rev), 0)      from oo   where oo.date = p.d)), 2) as revenue,
  round(sum((select coalesce(sum(personal), 0) from oo   where oo.date = p.d)), 2) as received_personal,
  round(sum((select coalesce(sum(inr), 0)      from adsh where adsh.date = p.d)), 2) as ad_spend,
  round(sum((select coalesce(sum(share), 0)    from oo   where oo.date = p.d))
      + sum((select coalesce(sum(share), 0)    from adsh where adsh.date = p.d)), 2) as agent_commission,
  round(sum((select coalesce(sum(amount), 0)   from tr   where tr.date = p.d)), 2) as transferred_all,
  round(sum((select coalesce(sum(amount), 0)   from tr   where tr.date = p.d and st = 'pending')), 2)  as transferred_pending,
  round(sum((select coalesce(sum(amount), 0)   from tr   where tr.date = p.d and st = 'rejected')), 2) as transferred_rejected
from p group by period order by period;

-- ── 2. Every Alpha order since 1 October (date, id, revenue, where the money went) ──
select date, id, name, price, paid, pay_status,
  coalesce(extra->>'via', via, 'personal') as received_to, extra->>'balanceVia' as balance_to,
  coalesce(extra->>'proofStatus', proof_status) as proof, coalesce(extra->>'t', '') as tier,
  coalesce((extra->>'summary')::boolean, summary, false) as is_adjustment_line
from orders where agent_code = 'ALPHA' and date >= '2026-10-01'
order by date, created_at;

-- ── 3. Every Alpha transfer since 1 October ─────────────────────────────────
select date, id, amount, coalesce(status, extra->>'status', 'verified') as status, account_code, note, imported
from transfers where agent_code = 'ALPHA' and date >= '2026-10-01'
order by date, id;

-- ── 4. Possible duplicates ──────────────────────────────────────────────────
select 'order' as kind, date::text, regexp_replace(coalesce(phone, ''), '\D', '', 'g') as key, price as amount, count(*) as copies, string_agg(id, ', ') as ids
from orders where agent_code = 'ALPHA' and date >= '2026-10-01' and not coalesce(summary, false)
group by date, regexp_replace(coalesce(phone, ''), '\D', '', 'g'), price having count(*) > 1
union all
select 'transfer', date::text, coalesce(note, ''), amount, count(*), string_agg(id, ', ')
from transfers where agent_code = 'ALPHA' and date >= '2026-10-01'
group by date, coalesce(note, ''), amount having count(*) > 1
order by 2;
