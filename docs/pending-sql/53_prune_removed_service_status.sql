-- 53 · Removed services no longer block combined orders (health check 28 Nov 2026)
--
-- Problem: when a service is removed from an order (e.g. LinkedIn taken off a CV + LinkedIn order),
-- its entry stayed in the per-service status map extra.tst. The order then still counted as a
-- combined order on the server (overall status = least advanced service = the removed one, stuck at
-- PENDING), while the app saw a single-service order and sent no service name, so set_task_status
-- refused every expert update with "Pick which service of this order you are updating"
-- (SIGMA-1794924415055, hafsath.muyeena, 28 Nov 13:52–14:18 IST).
--
-- Fix: a BEFORE UPDATE trigger keeps extra.tst to the services the order still has (same mapping as
-- the app's svcType) and recomputes the overall status from what is left. It runs after
-- trg_guard_orders (so an Operations save that removes a service is not refused for "changing
-- status") and before trg_keep_status_forward (which still stops any backwards move).
-- Removing a key can only raise the least-advanced value, so status never moves backwards here.
-- Safe to run twice.

create or replace function public.prune_tst_services() returns trigger
language plpgsql set search_path = public as $fn$
declare
  ty text[]; m jsonb; ov text; nowms numeric := floor(extract(epoch from clock_timestamp()) * 1000);
  rk jsonb := '{"PENDING":0,"DRAFT SHARED":1,"REVISION":2,"CV SUBMITTED":3,"CLOSED":4}'::jsonb;
begin
  if coalesce(jsonb_typeof(new.extra->'tst'), '') <> 'object'
     or coalesce(jsonb_typeof(new.extra->'services'), '') <> 'array'
     or jsonb_array_length(new.extra->'services') = 0 then
    return new;
  end if;
  select array_agg(distinct case
           when s = 'INTERVIEW TRAINING SESSION' then 'interview'
           when s = 'LINKEDIN OPTIMIZATION' then 'linkedin'
           when s = 'PORTFOLIO WEBSITE' then 'portfolio'
           when s in ('JOB PORTAL OPTIMISATION', 'NAUKRI OPTIMISATION', 'INDEED OPTIMISATION') then 'jobportal'
           else 'cv' end)
    into ty from jsonb_array_elements_text(new.extra->'services') s;
  select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) into m
    from jsonb_each(new.extra->'tst') e(k, v) where k = any(ty);
  if m = (new.extra->'tst') or m = '{}'::jsonb then return new; end if;

  new.extra := jsonb_set(new.extra, '{tst}', m);
  select v into ov from jsonb_each_text(m) t(k, v) order by (rk->>v)::int nulls first limit 1;
  if ov is null or (rk->ov) is null then return new; end if;
  if (rk->>ov)::int > coalesce((rk->>new.status)::int, -1) then
    new.status := ov;
    if (new.extra->'status') is not null then new.extra := jsonb_set(new.extra, '{status}', to_jsonb(ov)); end if;
    if (rk->>ov)::int >= 3 and coalesce(new.extra->>'submitAt', '') in ('', '0') then
      new.extra := jsonb_set(new.extra, '{submitAt}', to_jsonb(nowms));
    end if;
    if ov = 'CLOSED' and coalesce(new.extra->>'closeAt', '') in ('', '0') then
      new.extra := jsonb_set(new.extra, '{closeAt}', to_jsonb(nowms));
    end if;
  end if;
  return new;
end $fn$;

drop trigger if exists trg_h_prune_tst on public.orders;
create trigger trg_h_prune_tst before update on public.orders
  for each row execute function public.prune_tst_services();

-- One-time repair of the orders that already carry a removed service's status (proved by
-- activity_log: the service was taken off by the agent; both dated after 2 Nov 2026).
--   SIGMA-1794924415055  LinkedIn removed 28 Nov 13:51 IST → tst {cv: DRAFT SHARED}, status DRAFT SHARED
--   WAU-1793944796085    Job portal removed → tst {cv: CLOSED, linkedin: PENDING}, status stays PENDING
alter table public.orders disable trigger trg_guard_orders;
update public.orders set extra = extra
 where id in ('SIGMA-1794924415055', 'WAU-1793944796085') and date >= '2026-11-02';
alter table public.orders enable trigger trg_guard_orders;
