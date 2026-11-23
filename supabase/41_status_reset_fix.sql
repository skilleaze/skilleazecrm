-- Skilleaze HQ · undo 40's "order status = least task" rule and restore works pushed back to Not started
-- Safe to run again. Run in 3 steps.

-- STEP 1 · new guard: protect each task's status, never recompute the order status from old task data
create or replace function keep_status_forward() returns trigger language plpgsql as $fn$
declare
  done text[] := array['DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED'];
  m jsonb; k text; ov text; nv text; ota numeric; nta numeric;
begin
  if jsonb_typeof(new.extra->'tst') = 'object' and jsonb_typeof(old.extra->'tst') = 'object' then
    m := new.extra->'tst';
    for k in select jsonb_object_keys(new.extra->'tst') loop
      ov := old.extra->'tst'->>k; nv := new.extra->'tst'->>k;
      if ov is null or ov = nv then continue; end if;
      ota := coalesce((old.extra->'tAt'->k->>ov)::numeric, 0);
      nta := coalesce((new.extra->'tAt'->k->>nv)::numeric, 0);
      if (ov = any(done) and nv = 'PENDING' and nta <= ota)
         or (ov = 'CLOSED' and nv in ('DRAFT SHARED', 'CV SUBMITTED') and nta <= ota) then
        m := m || jsonb_build_object(k, ov);
      end if;
    end loop;
    new.extra := jsonb_set(new.extra, '{tst}', m);
    if jsonb_typeof(old.extra->'tAt') = 'object' then
      new.extra := jsonb_set(new.extra, '{tAt}', (
        select coalesce(jsonb_object_agg(t, coalesce(old.extra->'tAt'->t, '{}'::jsonb) || coalesce(new.extra->'tAt'->t, '{}'::jsonb)), '{}'::jsonb)
        from (select jsonb_object_keys(old.extra->'tAt') t union select jsonb_object_keys(coalesce(new.extra->'tAt', '{}'::jsonb))) x));
    end if;
  end if;
  if old.status = any(done) and coalesce(new.status, 'PENDING') = 'PENDING' then new.status := old.status; end if;
  if old.status = 'CLOSED' and new.status in ('DRAFT SHARED', 'CV SUBMITTED') then new.status := old.status; end if;
  if new.extra ? 'status' then new.extra := jsonb_set(new.extra, '{status}', to_jsonb(new.status)); end if;
  if new.submit_at is null then new.submit_at := old.submit_at; end if;
  if new.close_at  is null and new.status = 'CLOSED' then new.close_at := old.close_at; end if;
  if old.extra ? 'submitAt' and coalesce(new.extra->>'submitAt', '') = '' then new.extra := jsonb_set(new.extra, '{submitAt}', old.extra->'submitAt'); end if;
  if new.status = 'CLOSED' and old.extra ? 'closeAt' and coalesce(new.extra->>'closeAt', '') = '' then new.extra := jsonb_set(new.extra, '{closeAt}', old.extra->'closeAt'); end if;
  return new;
end $fn$;
drop trigger if exists trg_keep_status_forward on orders;
create trigger trg_keep_status_forward before update on orders for each row execute function keep_status_forward();

-- STEP 2 · REPORT: works that were started / closed and got pushed back to Not started since 19 Nov
with hit as (
  select distinct on (l.row_id) l.row_id as id, l.at, l.old_data
  from activity_log l
  where l.table_name = 'orders' and l.action = 'UPDATE' and l.at >= '2026-11-19'
    and l.old_data->>'status' in ('DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED')
    and l.new_data->>'status' = 'PENDING'
  order by l.row_id, l.at)
select coalesce(o.extra->>'expert', '-') as expert, o.id, o.name, o.date,
       hit.old_data->>'status' as was, o.status as now, hit.at as reset_at
from hit join orders o on o.id = hit.id
where o.status = 'PENDING'
order by expert, o.date;

-- STEP 3 · RESTORE: put those works back to the status they had just before the reset
alter table orders disable trigger trg_guard_orders;
with hit as (
  select distinct on (l.row_id) l.row_id as id, l.old_data
  from activity_log l
  where l.table_name = 'orders' and l.action = 'UPDATE' and l.at >= '2026-11-19'
    and l.old_data->>'status' in ('DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED')
    and l.new_data->>'status' = 'PENDING'
  order by l.row_id, l.at)
update orders o set
  status = hit.old_data->>'status',
  close_at = coalesce(o.close_at, (hit.old_data->>'close_at')::timestamptz),
  submit_at = coalesce(o.submit_at, (hit.old_data->>'submit_at')::timestamptz),
  extra = jsonb_set(
            case when jsonb_typeof(hit.old_data->'extra'->'tst') = 'object' then jsonb_set(o.extra, '{tst}', hit.old_data->'extra'->'tst')
                 else o.extra - 'tst' end,
            '{status}', to_jsonb(hit.old_data->>'status'))
from hit where hit.id = o.id and o.status = 'PENDING'
returning o.id, o.name, o.status;
alter table orders enable trigger trg_guard_orders;
