-- Skilleaze HQ · work status can never jump back to "Not started" (run once, safe to run again)

create or replace function keep_status_forward() returns trigger language plpgsql as $$
declare done text[] := array['DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED'];
begin
  -- 1. Once work has started, an out-of-date copy can't put it back to Not started
  if old.status = any(done) and coalesce(new.status, 'PENDING') = 'PENDING' then
    new.status := old.status;
  end if;
  -- 2. A closed order can't be pushed back to Draft / Submitted by an old copy (Revision is still allowed)
  if old.status = 'CLOSED' and new.status in ('DRAFT SHARED', 'CV SUBMITTED') then
    new.status := old.status;
  end if;
  -- 3. Same rule for each task on combined orders (CV + LinkedIn …)
  if new.extra ? 'ts' and old.extra ? 'ts' then
    new.extra := jsonb_set(new.extra, '{ts}', (
      select coalesce(jsonb_object_agg(k, case
          when (old.extra->'ts'->>k) = any(done) and coalesce(new.extra->'ts'->>k, 'PENDING') = 'PENDING' then old.extra->'ts'->k
          when (old.extra->'ts'->>k) = 'CLOSED' and (new.extra->'ts'->>k) in ('DRAFT SHARED', 'CV SUBMITTED') then old.extra->'ts'->k
          else new.extra->'ts'->k end), '{}'::jsonb)
      from jsonb_object_keys(new.extra->'ts' || old.extra->'ts') k));
  end if;
  -- 4. Keep the saved copy in step and never lose submitted / closed times
  if new.extra ? 'status' then new.extra := jsonb_set(new.extra, '{status}', to_jsonb(new.status)); end if;
  if new.submit_at is null then new.submit_at := old.submit_at; end if;
  if new.close_at  is null and new.status = 'CLOSED' then new.close_at := old.close_at; end if;
  if old.extra ? 'submitAt' and coalesce(new.extra->>'submitAt', '') = '' then new.extra := jsonb_set(new.extra, '{submitAt}', old.extra->'submitAt'); end if;
  if new.status = 'CLOSED' and old.extra ? 'closeAt' and coalesce(new.extra->>'closeAt', '') = '' then new.extra := jsonb_set(new.extra, '{closeAt}', old.extra->'closeAt'); end if;
  return new;
end $$;

drop trigger if exists trg_keep_status_forward on orders;
create trigger trg_keep_status_forward before update on orders for each row execute function keep_status_forward();

-- Put back orders that already slipped back to Not started (uses the change history)
with lost as (
  select distinct on (o.id) o.id, l.old_data->>'status' as was
  from orders o join activity_log l on l.table_name = 'orders' and l.row_id = o.id and l.action = 'UPDATE'
  where o.status = 'PENDING' and o.date >= '2026-11-02'
    and l.old_data->>'status' in ('DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED')
    and coalesce(l.new_data->>'status', 'PENDING') = 'PENDING'
  order by o.id, l.at desc)
update orders o set status = lost.was, extra = case when o.extra ? 'status' then jsonb_set(o.extra, '{status}', to_jsonb(lost.was)) else o.extra end
from lost where lost.id = o.id;

select count(*) as orders_still_slipped_back
from orders o
where o.status = 'PENDING' and o.date >= '2026-11-02'
  and exists (select 1 from activity_log l where l.table_name = 'orders' and l.row_id = o.id
              and l.old_data->>'status' in ('DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED'));
