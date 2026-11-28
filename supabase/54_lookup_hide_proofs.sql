-- 54 · Customer lookup never returns payment screenshots (28 Nov 2026)
-- Safe to run more than once. Paste into Supabase → SQL Editor → Run.
-- (52 and 53 are reserved for files in docs/pending-sql/, not applied yet.)
--
-- lookup_orders() is open to every active login. It already dropped 'proof', but not the new
-- 'proofs' list (several payment screenshots on one order) and it dropped 'balProof' while the
-- app stores the balance screenshot as 'balanceProof'. Both are now removed from the results.

create or replace function public.lookup_orders(q text)
returns table(id text, date date, status text, pay_status text, extra jsonb)
language sql stable security definer set search_path to 'public' as $fn$
  select o.id, o.date, o.status, o.pay_status,
         (o.extra - 'price' - 'paid' - 'aedPrice' - 'aedPaid' - 'proof' - 'proofs' - 'balProof' - 'balanceProof' - 'comm' - 't')
  from orders o
  where auth.uid() is not null
    and exists (select 1 from profiles p where p.id = auth.uid() and p.active)
    and not o.summary
    and (
      (length(regexp_replace(q, '\D', '', 'g')) >= 5
        and regexp_replace(coalesce(o.phone, ''), '\D', '', 'g') like '%' || regexp_replace(q, '\D', '', 'g') || '%')
      or (length(regexp_replace(q, '\D', '', 'g')) = 0 and length(trim(q)) >= 3
        and o.name ilike '%' || trim(q) || '%')
    )
  order by o.date desc
  limit 200
$fn$;
