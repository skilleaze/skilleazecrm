-- Skilleaze HQ · fix the save errors in the Supabase logs (19–20 Nov). Safe to run again.
-- 1. "Experts can only update work status"   → an expert's save no longer fails; money/customer fields just keep the saved value
-- 2. orders row-level security on save        → Head of operations can add orders; a copy of an order that already exists saves as an update
-- 3. hr_records row-level security            → people whose saved person key no longer matches their login are corrected; LinkedIn manual counts can be re-saved
-- 4. order_experts errors                     → fixed in the app (only changed experts are saved, never before the order exists)

-- 1 + 2a · order guard: keep old values instead of rejecting the whole save
create or replace function guard_orders() returns trigger language plpgsql security definer set search_path = public as $fn$
declare ps text; pb text;
begin
  if tg_op = 'UPDATE' then
    if old.summary and not is_mgmt() then raise exception 'Sheet adjustment lines are read-only'; end if;
    if is_ops() and not is_head() then
      new.status := old.status; new.price := old.price; new.paid := old.paid; new.pay_status := old.pay_status;
    end if;
    if my_expert() is not null then
      new.price := old.price; new.paid := old.paid; new.pay_status := old.pay_status;
      new.agent_code := old.agent_code; new.name := old.name; new.phone := old.phone;
      new.extra := new.extra || jsonb_strip_nulls(jsonb_build_object(
        'price', old.extra->'price', 'paid', old.extra->'paid', 'pay', old.extra->'pay',
        'agent', old.extra->'agent', 'name', old.extra->'name', 'phone', old.extra->'phone'));
    end if;
    if not is_mgmt() and new.date <> old.date then new.date := old.date; end if;
    ps := new.extra->>'proofStatus'; pb := new.extra->>'balanceProofStatus';
    if not can_check_payments() and (
         (ps is distinct from (old.extra->>'proofStatus') and ps in ('confirmed', 'rejected', 'changes'))
      or (pb is distinct from (old.extra->>'balanceProofStatus') and pb in ('confirmed', 'rejected', 'changes'))) then
      raise exception 'Only management, operations or the Puttur manager can check payments';
    end if;
  end if;
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.created_by := auth.uid();
    if not is_mgmt() then new.date := (now() at time zone 'Asia/Kolkata')::date; end if;
  end if;
  return new;
end $fn$;
drop trigger if exists trg_guard_orders on orders;
create trigger trg_guard_orders before insert or update on orders for each row execute function guard_orders();

-- 2b · who may add an order
drop policy if exists o_insert on orders;
create policy o_insert on orders for insert with check (
  (select is_mgmt()) or (select is_head())
  or (branch = 'cloud'  and agent_code = (select my_agent()))
  or (branch = 'puttur' and (cse_id = (select my_staff()) or (select is_pmgr()))));

-- 3a · person key follows the login (role:id), only for your own role and id
create or replace function set_my_person_key(k text) returns void language sql security definer set search_path = public as $fn$
  update profiles p set person_key = k
  where p.id = auth.uid() and p.person_key is distinct from k
    and split_part(k, ':', 1) = p.role::text
    and (p.person_key is null
         or lower(substr(k, length(p.role::text) + 2)) in (lower(coalesce(p.agent_code, '')), lower(coalesce(p.expert_code, '')), lower(coalesce(p.staff_id, '')), lower(coalesce(p.full_name, '')), lower(coalesce(p.username, ''))))
$fn$;

-- 3b · LinkedIn manual counts: the expert can read and re-save their own
drop policy if exists hr_manual_read_own on hr_records;
create policy hr_manual_read_own on hr_records for select using (kind = 'manual' and person_key = (select my_pkey()));
drop policy if exists hr_manual_upd on hr_records;
create policy hr_manual_upd on hr_records for update
  using (kind = 'manual' and person_key = (select my_pkey()))
  with check (kind = 'manual' and person_key = (select my_pkey()));

-- CHECK · logins whose saved person key does not look like role:id (these were the hr_records errors)
select username, role, person_key,
       role::text || ':' || coalesce(agent_code, expert_code, staff_id, full_name) as expected
from profiles
where active and role::text in ('sales', 'expert', 'cse', 'ops', 'manager', 'management')
  and (person_key is null or split_part(person_key, ':', 1) <> role::text)
order by role, username;
