-- Stratt HQ · Supabase schema
-- Run once in Supabase → SQL Editor → New query → paste → Run.

create extension if not exists "pgcrypto";

-- Roles and profiles ---------------------------------------------------------
create type app_role as enum ('ceo', 'admin', 'finance', 'hr', 'sales', 'marketing', 'agent');

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  email text unique not null,
  role app_role not null default 'agent',
  phone text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create or replace function my_role() returns app_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function has_role(variadic r app_role[]) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role from profiles where id = auth.uid()) = any(r), false)
$$;

-- New sign-ups get a profile automatically
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email), new.email);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function handle_new_user();

-- Sales ----------------------------------------------------------------------
create table clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  kind text not null default 'buyer' check (kind in ('buyer','seller','owner','tenant','investor')),
  email text, phone text, nationality text, notes text,
  owner_id uuid references profiles,
  created_at timestamptz not null default now()
);

create table listings (
  id uuid primary key default gen_random_uuid(),
  ref text unique,
  title text not null,
  community text, developer text,
  type text check (type in ('apartment','villa','townhouse','penthouse','plot','office')),
  purpose text not null default 'sale' check (purpose in ('sale','rent','off-plan')),
  bedrooms int, size_sqft numeric, price_aed numeric,
  status text not null default 'active' check (status in ('draft','active','reserved','sold','rented','withdrawn')),
  owner_client_id uuid references clients,
  agent_id uuid references profiles,
  permit_no text,
  created_at timestamptz not null default now()
);

create table leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text, phone text,
  source text check (source in ('bayut','dubizzle','property_finder','website','instagram','referral','walk_in','other')),
  stage text not null default 'new' check (stage in ('new','contacted','viewing','offer','won','lost')),
  budget_aed numeric,
  listing_id uuid references listings,
  agent_id uuid references profiles,
  notes text,
  created_at timestamptz not null default now()
);

create table deals (
  id uuid primary key default gen_random_uuid(),
  name text not null,                       -- e.g. 'Imtiaz', 'Nshama'
  developer text,
  listing_id uuid references listings,
  client_id uuid references clients,
  agent_id uuid references profiles,
  value_aed numeric,
  commission_aed numeric not null default 0,
  status text not null default 'open' check (status in ('open','received','under_review','cancelled')),
  received_on date,
  created_at timestamptz not null default now()
);

-- Marketing ------------------------------------------------------------------
create table marketing_spend (
  id uuid primary key default gen_random_uuid(),
  item text not null,
  channel text not null check (channel in ('listing_portal','marketing','market_data')),
  amount_aed numeric not null,
  month date not null,                      -- first day of month
  created_at timestamptz not null default now()
);

-- HR -------------------------------------------------------------------------
create table employees (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles,
  full_name text not null,
  position text,
  portal_code text unique,                  -- ID used by the attendance portal export
  basic_salary_aed numeric,
  joined_on date, left_on date,
  status text not null default 'active' check (status in ('active','left','settlement_pending')),
  created_at timestamptz not null default now()
);

create table attendance (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees on delete cascade,
  work_date date not null,
  punch_in time, punch_out time,
  hours numeric generated always as (
    case when punch_in is not null and punch_out is not null
      then round(extract(epoch from (punch_out - punch_in)) / 3600.0, 2) end) stored,
  source text not null default 'portal_import',
  imported_at timestamptz not null default now(),
  unique (employee_id, work_date)
);

create table payroll (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees,
  month date not null,
  amount_aed numeric not null,
  status text not null default 'paid' check (status in ('draft','paid','owed')),
  paid_on date,
  unique (employee_id, month)
);

-- Finance --------------------------------------------------------------------
create table transactions (
  id uuid primary key default gen_random_uuid(),
  month date not null,
  direction text not null check (direction in ('in','out')),
  category text not null check (category in ('commission','salaries','utilities','marketing','listing_portals','rent_visas_admin','petty_cash','other')),
  description text,
  amount_aed numeric not null check (amount_aed >= 0),
  deal_id uuid references deals,
  created_by uuid references profiles default auth.uid(),
  created_at timestamptz not null default now()
);

create table petty_cash (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null default current_date,
  description text not null,
  category text not null default 'office',
  amount_aed numeric not null,
  created_by uuid references profiles default auth.uid(),
  created_at timestamptz not null default now()
);

create table urgent_payments (
  id uuid primary key default gen_random_uuid(),
  payee text not null,
  type text not null check (type in ('supplier','listing_portal','salary','commission','office','utilities','tax')),
  amount_aed numeric not null,
  due_on date,
  status text not null default 'outstanding' check (status in ('overdue','outstanding','under_review','paid')),
  notes text,
  created_at timestamptz not null default now()
);

create table budget_lines (
  id uuid primary key default gen_random_uuid(),
  year int not null,
  line text not null,
  annual_aed numeric not null
);

-- Work -----------------------------------------------------------------------
create table tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  assignee_id uuid references profiles,
  due_on date,
  done boolean not null default false,
  created_at timestamptz not null default now()
);

create table documents (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text,                                -- contract, form A, passport, title deed
  storage_path text not null,               -- path in the 'documents' storage bucket
  client_id uuid references clients,
  deal_id uuid references deals,
  uploaded_by uuid references profiles default auth.uid(),
  created_at timestamptz not null default now()
);

-- Reporting views ------------------------------------------------------------
create view monthly_cashflow with (security_invoker = true) as
select month,
  sum(amount_aed) filter (where direction = 'in')  as money_in,
  sum(amount_aed) filter (where direction = 'out') as money_out,
  coalesce(sum(amount_aed) filter (where direction = 'in'), 0)
    - coalesce(sum(amount_aed) filter (where direction = 'out'), 0) as net
from transactions group by month order by month;

-- Row level security ---------------------------------------------------------
alter table profiles enable row level security;
alter table clients enable row level security;
alter table listings enable row level security;
alter table leads enable row level security;
alter table deals enable row level security;
alter table marketing_spend enable row level security;
alter table employees enable row level security;
alter table attendance enable row level security;
alter table payroll enable row level security;
alter table transactions enable row level security;
alter table petty_cash enable row level security;
alter table urgent_payments enable row level security;
alter table budget_lines enable row level security;
alter table tasks enable row level security;
alter table documents enable row level security;

create policy "read own or managers read all" on profiles for select
  using (id = auth.uid() or has_role('ceo','admin','hr'));
create policy "ceo admin manage profiles" on profiles for all
  using (has_role('ceo','admin')) with check (has_role('ceo','admin'));

-- Sales data: everyone signed in reads; agents edit their own
create policy "sales read" on clients for select using (auth.uid() is not null);
create policy "sales write" on clients for all using (has_role('ceo','admin','sales') or owner_id = auth.uid())
  with check (has_role('ceo','admin','sales') or owner_id = auth.uid());
create policy "listings read" on listings for select using (auth.uid() is not null);
create policy "listings write" on listings for all using (has_role('ceo','admin','sales','marketing') or agent_id = auth.uid())
  with check (has_role('ceo','admin','sales','marketing') or agent_id = auth.uid());
create policy "leads read" on leads for select using (has_role('ceo','admin','sales','marketing') or agent_id = auth.uid());
create policy "leads write" on leads for all using (has_role('ceo','admin','sales','marketing') or agent_id = auth.uid())
  with check (has_role('ceo','admin','sales','marketing') or agent_id = auth.uid());
create policy "deals read" on deals for select using (has_role('ceo','admin','sales','finance') or agent_id = auth.uid());
create policy "deals write" on deals for all using (has_role('ceo','admin','sales','finance'))
  with check (has_role('ceo','admin','sales','finance'));

create policy "marketing" on marketing_spend for all using (has_role('ceo','admin','marketing','finance'))
  with check (has_role('ceo','admin','marketing','finance'));

-- HR: HR, admin, CEO; staff see their own attendance and pay
create policy "hr employees" on employees for all using (has_role('ceo','admin','hr'))
  with check (has_role('ceo','admin','hr'));
create policy "own employee row" on employees for select using (profile_id = auth.uid());
create policy "hr attendance" on attendance for all using (has_role('ceo','admin','hr'))
  with check (has_role('ceo','admin','hr'));
create policy "own attendance" on attendance for select
  using (employee_id in (select id from employees where profile_id = auth.uid()));
create policy "payroll" on payroll for all using (has_role('ceo','admin','hr','finance'))
  with check (has_role('ceo','admin','hr','finance'));
create policy "own payroll" on payroll for select
  using (employee_id in (select id from employees where profile_id = auth.uid()));

-- Finance: CEO, admin, finance
create policy "finance tx" on transactions for all using (has_role('ceo','admin','finance'))
  with check (has_role('ceo','admin','finance'));
create policy "finance petty" on petty_cash for all using (has_role('ceo','admin','finance'))
  with check (has_role('ceo','admin','finance'));
create policy "finance urgent" on urgent_payments for all using (has_role('ceo','admin','finance'))
  with check (has_role('ceo','admin','finance'));
create policy "finance budget" on budget_lines for all using (has_role('ceo','admin','finance'))
  with check (has_role('ceo','admin','finance'));

create policy "tasks" on tasks for all using (has_role('ceo','admin') or assignee_id = auth.uid())
  with check (has_role('ceo','admin') or assignee_id = auth.uid());
create policy "documents" on documents for all using (auth.uid() is not null) with check (auth.uid() is not null);

-- Storage bucket for documents (private)
insert into storage.buckets (id, name, public) values ('documents', 'documents', false)
on conflict do nothing;
create policy "signed-in read docs" on storage.objects for select
  using (bucket_id = 'documents' and auth.uid() is not null);
create policy "signed-in upload docs" on storage.objects for insert
  with check (bucket_id = 'documents' and auth.uid() is not null);
