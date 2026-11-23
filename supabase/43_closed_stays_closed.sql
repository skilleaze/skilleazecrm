-- Skilleaze HQ · closed work stays closed; CRM status follows the experts' task statuses. Safe to run again.
-- Run in 3 steps: STEP 1, then STEP 2 (report), then STEP 3 (restore).

-- STEP 1 · new guard
-- Only management, operations (incl. Head of Operations) and the Puttur manager can move work backwards
-- (Closed → anything but Revision, or Started → Not started). Everyone else's out-of-date copy keeps the saved status.
-- Combined orders (CV + LinkedIn …): the order status is always the least-advanced task, worked out from the protected task statuses.
create or replace function keep_status_forward() returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  done text[] := array['DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED'];
  rk jsonb := '{"PENDING":0,"URGENT":0,"DRAFT SHARED":1,"REVISION":2,"CV SUBMITTED":3,"CLOSED":4}';
  boss boolean := coalesce(is_mgmt() or is_ops() or is_pmgr(), false);
  m jsonb; k text; ov text; nv text; low text;
begin
  if jsonb_typeof(new.extra->'tst') = 'object' then
    m := new.extra->'tst';
    if jsonb_typeof(old.extra->'tst') = 'object' and not boss then
      for k in select jsonb_object_keys(m) loop
        ov := old.extra->'tst'->>k; nv := m->>k;
        if ov is null or ov = nv then continue; end if;
        if (ov = any(done) and nv in ('PENDING', 'URGENT')) or (ov = 'CLOSED' and nv <> 'REVISION') then
          m := m || jsonb_build_object(k, ov);
        end if;
      end loop;
    elsif jsonb_typeof(old.extra->'tst') is distinct from 'object' and old.status = 'CLOSED' and not boss then
      -- an order closed before task statuses existed: every task stays closed unless it's a Revision
      for k in select jsonb_object_keys(m) loop
        if m->>k <> 'REVISION' then m := m || jsonb_build_object(k, 'CLOSED'); end if;
      end loop;
    end if;
    new.extra := jsonb_set(new.extra, '{tst}', m);
    if jsonb_typeof(old.extra->'tAt') = 'object' then
      new.extra := jsonb_set(new.extra, '{tAt}', (
        select coalesce(jsonb_object_agg(t, coalesce(old.extra->'tAt'->t, '{}'::jsonb) || coalesce(new.extra->'tAt'->t, '{}'::jsonb)), '{}'::jsonb)
        from (select jsonb_object_keys(old.extra->'tAt') t union select jsonb_object_keys(coalesce(new.extra->'tAt', '{}'::jsonb))) x));
    end if;
    select v into low from jsonb_each_text(m) e(t, v) order by coalesce((rk->>v)::int, 0) limit 1;
    if low is not null then new.status := low; end if;
  elsif not boss then
    if old.status = any(done) and coalesce(new.status, 'PENDING') in ('PENDING', 'URGENT') then new.status := old.status; end if;
    if old.status = 'CLOSED' and new.status <> 'REVISION' then new.status := old.status; end if;
  end if;
  if new.extra ? 'status' then new.extra := jsonb_set(new.extra, '{status}', to_jsonb(new.status)); end if;
  if new.submit_at is null then new.submit_at := old.submit_at; end if;
  if new.close_at  is null and new.status = 'CLOSED' then new.close_at := old.close_at; end if;
  if old.extra ? 'submitAt' and coalesce(new.extra->>'submitAt', '') = '' then new.extra := jsonb_set(new.extra, '{submitAt}', old.extra->'submitAt'); end if;
  if new.status = 'CLOSED' and old.extra ? 'closeAt' and coalesce(new.extra->>'closeAt', '') = '' then new.extra := jsonb_set(new.extra, '{closeAt}', old.extra->'closeAt'); end if;
  return new;
end $fn$;
drop trigger if exists trg_keep_status_forward on orders;
create trigger trg_keep_status_forward before update on orders for each row execute function keep_status_forward();
select 'guard ready' as ok;

-- STEP 2 · REPORT: closed work that was moved back by someone who isn't management / operations / Puttur manager
with bad as (
  select distinct on (l.row_id) l.row_id as id, l.at, l.old_data, l.new_data, coalesce(p.role::text, 'system / not signed in') as by_role
  from activity_log l left join profiles p on p.id = l.user_id
  where l.table_name = 'orders' and l.action = 'UPDATE'
    and l.old_data->>'status' = 'CLOSED' and coalesce(l.new_data->>'status', '') not in ('CLOSED', 'REVISION')
    and coalesce(p.role::text, '') not in ('management', 'ops', 'manager')
  order by l.row_id, l.at)
select coalesce(o.extra->>'expert', '-') as expert, o.id, o.name, o.date, bad.by_role as moved_by,
       bad.new_data->>'status' as moved_to, o.status as now, bad.at as moved_at
from bad join orders o on o.id = bad.id
where o.status <> 'CLOSED'
order by expert, o.date;

-- duplicate check: same agent/consultant + phone + services + day saved more than once
select coalesce(agent_code, 'P:' || cse_id) as owner, phone, date, extra->'services' as services, count(*) as copies, string_agg(id, ', ') as ids
from orders where date >= '2026-11-02' and coalesce(phone, '') <> ''
group by 1, 2, 3, 4 having count(*) > 1 order by date desc;

-- STEP 3 · RESTORE the STEP 2 orders to Closed (keeps their original closed date; Revision ones are left alone)
alter table orders disable trigger trg_guard_orders;
alter table orders disable trigger trg_keep_status_forward;
with bad as (
  select distinct on (l.row_id) l.row_id as id, l.old_data
  from activity_log l left join profiles p on p.id = l.user_id
  where l.table_name = 'orders' and l.action = 'UPDATE'
    and l.old_data->>'status' = 'CLOSED' and coalesce(l.new_data->>'status', '') not in ('CLOSED', 'REVISION')
    and coalesce(p.role::text, '') not in ('management', 'ops', 'manager')
  order by l.row_id, l.at)
update orders o set
  status = 'CLOSED',
  close_at = coalesce(o.close_at, (bad.old_data->>'close_at')::timestamptz),
  extra = jsonb_set(
            case when jsonb_typeof(o.extra->'tst') = 'object'
                 then jsonb_set(o.extra, '{tst}', (select jsonb_object_agg(t, case when v = 'REVISION' then 'REVISION' else 'CLOSED' end) from jsonb_each_text(o.extra->'tst') e(t, v)))
                 else o.extra end,
            '{status}', '"CLOSED"')
from bad where bad.id = o.id and o.status not in ('CLOSED', 'REVISION')
returning o.id, o.name, o.status;
alter table orders enable trigger trg_keep_status_forward;
alter table orders enable trigger trg_guard_orders;
