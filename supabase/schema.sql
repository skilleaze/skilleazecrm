-- =====================================================================
-- Skilleaze CRM · Supabase setup
-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- Safe to run once on a fresh project.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Roles ----------------------------------------------------
do $$ begin
  create type app_role as enum ('management','ops','sales','expert','cse','manager');
exception when duplicate_object then null; end $$;

-- ---------- People ---------------------------------------------------
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text unique not null,
  full_name   text not null,
  role        app_role not null,
  ops_scope   text check (ops_scope in ('head','orders')),      -- Dhiya = head, Ishfa = orders
  agent_code  text,                                              -- sales agents
  expert_code text,                                              -- experts
  staff_id    text,                                              -- Puttur customer support
  title       text,
  photo_path  text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists agents (
  code       text primary key,              -- ALPHA, BETA …
  name       text not null,
  partner    text,                          -- Muneez / Hashim
  deal       jsonb not null default '{}',   -- commission rules / tiers
  active     boolean not null default true,
  joined     date
);

create table if not exists experts (
  code    text primary key,                 -- FATHIMATH ISHFANA …
  name    text not null,
  active  boolean not null default true
);
create table if not exists expert_skills (
  expert_code text references experts(code) on delete cascade,
  skill       text not null check (skill in ('cv','linkedin','portfolio','jobportal','interview')),
  primary key (expert_code, skill)
);
create table if not exists expert_agents (            -- which agents an expert may work for
  expert_code text references experts(code) on delete cascade,
  agent_code  text references agents(code)  on delete cascade,
  primary key (expert_code, agent_code)
);

create table if not exists puttur_staff (
  id       text primary key,
  name     text not null,
  phone    text,
  role     text not null default 'cse',
  joined   date,
  left_on  date,
  base     numeric not null default 10000,
  target   numeric not null default 100000,
  demo     boolean not null default false
);

-- ---------- Orders ---------------------------------------------------
create table if not exists orders (
  id            text primary key,
  branch        text not null default 'cloud' check (branch in ('cloud','puttur')),
  agent_code    text references agents(code),
  cse_id        text references puttur_staff(id),
  date          date not null,
  created_at    timestamptz not null default now(),
  name          text,
  phone         text,
  country       text,
  services      text[] not null default '{}',
  service_note  text,                                   -- "Which job portal?"
  source        text check (source in ('ad','referral','direct')),
  price         numeric not null default 0,             -- INR
  paid          numeric not null default 0,             -- INR collected
  aed_price     numeric,
  aed_paid      numeric,
  pay_status    text not null default 'PAID' check (pay_status in ('PAID','PARTIAL','REFUNDED')),
  via           text check (via in ('personal','uae','gateway')),
  proof_path    text,
  proof_status  text check (proof_status in ('pending','confirmed','rejected')),
  balance_via   text,
  balance_proof_path text,
  status        text not null default 'PENDING' check (status in ('PENDING','DRAFT SHARED','CV SUBMITTED','REVISION','CLOSED')),
  urgent        boolean not null default false,
  hours         numeric,                                -- interview sessions
  submit_at     timestamptz,
  close_at      timestamptz,
  summary       boolean not null default false,         -- sheet adjustment line (read-only)
  qty           integer,
  tier          text,                                   -- commission tier used
  extra         jsonb not null default '{}',
  created_by    uuid references auth.users(id)
);
create index if not exists orders_agent_date on orders(agent_code, date);
create index if not exists orders_phone on orders(phone);
create index if not exists orders_branch_date on orders(branch, date);

create table if not exists order_experts (            -- one expert per service type
  order_id     text references orders(id) on delete cascade,
  service_type text not null check (service_type in ('cv','linkedin','portfolio','jobportal','interview')),
  expert_code  text references experts(code),
  assigned_at  timestamptz not null default now(),
  assigned_by  uuid references auth.users(id),
  primary key (order_id, service_type)
);
create index if not exists order_experts_expert on order_experts(expert_code);

-- ---------- Ads, cash, expenses ---------------------------------------
create table if not exists ad_days (
  id          text primary key,
  agent_code  text references agents(code),
  date        date not null,
  messages    integer not null default 0,
  aed         numeric not null default 0,
  summary     boolean not null default false,
  tier        text,
  unique (agent_code, date, summary)
);

create table if not exists accounts (                 -- where money lands
  code   text primary key,
  title  text not null,
  kind   text not null default 'bank'                 -- bank / card / prepaid / fund / investment
);
insert into accounts(code,title,kind) values
 ('Muneez','Agents fund · shared account 1','fund'),
 ('Hashim','Agents fund · shared account 2','fund'),
 ('Muneez Personal','Muneez Personal Account','bank'),
 ('Hashim Personal','Hashim Personal Account','bank'),
 ('UAE Hundi','UAE Hundi Account','bank'),
 ('Muneez UAE','Muneez UAE Account','bank'),
 ('Hashim UAE','Hashim UAE Account','bank'),
 ('Meta India Prepaid','Meta Indian Ad Account · prepaid','prepaid'),
 ('Office Investment','Office investment','investment'),
 ('Muneez India CC (ads)','Muneez · Indian credit card (ads)','card'),
 ('Muneez UAE CC','Muneez · UAE credit card','card'),
 ('Hashim UAE CC','Hashim · UAE credit card','card'),
 ('Salary','Paid as salary','fund'),
 ('Expense','Paid as expense','fund')
on conflict do nothing;

create table if not exists transfers (
  id           text primary key default ('t' || floor(extract(epoch from now())*1000)::text),
  agent_code   text references agents(code),
  date         date not null,
  amount       numeric not null,
  account_code text references accounts(code),
  note         text,
  proof_path   text,
  status       text not null default 'pending' check (status in ('pending','verified','rejected')),
  imported     boolean not null default false,        -- old sheet rows (no screenshot)
  created_by   uuid references auth.users(id),
  created_at   timestamptz not null default now(),
  verified_by  uuid references auth.users(id),
  verified_at  timestamptz,
  constraint transfer_needs_screenshot check (imported or proof_path is not null)
);
create index if not exists transfers_agent on transfers(agent_code, date);

create table if not exists expenses (
  id        text primary key default ('e' || floor(extract(epoch from now())*1000)::text),
  branch    text not null default 'cloud' check (branch in ('cloud','puttur')),
  date      date not null,
  category  text not null,          -- Subscription, Bill payment, Salary, Rent …
  name      text not null,
  amount    numeric not null check (amount > 0),
  paid_by   text references accounts(code),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ---------- Payroll ----------------------------------------------------
create table if not exists payroll_items (
  id          uuid primary key default gen_random_uuid(),
  month       text not null,                       -- '2026-10'
  person_key  text not null,                       -- expert code / 'ISHFA' / staff id …
  kind        text not null check (kind in ('salary','extra')),
  label       text,
  amount      numeric not null,
  created_by  uuid references auth.users(id),
  created_at  timestamptz not null default now()
);
create table if not exists payroll_paid (
  month      text not null,
  person_key text not null,
  amount     numeric not null,
  paid_at    timestamptz not null default now(),
  paid_by    uuid references auth.users(id),
  primary key (month, person_key)
);
create table if not exists salary_statements (
  id        uuid primary key default gen_random_uuid(),
  month     text not null,
  person    text not null,
  amount    numeric not null,
  note      text
);

-- ---------- Puttur enquiries -----------------------------------------
create table if not exists enquiries (
  id         text primary key,
  cse_id     text references puttur_staff(id),
  name       text not null,
  phone      text not null,
  source     text,
  status     text not null default 'NEW',
  note       text,
  order_id   text references orders(id),
  created_at timestamptz not null default now()
);
create table if not exists enquiry_log (
  id          uuid primary key default gen_random_uuid(),
  enquiry_id  text references enquiries(id) on delete cascade,
  at          timestamptz not null default now(),
  by_user     uuid references auth.users(id),
  status      text,
  text        text
);

-- ---------- Customer issues (quality control) -------------------------
create table if not exists customer_issues (
  id           text primary key default ('iss' || floor(extract(epoch from now())*1000)::text),
  customer_key text not null,
  name         text,
  phone        text,
  type         text not null,
  status       text not null default 'open' check (status in ('open','resolved')),
  agents       text[] not null default '{}',
  cses         text[] not null default '{}',
  experts      text[] not null default '{}',
  order_ids    text[] not null default '{}',
  created_by   uuid references auth.users(id),
  created_at   timestamptz not null default now()
);
create table if not exists issue_log (
  id        uuid primary key default gen_random_uuid(),
  issue_id  text references customer_issues(id) on delete cascade,
  at        timestamptz not null default now(),
  by_user   uuid references auth.users(id),
  text      text not null
);
create table if not exists issue_seen (
  user_id  uuid references auth.users(id) on delete cascade primary key,
  seen_at  timestamptz not null default now()
);

-- ---------- Audit log (every change) ----------------------------------
create table if not exists activity_log (
  id         bigserial primary key,
  at         timestamptz not null default now(),
  user_id    uuid,
  table_name text not null,
  row_id     text,
  action     text not null,
  old_data   jsonb,
  new_data   jsonb
);

create or replace function log_change() returns trigger language plpgsql security definer as $$
begin
  insert into activity_log(user_id, table_name, row_id, action, old_data, new_data)
  values (auth.uid(), tg_table_name,
          coalesce((case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end)->>'id',
                   (case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end)->>'order_id'),
          tg_op,
          case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

do $$ declare t text; begin
  foreach t in array array['orders','order_experts','transfers','expenses','payroll_items','payroll_paid','ad_days','enquiries','customer_issues','profiles','expert_agents','expert_skills']
  loop
    execute format('drop trigger if exists trg_log_%1$s on %1$s; create trigger trg_log_%1$s after insert or update or delete on %1$s for each row execute function log_change();', t);
  end loop;
end $$;

-- ---------- Who am I? (helper functions) ------------------------------
create or replace function me() returns profiles language sql stable security definer as
$$ select * from profiles where id = auth.uid() and active $$;
create or replace function my_role()   returns app_role language sql stable security definer as $$ select role from profiles where id = auth.uid() and active $$;
create or replace function is_mgmt()   returns boolean language sql stable security definer as $$ select coalesce(my_role() = 'management', false) $$;
create or replace function is_head()   returns boolean language sql stable security definer as $$ select exists(select 1 from profiles where id = auth.uid() and role='ops' and ops_scope='head' and active) $$;
create or replace function is_ops()    returns boolean language sql stable security definer as $$ select coalesce(my_role() = 'ops', false) $$;
create or replace function is_pmgr()   returns boolean language sql stable security definer as $$ select coalesce(my_role() = 'manager', false) $$;
create or replace function my_agent()  returns text language sql stable security definer as $$ select agent_code from profiles where id = auth.uid() and role='sales' and active $$;
create or replace function my_expert() returns text language sql stable security definer as $$ select expert_code from profiles where id = auth.uid() and role='expert' and active $$;
create or replace function my_staff()  returns text language sql stable security definer as $$ select staff_id from profiles where id = auth.uid() and role='cse' and active $$;
create or replace function can_see_order(o orders) returns boolean language sql stable security definer as $$
  select is_mgmt() or is_ops()
      or (o.branch='puttur' and (is_pmgr() or o.cse_id = my_staff()))
      or (o.branch='cloud' and o.agent_code = my_agent())
      or (my_expert() is not null and (
            exists(select 1 from order_experts e where e.order_id=o.id and e.expert_code=my_expert())
         or (o.agent_code in (select agent_code from expert_agents where expert_code=my_expert())
             and not exists(select 1 from order_experts e where e.order_id=o.id))))
$$;

-- ---------- Guard rules the screen can't enforce ----------------------
create or replace function guard_orders() returns trigger language plpgsql security definer as $$
begin
  if tg_op='UPDATE' then
    if old.summary and not is_mgmt() then raise exception 'Sheet adjustment lines are read-only'; end if;
    if is_ops() and (new.status <> old.status or new.price <> old.price or new.paid <> old.paid or new.pay_status <> old.pay_status) then
      raise exception 'Operations can assign experts but cannot change order status or money';
    end if;
    if my_expert() is not null and (new.price <> old.price or new.paid <> old.paid or new.pay_status <> old.pay_status
        or new.agent_code is distinct from old.agent_code or new.name is distinct from old.name or new.phone is distinct from old.phone) then
      raise exception 'Experts can only update work status';
    end if;
    if my_agent() is not null and new.date <> old.date then raise exception 'Order date cannot be changed'; end if;
  end if;
  if tg_op='INSERT' then
    new.created_at := now();
    new.created_by := auth.uid();
    if my_agent() is not null or my_staff() is not null then new.date := current_date; end if;  -- date is the moment of entry
  end if;
  return new;
end $$;
drop trigger if exists trg_guard_orders on orders;
create trigger trg_guard_orders before insert or update on orders for each row execute function guard_orders();

create or replace function guard_transfers() returns trigger language plpgsql security definer as $$
begin
  if tg_op='INSERT' then
    new.created_by := auth.uid(); new.created_at := now();
    if is_mgmt() or is_head() then new.status := 'verified'; new.verified_by := auth.uid(); new.verified_at := now();
    else new.status := 'pending'; new.verified_by := null; new.verified_at := null; end if;
    if my_agent() is not null then new.agent_code := my_agent(); end if;
  end if;
  if tg_op='UPDATE' and new.status <> old.status then
    if not is_head() then raise exception 'Only the Head of operations can verify transfers'; end if;
    new.verified_by := auth.uid(); new.verified_at := now();
  end if;
  return new;
end $$;
drop trigger if exists trg_guard_transfers on transfers;
create trigger trg_guard_transfers before insert or update on transfers for each row execute function guard_transfers();

-- ---------- Row-level security ---------------------------------------
do $$ declare t text; begin
  foreach t in array array['profiles','agents','experts','expert_skills','expert_agents','puttur_staff','orders','order_experts','ad_days','accounts','transfers','expenses','payroll_items','payroll_paid','salary_statements','enquiries','enquiry_log','customer_issues','issue_log','issue_seen','activity_log']
  loop execute format('alter table %I enable row level security;', t); end loop;
end $$;

-- profiles
create policy p_self   on profiles for select using (id = auth.uid() or is_mgmt() or is_ops() or is_pmgr());
create policy p_mgmt   on profiles for all    using (is_mgmt()) with check (is_mgmt());
create policy p_ops_ex on profiles for all    using (is_ops() and role in ('expert','sales')) with check (is_ops() and role in ('expert','sales'));
create policy p_photo  on profiles for update using (id = auth.uid()) with check (id = auth.uid() and role = my_role());

-- reference data: everyone signed in can read
create policy r_agents  on agents        for select using (auth.uid() is not null);
create policy r_experts on experts       for select using (auth.uid() is not null);
create policy r_skills  on expert_skills for select using (auth.uid() is not null);
create policy r_map     on expert_agents for select using (auth.uid() is not null);
create policy r_accts   on accounts      for select using (is_mgmt() or is_head() or my_agent() is not null);
create policy w_agents  on agents        for all using (is_mgmt()) with check (is_mgmt());
create policy w_experts on experts       for all using (is_mgmt() or is_ops()) with check (is_mgmt() or is_ops());
create policy w_skills  on expert_skills for all using (is_mgmt() or is_ops()) with check (is_mgmt() or is_ops());
create policy w_map     on expert_agents for all using (is_mgmt() or is_ops()) with check (is_mgmt() or is_ops());
create policy w_accts   on accounts      for all using (is_mgmt()) with check (is_mgmt());
create policy r_staff   on puttur_staff  for select using (is_mgmt() or is_pmgr() or id = my_staff());
create policy w_staff   on puttur_staff  for all using (is_mgmt() or is_pmgr()) with check (is_mgmt() or is_pmgr());

-- orders
create policy o_read   on orders for select using (can_see_order(orders));
create policy o_insert on orders for insert with check (
  is_mgmt()
  or (branch='cloud'  and agent_code = my_agent())
  or (branch='puttur' and (cse_id = my_staff() or is_pmgr())));
create policy o_update on orders for update using (can_see_order(orders)) with check (can_see_order(orders));
create policy o_delete on orders for delete using (is_mgmt());

create policy oe_read  on order_experts for select using (exists(select 1 from orders o where o.id = order_id and can_see_order(o)));
create policy oe_write on order_experts for all using (is_mgmt() or is_ops()
    or exists(select 1 from orders o where o.id = order_id and (o.agent_code = my_agent() or o.cse_id = my_staff()))
    or expert_code = my_expert())
  with check (is_mgmt() or is_ops()
    or exists(select 1 from orders o where o.id = order_id and (o.agent_code = my_agent() or o.cse_id = my_staff()))
    or expert_code = my_expert());

-- ads (Ishfa has no ads access)
create policy a_read  on ad_days for select using (is_mgmt() or is_head() or agent_code = my_agent());
create policy a_write on ad_days for all using (is_mgmt() or is_head() or agent_code = my_agent()) with check (is_mgmt() or is_head() or agent_code = my_agent());

-- transfers
create policy t_read   on transfers for select using (is_mgmt() or is_head() or agent_code = my_agent());
create policy t_insert on transfers for insert with check (is_mgmt() or is_head() or agent_code = my_agent());
create policy t_verify on transfers for update using (is_mgmt() or is_head()) with check (is_mgmt() or is_head());
create policy t_delete on transfers for delete using (is_mgmt());

-- expenses
create policy e_cloud  on expenses for all using (branch='cloud'  and (is_mgmt() or is_head())) with check (branch='cloud'  and (is_mgmt() or is_head()));
create policy e_puttur on expenses for all using (branch='puttur' and (is_mgmt() or is_pmgr())) with check (branch='puttur' and (is_mgmt() or is_pmgr()));

-- payroll
create policy pr_items on payroll_items     for all using (is_mgmt() or is_head() or is_pmgr()) with check (is_mgmt() or is_head() or is_pmgr());
create policy pr_paid  on payroll_paid      for all using (is_mgmt() or is_head() or is_pmgr()) with check (is_mgmt() or is_head() or is_pmgr());
create policy pr_stmt  on salary_statements for all using (is_mgmt()) with check (is_mgmt());

-- Puttur enquiries
create policy q_rw  on enquiries   for all using (is_mgmt() or is_pmgr() or cse_id = my_staff()) with check (is_mgmt() or is_pmgr() or cse_id = my_staff());
create policy ql_rw on enquiry_log for all using (exists(select 1 from enquiries q where q.id = enquiry_id and (is_mgmt() or is_pmgr() or q.cse_id = my_staff())))
  with check (exists(select 1 from enquiries q where q.id = enquiry_id and (is_mgmt() or is_pmgr() or q.cse_id = my_staff())));

-- customer issues
create policy ci_read on customer_issues for select using (
  is_mgmt() or is_ops() or is_pmgr() or created_by = auth.uid()
  or my_agent() = any(agents) or my_expert() = any(experts) or my_staff() = any(cses));
create policy ci_new  on customer_issues for insert with check (auth.uid() is not null);
create policy ci_upd  on customer_issues for update using (
  is_mgmt() or is_ops() or is_pmgr() or created_by = auth.uid() or my_agent() = any(agents) or my_staff() = any(cses));
create policy il_read on issue_log for select using (exists(select 1 from customer_issues i where i.id = issue_id));
create policy il_new  on issue_log for insert with check (exists(select 1 from customer_issues i where i.id = issue_id) and by_user = auth.uid());
create policy is_self on issue_seen for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- audit log: management only
create policy log_read on activity_log for select using (is_mgmt());

-- ---------- Customer lookup across agents (quality control) -----------
-- Everyone signed in can find WHO owns a customer and the order status,
-- without seeing prices or other agents' full order lists.
create or replace function lookup_customer(q text)
returns table(order_id text, date date, name text, phone text, services text[], owner text, branch text, status text, pay_status text, urgent boolean, experts text)
language sql stable security definer as $$
  select o.id, o.date, o.name, o.phone, o.services,
         coalesce(o.agent_code, o.cse_id), o.branch, o.status, o.pay_status, o.urgent,
         (select string_agg(e.expert_code, ', ') from order_experts e where e.order_id = o.id)
  from orders o
  where auth.uid() is not null and not o.summary
    and ( (length(regexp_replace(q,'\D','','g')) >= 5 and regexp_replace(o.phone,'\D','','g') like '%' || regexp_replace(q,'\D','','g') || '%')
       or (length(regexp_replace(q,'\D','','g')) = 0 and length(q) >= 3 and o.name ilike '%' || q || '%') )
  order by o.date desc limit 100
$$;

-- ---------- File storage ---------------------------------------------
insert into storage.buckets (id, name, public) values ('proofs','proofs', false) on conflict do nothing;
insert into storage.buckets (id, name, public) values ('photos','photos', true)  on conflict do nothing;

create policy st_proof_up   on storage.objects for insert with check (bucket_id = 'proofs' and auth.uid() is not null);
create policy st_proof_read on storage.objects for select using (bucket_id = 'proofs' and (is_mgmt() or is_ops() or is_pmgr() or owner = auth.uid()));
create policy st_photo_up   on storage.objects for insert with check (bucket_id = 'photos' and auth.uid() is not null);
create policy st_photo_upd  on storage.objects for update using (bucket_id = 'photos' and (owner = auth.uid() or is_mgmt()));
create policy st_photo_read on storage.objects for select using (bucket_id = 'photos');

-- ---------- Live updates ---------------------------------------------
alter publication supabase_realtime add table orders, order_experts, transfers, customer_issues, issue_log, enquiries;

-- Done.
