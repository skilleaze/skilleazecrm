-- =====================================================================
-- Skilleaze CRM · step 2 (run once, after schema.sql)
-- SQL Editor → New query → paste → Run
-- =====================================================================

-- 1. Keep the CRM's full record next to the searchable columns
alter table transfers       add column if not exists extra jsonb not null default '{}';
alter table expenses        add column if not exists extra jsonb not null default '{}';
alter table ad_days         add column if not exists extra jsonb not null default '{}';
alter table enquiries       add column if not exists extra jsonb not null default '{}';
alter table customer_issues add column if not exists extra jsonb not null default '{}';

-- 2. Screenshots are uploaded by the app; old sheet rows have none
alter table transfers drop constraint if exists transfer_needs_screenshot;

-- 3. Settings shared by the whole CRM (payroll, Puttur, expert works, account picks …)
create table if not exists app_kv (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
alter table app_kv enable row level security;
create policy kv_read on app_kv for select using (
  auth.uid() is not null and (
    key not in ('payroll','salaryStatements','transferAcct','agentDeals')
    or is_mgmt() or is_head() or (is_pmgr() and key = 'payroll')));
create policy kv_write on app_kv for all using (is_mgmt() or is_ops() or is_pmgr())
  with check (is_mgmt() or is_ops() or is_pmgr());
drop trigger if exists trg_log_app_kv on app_kv;
create trigger trg_log_app_kv after insert or update or delete on app_kv for each row execute function log_change();

-- 4. "Must change password" flag + last sign-in
alter table profiles add column if not exists must_change_pw boolean not null default true;
alter table profiles add column if not exists last_login timestamptz;
create or replace function touch_login(changed boolean default false) returns void language sql security definer as $$
  update profiles set last_login = now(), must_change_pw = case when changed then false else must_change_pw end where id = auth.uid()
$$;

-- 5. First management account (Muneez)
--    Before running this file: Authentication → Users → Add user → Create new user
--      Email:    muneez@skilleaze.com
--      Password: (choose one)       ✔ Auto Confirm User
insert into profiles (id, username, full_name, role, must_change_pw)
select id, 'muneez', 'Muneez', 'management', false
from auth.users where email = 'muneez@skilleaze.com'
on conflict (id) do update set role = 'management', active = true;

select username, role from profiles;   -- should show: muneez | management
