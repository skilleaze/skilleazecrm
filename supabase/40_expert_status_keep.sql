-- Skilleaze HQ · expert work status: closed stays closed (run once, safe to run again)
-- Combined orders (CV + LinkedIn …) keep each expert's status in extra.tst.
-- An out-of-date copy from one expert used to overwrite the other expert's task status.

create or replace function keep_status_forward() returns trigger language plpgsql as $fn$
declare
  done text[] := array['DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED'];
  rk jsonb := '{"PENDING":0,"DRAFT SHARED":1,"REVISION":2,"CV SUBMITTED":3,"CLOSED":4}';
  m jsonb; k text; ov text; nv text; ota numeric; nta numeric; low text;
begin
  -- A. Per-task statuses (extra.tst): keep each task's newest real status
  if jsonb_typeof(new.extra->'tst') = 'object' and jsonb_typeof(old.extra->'tst') = 'object' then
    m := new.extra->'tst';
    for k in select jsonb_object_keys(old.extra->'tst') loop
      ov := old.extra->'tst'->>k; nv := new.extra->'tst'->>k;
      ota := coalesce((old.extra->'tAt'->k->>ov)::numeric, 0);
      nta := coalesce((new.extra->'tAt'->k->>coalesce(nv, ''))::numeric, 0);
      if nv is null then m := m || jsonb_build_object(k, ov);
      elsif ov = nv then null;
      elsif ov = any(done) and nv = 'PENDING' then m := m || jsonb_build_object(k, ov);
      elsif ov = 'CLOSED' and nv in ('DRAFT SHARED', 'CV SUBMITTED') and nta <= ota then m := m || jsonb_build_object(k, ov);
      end if;
    end loop;
    new.extra := jsonb_set(new.extra, '{tst}', m);
    -- keep every task's time stamps
    if jsonb_typeof(old.extra->'tAt') = 'object' then
      new.extra := jsonb_set(new.extra, '{tAt}', (
        select coalesce(jsonb_object_agg(t, coalesce(old.extra->'tAt'->t, '{}'::jsonb) || coalesce(new.extra->'tAt'->t, '{}'::jsonb)), '{}'::jsonb)
        from (select jsonb_object_keys(old.extra->'tAt') t union select jsonb_object_keys(coalesce(new.extra->'tAt', '{}'::jsonb))) x));
    end if;
    -- order status = the least-advanced task
    select v into low from jsonb_each_text(m) e(t, v) order by coalesce((rk->>v)::int, 0) limit 1;
    if low is not null then new.status := low; end if;
  else
    -- B. Single-task orders: old rules
    if old.status = any(done) and coalesce(new.status, 'PENDING') = 'PENDING' then new.status := old.status; end if;
    if old.status = 'CLOSED' and new.status in ('DRAFT SHARED', 'CV SUBMITTED') then new.status := old.status; end if;
  end if;
  -- C. Keep the saved copy in step and never lose submitted / closed times
  if new.extra ? 'status' then new.extra := jsonb_set(new.extra, '{status}', to_jsonb(new.status)); end if;
  if new.submit_at is null then new.submit_at := old.submit_at; end if;
  if new.close_at  is null and new.status = 'CLOSED' then new.close_at := old.close_at; end if;
  if old.extra ? 'submitAt' and coalesce(new.extra->>'submitAt', '') = '' then new.extra := jsonb_set(new.extra, '{submitAt}', old.extra->'submitAt'); end if;
  if new.status = 'CLOSED' and old.extra ? 'closeAt' and coalesce(new.extra->>'closeAt', '') = '' then new.extra := jsonb_set(new.extra, '{closeAt}', old.extra->'closeAt'); end if;
  return new;
end $fn$;

drop trigger if exists trg_keep_status_forward on orders;
create trigger trg_keep_status_forward before update on orders for each row execute function keep_status_forward();

-- REPORT (run on its own first): expert tasks that were CLOSED and later pushed back by an out-of-date copy
with closed as (
  select l.row_id as id, t.k, max(l.at) as at
  from activity_log l cross join lateral jsonb_object_keys(coalesce(l.new_data->'extra'->'tst', '{}'::jsonb)) t(k)
  where l.table_name = 'orders' and l.new_data->'extra'->'tst'->>t.k = 'CLOSED'
  group by 1, 2)
select o.id, o.name, o.date, c.k as task, coalesce(o.extra->'wx'->>c.k, o.extra->>'expert') as expert,
       o.extra->'tst'->>c.k as now_status, c.at as was_closed_at
from orders o join closed c on c.id = o.id
where o.extra->'tst'->>c.k in ('PENDING', 'DRAFT SHARED', 'CV SUBMITTED')
  and coalesce((o.extra->'tAt'->c.k->>(o.extra->'tst'->>c.k))::numeric, 0) < extract(epoch from c.at) * 1000
order by expert, o.date;

-- RESTORE (run after checking the report): put those tasks back to CLOSED
alter table orders disable trigger trg_guard_orders;
with closed as (
  select l.row_id as id, t.k, max(l.at) as at
  from activity_log l cross join lateral jsonb_object_keys(coalesce(l.new_data->'extra'->'tst', '{}'::jsonb)) t(k)
  where l.table_name = 'orders' and l.new_data->'extra'->'tst'->>t.k = 'CLOSED'
  group by 1, 2),
fix as (
  select o.id, jsonb_object_agg(c.k, 'CLOSED') as p
  from orders o join closed c on c.id = o.id
  where o.extra->'tst'->>c.k in ('PENDING', 'DRAFT SHARED', 'CV SUBMITTED')
    and coalesce((o.extra->'tAt'->c.k->>(o.extra->'tst'->>c.k))::numeric, 0) < extract(epoch from c.at) * 1000
  group by o.id)
update orders o set extra = jsonb_set(o.extra, '{tst}', (o.extra->'tst') || fix.p)
from fix where fix.id = o.id
returning o.id, o.name, o.status;
alter table orders enable trigger trg_guard_orders;
