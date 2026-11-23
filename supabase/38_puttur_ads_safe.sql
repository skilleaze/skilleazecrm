-- 38_puttur_ads_safe.sql · 17 Nov 2026 · Puttur Daily Ads: never lose a saved day again + bring back lost entries. Safe to run again.
-- Cause: Puttur data is one shared record (app_kv key 'puttur'). A consultant's phone saving an enquiry wrote back its OLD copy of the ads list,
-- wiping ad days the manager had just saved. The app now merges per entry; this trigger makes the database refuse to drop any ad day too.

-- 1. Guard: on every save of 'puttur', keep every ad day the database already has unless the incoming copy has a newer version of it.
create or replace function puttur_ads_keep() returns trigger
language plpgsql security definer set search_path = public as $fn$
declare merged jsonb;
begin
  if new.key <> 'puttur' or old.value is null or jsonb_typeof(old.value->'ads') is distinct from 'array' then
    return new;
  end if;
  select coalesce(jsonb_agg(y.a order by y.a->>'date', y.a->>'staff'), '[]'::jsonb) into merged
  from (
    select distinct on (x.a->>'id') x.a
    from (
      select t.a, 1 as src from jsonb_array_elements(
        case when jsonb_typeof(new.value->'ads') = 'array' then new.value->'ads' else '[]'::jsonb end) as t(a)
      union all
      select t.a, 2 as src from jsonb_array_elements(old.value->'ads') as t(a)
    ) x
    where (x.a->>'id') is not null
    order by x.a->>'id', coalesce((x.a->>'at')::numeric, 0) desc, x.src
  ) y;
  new.value := jsonb_set(new.value, array['ads'], merged);
  return new;
end
$fn$;
drop trigger if exists trg_puttur_ads_keep on app_kv;
create trigger trg_puttur_ads_keep before update on app_kv for each row execute function puttur_ads_keep();

-- 2. Report: ad days that were saved at some point (change history) but are missing or older in the live record now.
with hist as (
  select a from activity_log l, jsonb_array_elements(coalesce(l.old_data->'value'->'ads', '[]'::jsonb)) a
   where l.table_name = 'app_kv' and coalesce(l.new_data, l.old_data)->>'key' = 'puttur'
  union all
  select a from activity_log l, jsonb_array_elements(coalesce(l.new_data->'value'->'ads', '[]'::jsonb)) a
   where l.table_name = 'app_kv' and coalesce(l.new_data, l.old_data)->>'key' = 'puttur'
), best as (
  select distinct on (a->>'id') a from hist where (a->>'id') is not null and (a->>'date') >= '2026-11-02'
  order by a->>'id', coalesce((a->>'at')::numeric, 0) desc
), cur as (
  select a from app_kv k, jsonb_array_elements(coalesce(k.value->'ads', '[]'::jsonb)) a where k.key = 'puttur'
)
select b.a->>'date' as day, b.a->>'staff' as consultant, b.a->>'messages' as enquiries, b.a->>'inInr' as india_inr, b.a->>'uaeAed' as uae_aed,
       case when c.a is null then 'MISSING - will restore' else 'OLDER copy live - will restore newer' end as action
from best b left join cur c on c.a->>'id' = b.a->>'id'
where c.a is null or coalesce((b.a->>'at')::numeric, 0) > coalesce((c.a->>'at')::numeric, 0)
order by 1, 2;

-- 3. Restore them (the guard above keeps whichever copy is newest, so this never duplicates or drops anything).
with hist as (
  select a from activity_log l, jsonb_array_elements(coalesce(l.old_data->'value'->'ads', '[]'::jsonb)) a
   where l.table_name = 'app_kv' and coalesce(l.new_data, l.old_data)->>'key' = 'puttur'
  union all
  select a from activity_log l, jsonb_array_elements(coalesce(l.new_data->'value'->'ads', '[]'::jsonb)) a
   where l.table_name = 'app_kv' and coalesce(l.new_data, l.old_data)->>'key' = 'puttur'
), best as (
  select coalesce(jsonb_agg(a), '[]'::jsonb) as ads from (
    select distinct on (a->>'id') a from hist where (a->>'id') is not null and (a->>'date') >= '2026-11-02'
    order by a->>'id', coalesce((a->>'at')::numeric, 0) desc) z
)
update app_kv k set value = jsonb_set(k.value, array['ads'], best.ads), updated_at = now()
from best where k.key = 'puttur';

-- 4. Check: ad days per date now live
select a->>'date' as day, count(*) as consultants, sum((a->>'messages')::numeric) as enquiries,
       round(sum((a->>'aed')::numeric) * 29.40) as spend_inr_incl_tax
from app_kv k, jsonb_array_elements(coalesce(k.value->'ads', '[]'::jsonb)) a
where k.key = 'puttur' and (a->>'date') >= '2026-11-01'
group by 1 order by 1 desc;
