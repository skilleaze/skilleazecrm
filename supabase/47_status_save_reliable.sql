-- 47 · Expert work status saves reliably (Share draft / Submit / Close)
-- Safe to run more than once. Paste into Supabase → SQL Editor → Run.
--
-- What it fixes
--  1. sync_order_experts ignored the CV expert (extra.expert) whenever the order also had
--     another service's expert in extra.wx (CV + LinkedIn orders). That expert then lost
--     read/update access to the order, so their saves were silently dropped (0 rows) or
--     refused (403). It also looked codes up in the empty `experts` table.
--  2. patch_extra reported success even when an order could not be updated (0 rows).
--     For orders it now raises an error, so the app shows "Not saved" instead of a false success.
--  3. keep_status_forward let any role move a task back to Not started if the stale copy
--     carried a newer timestamp. Only management, operations, the Puttur manager (or the
--     SQL editor) can move work backwards now, as the business rules say.
--  4. New set_task_status(): one locked, server-side, all-or-nothing status change for
--     experts. It checks the expert is assigned, merges with the latest row (so two
--     experts on one combined order can't overwrite each other) and returns the saved row.
--  5. Backfills missing order_experts rows for the CRM period (from 2 Nov 2026), insert only.
--     On 23 Nov 2026 this was 1 order (IOTA-1794076173580, SAUDATH HASEENA's CV task).

-- 1 ── order_experts follows the order, CV expert included ─────────────────────────────
create or replace function public.sync_order_experts() returns trigger
language plpgsql security definer set search_path to 'public' as $fn$
declare k text; v text; code text; wx jsonb;
begin
  if pg_trigger_depth() > 1 then return new; end if;
  wx := case when jsonb_typeof(new.extra->'wx') = 'object' then new.extra->'wx' else '{}'::jsonb end;
  -- extra.expert is the CV expert, unless it is just a copy of another service's expert
  if coalesce(trim(new.extra->>'expert'), '') <> '' and (wx->'cv') is null
     and not exists (select 1 from jsonb_each_text(wx) w
                     where upper(regexp_replace(trim(w.value), '\s+', ' ', 'g')) = upper(regexp_replace(trim(new.extra->>'expert'), '\s+', ' ', 'g'))) then
    wx := wx || jsonb_build_object('cv', new.extra->>'expert');
  end if;
  for k, v in select key, value from jsonb_each_text(wx) loop
    if k not in ('cv', 'linkedin', 'portfolio', 'jobportal', 'interview') then continue; end if;
    if coalesce(trim(v), '') = '' then
      delete from order_experts where order_id = new.id and service_type = k;
    else
      code := null;
      select e.code into code from experts e
        where upper(regexp_replace(trim(e.code), '\s+', ' ', 'g')) = upper(regexp_replace(trim(v), '\s+', ' ', 'g')) limit 1;
      if code is null then
        select p.expert_code into code from profiles p
          where p.expert_code is not null
            and upper(regexp_replace(trim(p.expert_code), '\s+', ' ', 'g')) = upper(regexp_replace(trim(v), '\s+', ' ', 'g')) limit 1;
      end if;
      if code is not null then
        insert into order_experts (order_id, service_type, expert_code) values (new.id, k, code)
        on conflict (order_id, service_type) do update set expert_code = excluded.expert_code
          where order_experts.expert_code is distinct from excluded.expert_code;
      end if;
    end if;
  end loop;
  return new;
end $fn$;

-- 2 ── patch_extra: no more silent "saved" when nothing was saved ─────────────────────────
create or replace function public.patch_extra(p_table text, p_id text, p_set jsonb, p_unset text[]) returns void
language plpgsql set search_path to 'public' as $fn$
declare n int;
begin
  if p_table not in ('orders','transfers','expenses','ad_days','customer_issues','hr_records','enquiries') then
    raise exception 'not allowed';
  end if;
  execute format('update %I set extra = (coalesce(extra, ''{}''::jsonb) || coalesce($1, ''{}''::jsonb)) - coalesce($2, ''{}''::text[]) where id::text = $3', p_table)
  using p_set, p_unset, p_id;
  get diagnostics n = row_count;
  if n = 0 and p_table = 'orders' then
    raise exception 'Not saved: % % is not open to your login or was removed', p_table, p_id using errcode = '42501';
  end if;
end $fn$;

-- 3 ── keep_status_forward: only management / operations / Puttur manager move work back ───
create or replace function public.keep_status_forward() returns trigger
language plpgsql set search_path to 'public' as $fn$
declare
  done text[] := array['DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED'];
  m jsonb; k text; ov text; nv text; ota numeric; nta numeric;
  can_back boolean := auth.uid() is null or coalesce(is_mgmt(), false) or coalesce(is_ops(), false) or coalesce(is_pmgr(), false);
begin
  if jsonb_typeof(new.extra->'tst') = 'object' and jsonb_typeof(old.extra->'tst') = 'object' then
    m := new.extra->'tst';
    for k in select jsonb_object_keys(new.extra->'tst') loop
      ov := old.extra->'tst'->>k; nv := new.extra->'tst'->>k;
      if ov is null or ov = nv then continue; end if;
      ota := coalesce((old.extra->'tAt'->k->>ov)::numeric, 0);
      nta := coalesce((new.extra->'tAt'->k->>nv)::numeric, 0);
      if (ov = any(done) and nv = 'PENDING' and (not can_back or nta <= ota))
         or (ov = 'CLOSED' and nv in ('DRAFT SHARED', 'CV SUBMITTED') and (not can_back or nta <= ota)) then
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
  if (new.extra->'status') is not null then new.extra := jsonb_set(new.extra, '{status}', to_jsonb(new.status)); end if;
  if new.submit_at is null then new.submit_at := old.submit_at; end if;
  if new.close_at is null and new.status = 'CLOSED' then new.close_at := old.close_at; end if;
  if (old.extra->'submitAt') is not null and coalesce(new.extra->>'submitAt', '') = '' then new.extra := jsonb_set(new.extra, '{submitAt}', old.extra->'submitAt'); end if;
  if new.status = 'CLOSED' and (old.extra->'closeAt') is not null and coalesce(new.extra->>'closeAt', '') = '' then new.extra := jsonb_set(new.extra, '{closeAt}', old.extra->'closeAt'); end if;
  return new;
end $fn$;

-- 4 ── set_task_status: the one safe way for experts to move work forward ─────────────────
create or replace function public.set_task_status(p_id text, p_status text, p_task text default null, p_types text[] default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $fn$
declare
  me text := my_expert();
  boss boolean := coalesce(is_mgmt(), false) or coalesce(is_head(), false) or coalesce(is_pmgr(), false);
  rk jsonb := '{"PENDING":0,"DRAFT SHARED":1,"REVISION":2,"CV SUBMITTED":3,"CLOSED":4}'::jsonb;
  o orders%rowtype; ex jsonb; tst jsonb; tat jsonb; k text; overall text; n int;
  nowms numeric := floor(extract(epoch from clock_timestamp()) * 1000);
  nme text;
begin
  if p_status is null or (rk->p_status) is null then raise exception 'Unknown status %', p_status; end if;
  if me is null and not boss then raise exception 'Only the assigned expert, management or operations can change work status'; end if;
  select * into o from orders where id = p_id for update;
  if not found then raise exception 'Order % was not found', p_id; end if;
  if coalesce(o.summary, false) then raise exception 'Sheet adjustment lines are read-only'; end if;
  ex := coalesce(o.extra, '{}'::jsonb);
  if me is not null and not boss then
    nme := upper(regexp_replace(trim(me), '\s+', ' ', 'g'));
    if not (exists (select 1 from order_experts oe where oe.order_id = p_id and upper(regexp_replace(trim(oe.expert_code), '\s+', ' ', 'g')) = nme and (p_task is null or oe.service_type = p_task))
        or (coalesce(p_task, 'cv') = 'cv' and upper(regexp_replace(trim(coalesce(ex->>'expert', '')), '\s+', ' ', 'g')) = nme)
        or (p_task is not null and upper(regexp_replace(trim(coalesce(ex->'wx'->>p_task, '')), '\s+', ' ', 'g')) = nme)) then
      raise exception 'This order is not assigned to you';
    end if;
    if p_status = 'PENDING' then raise exception 'Work cannot be moved back to Not started. Ask operations'; end if;
    if o.pay_status = 'PARTIAL' and p_status in ('CV SUBMITTED', 'CLOSED') then raise exception 'Balance not received yet. Share draft only'; end if;
  end if;

  tst := case when jsonb_typeof(ex->'tst') = 'object' then ex->'tst' else '{}'::jsonb end;
  if p_types is not null and coalesce(array_length(p_types, 1), 0) > 1 then
    foreach k in array p_types loop
      if (tst->k) is null then tst := tst || jsonb_build_object(k, o.status); end if;
    end loop;
  end if;
  select count(*) into n from jsonb_object_keys(tst);
  tat := case when jsonb_typeof(ex->'tAt') = 'object' then ex->'tAt' else '{}'::jsonb end;

  if n > 1 then
    if p_task is null or (tst->p_task) is null then
      if me is not null and not boss then raise exception 'Pick which service of this order you are updating'; end if;
      for k in select jsonb_object_keys(tst) loop
        tst := tst || jsonb_build_object(k, p_status);
        tat := tat || jsonb_build_object(k, coalesce(tat->k, '{}'::jsonb) || jsonb_build_object(p_status, nowms));
      end loop;
    else
      tst := tst || jsonb_build_object(p_task, p_status);
      tat := tat || jsonb_build_object(p_task, coalesce(tat->p_task, '{}'::jsonb) || jsonb_build_object(p_status, nowms));
    end if;
    select v into overall from jsonb_each_text(tst) t(kk, v) order by (rk->>v)::int nulls first limit 1;
  else
    overall := p_status;
    for k in select jsonb_object_keys(tst) loop
      tst := tst || jsonb_build_object(k, p_status);
      tat := tat || jsonb_build_object(k, coalesce(tat->k, '{}'::jsonb) || jsonb_build_object(p_status, nowms));
    end loop;
  end if;

  ex := ex || jsonb_build_object('status', overall);
  if n > 0 then ex := ex || jsonb_build_object('tst', tst, 'tAt', tat); end if;
  if (rk->>overall)::int >= 3 and coalesce(ex->>'submitAt', '') in ('', '0') then ex := ex || jsonb_build_object('submitAt', nowms); end if;
  if overall = 'CLOSED' then ex := ex || jsonb_build_object('closeAt', nowms); end if;

  update orders set status = overall, extra = ex where id = p_id returning * into o;
  if not found then raise exception 'Order % was not saved', p_id; end if;
  return jsonb_build_object('id', o.id, 'date', o.date, 'price', o.price, 'paid', o.paid, 'pay_status', o.pay_status, 'status', o.status, 'extra', o.extra);
end $fn$;

revoke all on function public.set_task_status(text, text, text, text[]) from public, anon;
grant execute on function public.set_task_status(text, text, text, text[]) to authenticated;

-- 5 ── backfill missing expert links (CRM period only, insert only, never overwrites) ──────
insert into order_experts (order_id, service_type, expert_code)
select distinct o.id, x.k, p.expert_code
from orders o
cross join lateral (
  select key k, value v from jsonb_each_text(case when jsonb_typeof(o.extra->'wx') = 'object' then o.extra->'wx' else '{}'::jsonb end)
  union all
  select 'cv', o.extra->>'expert' where coalesce(trim(o.extra->>'expert'), '') <> '' and (o.extra->'wx'->'cv') is null
    and not exists (select 1 from jsonb_each_text(case when jsonb_typeof(o.extra->'wx') = 'object' then o.extra->'wx' else '{}'::jsonb end) w
                    where upper(regexp_replace(trim(w.value), '\s+', ' ', 'g')) = upper(regexp_replace(trim(o.extra->>'expert'), '\s+', ' ', 'g')))
) x
join profiles p on p.expert_code is not null
  and upper(regexp_replace(trim(p.expert_code), '\s+', ' ', 'g')) = upper(regexp_replace(trim(x.v), '\s+', ' ', 'g'))
where x.k in ('cv', 'linkedin', 'portfolio', 'jobportal', 'interview') and coalesce(trim(x.v), '') <> ''
  and not coalesce(o.summary, false) and o.date >= '2026-11-02'
  and not exists (select 1 from order_experts oe where oe.order_id = o.id and oe.service_type = x.k)
on conflict (order_id, service_type) do nothing;
