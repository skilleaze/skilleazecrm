-- Stratt HQ · access levels, per-module permissions, Google login limited to company domains
-- Run after schema.sql and seed.sql.

-- 1. Access levels
create type access_level as enum ('super_admin', 'admin', 'user');
alter table profiles add column access_level access_level not null default 'user';

create table module_permissions (
  profile_id uuid not null references profiles on delete cascade,
  module text not null check (module in ('dashboard','leads','listings','clients','deals','marketing','finance','hr','documents','tasks','reports','settings')),
  can_view boolean not null default true,
  can_edit boolean not null default false,
  primary key (profile_id, module)
);
alter table module_permissions enable row level security;

-- People you set up before they first sign in with Google
create table staff_access (
  email text primary key check (lower(split_part(email, '@', 2)) in ('stratt.ae', 'stratton.ae')),
  full_name text,
  role app_role not null default 'agent',
  access_level access_level not null default 'user',
  view_modules text[] not null default '{}',
  edit_modules text[] not null default '{}'
);
alter table staff_access enable row level security;

-- 2. Permission checks
create or replace function my_level() returns access_level
language sql stable security definer set search_path = public as $$
  select access_level from profiles where id = auth.uid() and active
$$;

create or replace function is_super_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(my_level() = 'super_admin', false)
$$;

create or replace function can_view(m text) returns boolean
language sql stable security definer set search_path = public as $$
  select is_super_admin() or exists (
    select 1 from module_permissions p join profiles pr on pr.id = p.profile_id
    where p.profile_id = auth.uid() and p.module = m and pr.active and (p.can_view or p.can_edit))
$$;

create or replace function can_edit(m text) returns boolean
language sql stable security definer set search_path = public as $$
  select is_super_admin() or exists (
    select 1 from module_permissions p join profiles pr on pr.id = p.profile_id
    where p.profile_id = auth.uid() and p.module = m and pr.active and p.can_edit)
$$;

-- 3. Only stratt.ae and stratton.ae accounts can be created
create or replace function enforce_company_domain() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if lower(split_part(new.email, '@', 2)) not in ('stratt.ae', 'stratton.ae') then
    raise exception 'Only stratt.ae and stratton.ae accounts can sign in';
  end if;
  return new;
end $$;
create trigger enforce_company_domain before insert or update of email on auth.users
for each row execute function enforce_company_domain();

-- 4. New sign-in: create profile and apply any pre-set access
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare s staff_access;
begin
  select * into s from staff_access where lower(email) = lower(new.email);
  insert into profiles (id, full_name, email, role, access_level)
  values (new.id,
          coalesce(s.full_name, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', new.email),
          lower(new.email),
          coalesce(s.role, 'agent'),
          coalesce(s.access_level, 'user'));
  if s.email is not null then
    insert into module_permissions (profile_id, module, can_view, can_edit)
    select new.id, m, true, m = any(s.edit_modules)
    from unnest(s.view_modules || s.edit_modules) m
    on conflict (profile_id, module) do update set can_edit = excluded.can_edit;
  end if;
  return new;
end $$;

-- 5. Replace the role-based policies with module permissions
drop policy if exists "read own or managers read all" on profiles;
drop policy if exists "ceo admin manage profiles" on profiles;
drop policy if exists "sales read" on clients;          drop policy if exists "sales write" on clients;
drop policy if exists "listings read" on listings;      drop policy if exists "listings write" on listings;
drop policy if exists "leads read" on leads;            drop policy if exists "leads write" on leads;
drop policy if exists "deals read" on deals;            drop policy if exists "deals write" on deals;
drop policy if exists "marketing" on marketing_spend;
drop policy if exists "hr employees" on employees;      drop policy if exists "hr attendance" on attendance;
drop policy if exists "payroll" on payroll;
drop policy if exists "finance tx" on transactions;     drop policy if exists "finance petty" on petty_cash;
drop policy if exists "finance urgent" on urgent_payments; drop policy if exists "finance budget" on budget_lines;
drop policy if exists "tasks" on tasks;                 drop policy if exists "documents" on documents;

do $$
declare t record;
begin
  for t in select * from (values
    ('clients','clients'), ('listings','listings'), ('leads','leads'), ('deals','deals'),
    ('marketing_spend','marketing'),
    ('employees','hr'), ('attendance','hr'), ('payroll','hr'),
    ('transactions','finance'), ('petty_cash','finance'), ('urgent_payments','finance'), ('budget_lines','finance'),
    ('tasks','tasks'), ('documents','documents')
  ) v(tbl, module) loop
    execute format('create policy "module view" on %I for select using (can_view(%L))', t.tbl, t.module);
    execute format('create policy "module insert" on %I for insert with check (can_edit(%L))', t.tbl, t.module);
    execute format('create policy "module update" on %I for update using (can_edit(%L)) with check (can_edit(%L))', t.tbl, t.module, t.module);
    execute format('create policy "module delete" on %I for delete using (can_edit(%L))', t.tbl, t.module);
  end loop;
end $$;

-- Everyone keeps sight of their own tasks, attendance and pay
create policy "own tasks" on tasks for select using (assignee_id = auth.uid());
create policy "update own tasks" on tasks for update using (assignee_id = auth.uid()) with check (assignee_id = auth.uid());
-- (The "own employee row", "own attendance" and "own payroll" policies from schema.sql stay in place.)

-- Profiles: everyone reads their own; admins read all; only super admins change people
create policy "profiles read" on profiles for select
  using (id = auth.uid() or my_level() in ('super_admin', 'admin'));
create policy "profiles manage" on profiles for all
  using (is_super_admin()) with check (is_super_admin());

-- Permissions: super admins manage everyone; admins manage people at user level
create policy "permissions read" on module_permissions for select
  using (profile_id = auth.uid() or my_level() in ('super_admin', 'admin'));
create policy "permissions manage" on module_permissions for all
  using (is_super_admin() or (my_level() = 'admin' and (select access_level from profiles where id = profile_id) = 'user'))
  with check (is_super_admin() or (my_level() = 'admin' and (select access_level from profiles where id = profile_id) = 'user'));

create policy "staff access manage" on staff_access for all
  using (is_super_admin()) with check (is_super_admin());

-- 6. CEO and admin are super admins
-- Replace admin@stratt.ae with the admin's real Google account.
insert into staff_access (email, full_name, role, access_level) values
  ('ali@stratt.ae', 'Ali Hussain', 'ceo', 'super_admin'),
  ('admin@stratt.ae', 'Admin', 'admin', 'super_admin')
on conflict (email) do update set access_level = excluded.access_level, role = excluded.role, full_name = excluded.full_name;

-- Anyone already created by email/password
update profiles p set access_level = s.access_level, role = s.role, full_name = coalesce(s.full_name, p.full_name)
from staff_access s where lower(p.email) = lower(s.email);
