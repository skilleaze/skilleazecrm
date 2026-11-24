-- 51 · HR records use the key the app uses (fixes Saudath Haseena's punch-in, 24 Nov 2026)
-- Safe to run more than once. Paste into Supabase → SQL Editor → Run.
-- (50 is reserved for docs/pending-sql/50_expert_keep_assignments.sql, not applied yet.)
--
-- Problem: 49 filed a person's own HR records under profiles.person_key. For haseena that column
-- still held an old key (expert:HASEENA) while her login's expert code — and so the app — uses
-- expert:SAUDATH HASEENA. Her punches saved, but the app never saw them, so "Punch in now" kept
-- coming back and every tap added another punch.
-- Fix: the key comes from the login's own code (expert_code / agent_code / staff_id), the same way
-- the app builds it; profiles.person_key is kept in step; haseena's records move to the right key.

-- 1 ── own HR records: key from the login's code ───────────────────────────────────────────
create or replace function public.login_hr_key(p_uid uuid) returns text
language sql stable security definer set search_path to 'public' as $fn$
  select coalesce(case p.role
           when 'expert' then nullif('expert:' || nullif(trim(p.expert_code), ''), 'expert:')
           when 'sales'  then nullif('sales:'  || nullif(trim(p.agent_code), ''),  'sales:')
           when 'cse'    then nullif('cse:'    || nullif(trim(p.staff_id), ''),    'cse:')
         end, nullif(p.person_key, ''))
  from profiles p where p.id = p_uid and p.active
$fn$;

create or replace function public.hr_own_key() returns trigger
language plpgsql security definer set search_path to 'public' as $fn$
declare k text;
begin
  if auth.uid() is null or hr_admin(coalesce(new.branch, 'all')) then return new; end if;
  if new.kind in ('punch', 'leave', 'fix', 'profile', 'seen') then
    k := login_hr_key(auth.uid());
    if coalesce(k, '') <> '' then
      new.person_key := k;
      if new.extra is not null and jsonb_typeof(new.extra) = 'object' and (new.extra->'key') is not null then
        new.extra := jsonb_set(new.extra, '{key}', to_jsonb(k));
      end if;
      update profiles set person_key = k where id = auth.uid() and person_key is distinct from k;
    end if;
    new.user_id := auth.uid();
  end if;
  return new;
end $fn$;

drop trigger if exists trg_hr_own_key on public.hr_records;
create trigger trg_hr_own_key before insert on public.hr_records
  for each row execute function public.hr_own_key();

-- 2 ── bring any out-of-step login (only haseena on 24 Nov) and its records in line ────────
do $fn$
declare r record;
begin
  for r in select p.id, p.person_key as old_k, login_hr_key(p.id) as new_k from profiles p
           where p.active and p.role in ('expert', 'sales', 'cse')
             and login_hr_key(p.id) is not null and p.person_key is distinct from login_hr_key(p.id)
  loop
    if coalesce(r.old_k, '') <> '' then
      update hr_records set person_key = r.new_k,
             extra = case when jsonb_typeof(extra) = 'object' and (extra->'key') is not null
                          then jsonb_set(extra, '{key}', to_jsonb(r.new_k)) else extra end
       where person_key = r.old_k;
    end if;
    update profiles set person_key = r.new_k where id = r.id;
  end loop;
end $fn$;
