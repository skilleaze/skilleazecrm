-- Skilleaze HQ · make every new order save and reach experts (run once)

-- 1. Agents and experts created from Team & logins may not exist in the
--    lookup tables, so orders / assignments for them were rejected.
insert into agents (code, name)
select distinct upper(p.agent_code), coalesce(p.full_name, upper(p.agent_code))
from profiles p where p.role = 'sales' and p.agent_code is not null
on conflict (code) do nothing;

insert into experts (code, name)
select distinct upper(p.expert_code), coalesce(p.full_name, upper(p.expert_code))
from profiles p where p.role = 'expert' and p.expert_code is not null
on conflict (code) do nothing;

update profiles set agent_code = upper(agent_code) where role = 'sales' and agent_code is not null and agent_code <> upper(agent_code);
update profiles set expert_code = upper(expert_code) where role = 'expert' and expert_code is not null and expert_code <> upper(expert_code);

-- 2. From now on, create the lookup row automatically instead of rejecting the save.
create or replace function ensure_order_refs() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.agent_code is not null then insert into agents (code, name) values (new.agent_code, new.agent_code) on conflict (code) do nothing; end if;
  if new.cse_id is not null then insert into puttur_staff (id, name) values (new.cse_id, new.cse_id) on conflict (id) do nothing; end if;
  return new;
end $$;
drop trigger if exists trg_order_refs on orders;
create trigger trg_order_refs before insert or update on orders for each row execute function ensure_order_refs();

create or replace function ensure_expert_ref() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.expert_code is not null then insert into experts (code, name) values (new.expert_code, new.expert_code) on conflict (code) do nothing; end if;
  return new;
end $$;
drop trigger if exists trg_expert_ref on order_experts;
create trigger trg_expert_ref before insert or update on order_experts for each row execute function ensure_expert_ref();

drop trigger if exists trg_expert_map_ref on expert_agents;
create trigger trg_expert_map_ref before insert or update on expert_agents for each row execute function ensure_expert_ref();

-- 3. Check: sales logins whose agent has no CV expert linked (their orders can't be picked up)
select p.username, p.agent_code,
       (select count(*) from expert_agents ea where ea.agent_code = p.agent_code) as experts_linked
from profiles p where p.role = 'sales' and p.active
order by experts_linked, p.username;
