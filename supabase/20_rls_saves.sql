-- Skilleaze HQ · fix "row-level security" save errors (run once, safe to run again)

-- 1. HR punches / leave / profile: always keep each login's HR key up to date
create or replace function set_my_person_key(k text) returns void language sql security definer set search_path = public as $$
  update profiles set person_key = k where id = auth.uid() and k is not null and k <> '' and person_key is distinct from k
$$;
grant execute on function set_my_person_key(text) to authenticated;

-- fill missing keys from each profile (sales:ALPHA, expert:NAME, cse:STAFFID)
update profiles set person_key = 'sales:' || agent_code where role = 'sales' and agent_code is not null and (person_key is null or person_key = '');
update profiles set person_key = 'expert:' || expert_code where role = 'expert' and expert_code is not null and (person_key is null or person_key = '');
update profiles set person_key = 'cse:' || staff_id where role = 'cse' and staff_id is not null and (person_key is null or person_key = '');

-- 2. Orders: retrying a save of the same order must not fail
-- (handled in the app: saves now use upsert)

select role, count(*) total, count(person_key) with_hr_key from profiles where active group by role order by role;
