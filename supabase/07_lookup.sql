-- Skilleaze CRM · customer lookup for every signed-in user (run once)
-- Lets agents, experts and consultants find any customer by number or name,
-- and see whose customer it is and the order status. Prices are NOT returned.
create or replace function lookup_orders(q text)
returns table(id text, date date, status text, pay_status text, extra jsonb)
language sql stable security definer set search_path = public as $$
  select o.id, o.date, o.status, o.pay_status,
         (o.extra - 'price' - 'paid' - 'aedPrice' - 'aedPaid' - 'proof' - 'balProof' - 'comm' - 't')
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
$$;
grant execute on function lookup_orders(text) to authenticated;
select 'ok';
