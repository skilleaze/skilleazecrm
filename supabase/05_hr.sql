-- Skilleaze CRM · HR & attendance (run once)
-- SQL Editor → New query → paste → Run

alter table profiles add column if not exists person_key text;

create or replace function set_my_person_key(k text) returns void language sql security definer as $$
  update profiles set person_key = k where id = auth.uid() and person_key is null
$$;
create or replace function my_pkey() returns text language sql stable security definer as $$
  select person_key from profiles where id = auth.uid() and active
$$;
create or replace function hr_admin(b text) returns boolean language sql stable security definer as $$
  select is_mgmt() or (is_head() and b in ('cloud','all')) or (is_pmgr() and b in ('puttur','all'))
$$;

create table if not exists hr_records (
  id          text primary key,
  kind        text not null check (kind in ('punch','leave','fix','profile','advance','holiday','announce','seen','setting')),
  person_key  text,
  branch      text not null default 'all' check (branch in ('cloud','puttur','all')),
  extra       jsonb not null default '{}',
  user_id     uuid default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists hr_kind_person on hr_records(kind, person_key);
alter table hr_records enable row level security;

drop policy if exists hr_read on hr_records;
create policy hr_read on hr_records for select using (
  auth.uid() is not null and (
    kind in ('holiday','announce','setting')
    or person_key = (select my_pkey())
    or (kind <> 'seen' and hr_admin(branch))));

drop policy if exists hr_ins on hr_records;
create policy hr_ins on hr_records for insert with check (
  hr_admin(branch)
  or (kind in ('punch','leave','fix','profile','seen') and person_key = (select my_pkey())));

drop policy if exists hr_upd on hr_records;
create policy hr_upd on hr_records for update
  using (hr_admin(branch) or (kind in ('punch','leave','fix','profile','seen') and person_key = (select my_pkey())))
  with check (hr_admin(branch) or (kind in ('punch','leave','fix','profile','seen') and person_key = (select my_pkey())));

drop policy if exists hr_del on hr_records;
create policy hr_del on hr_records for delete using (hr_admin(branch) or (kind in ('leave','fix') and person_key = (select my_pkey()) and extra->>'status' = 'pending'));

-- Only HR admins can approve or reject; people can't approve their own requests
create or replace function guard_hr() returns trigger language plpgsql security definer as $$
begin
  if new.kind in ('leave','fix') and coalesce(new.extra->>'status','pending') <> 'pending'
     and (tg_op = 'INSERT' or coalesce(old.extra->>'status','pending') <> coalesce(new.extra->>'status','pending')) then
    if not hr_admin(new.branch) or new.person_key = my_pkey() and not is_mgmt() then
      raise exception 'Only HR can approve or reject requests';
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_guard_hr on hr_records;
create trigger trg_guard_hr before insert or update on hr_records for each row execute function guard_hr();

drop trigger if exists trg_log_hr on hr_records;
create trigger trg_log_hr after insert or update or delete on hr_records for each row execute function log_change();

notify pgrst, 'reload schema';
select 'ok' as done;
