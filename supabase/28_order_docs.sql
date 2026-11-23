-- Skilleaze HQ · customer documents on orders (run once, safe to run again)
-- Files go in the private "proofs" bucket under orderdocs/<order id>/…
-- Anyone signed in can upload; only people who can see that order can open its files.
drop policy if exists st_orderdocs_read on storage.objects;
create policy st_orderdocs_read on storage.objects for select using (
  bucket_id = 'proofs' and split_part(name, '/', 1) = 'orderdocs'
  and exists (select 1 from orders o where o.id = split_part(name, '/', 2)));
select 'ok' as order_docs_ready;
