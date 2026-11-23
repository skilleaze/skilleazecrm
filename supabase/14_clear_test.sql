-- Skilleaze HQ · remove all test data added from 1 October 2026
-- STEP 1 · preview (run this first, read the counts)
select 'orders (Oct/Nov + all Puttur)' as what, count(*) from orders where date >= '2026-10-01' or branch = 'puttur'
union all select 'payment transfers (Oct/Nov)', count(*) from transfers where date >= '2026-10-01'
union all select 'complaints', count(*) from customer_issues where created_at >= '2026-10-01'
union all select 'Puttur enquiries', coalesce((select jsonb_array_length(value->'enquiries') from app_kv where key = 'puttur'), 0)
union all select 'invoices', coalesce((select sum(jsonb_array_length(value)) from app_kv where key like 'inv\_%' and jsonb_typeof(value) = 'array'), 0);

-- STEP 2 · delete (run after checking the counts)
begin;
delete from orders where date >= '2026-10-01' or branch = 'puttur';
delete from transfers where date >= '2026-10-01';
delete from customer_issues where created_at >= '2026-10-01';
delete from enquiry_log;
delete from enquiries;
update app_kv set value = jsonb_set(value, '{enquiries}', '[]'::jsonb), updated_at = now() where key = 'puttur' and value ? 'enquiries';
delete from app_kv where key like 'inv\_%';
update app_kv set value = '{}'::jsonb, updated_at = now() where key = 'issueSeen';
commit;
select 'ok' as test_data_removed;
