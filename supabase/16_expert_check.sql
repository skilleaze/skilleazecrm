-- Skilleaze HQ · check that assigned orders reach the expert (run in SQL Editor)

-- 1. Every expert login is linked to its expert name
select p.username, p.expert_code, p.active,
       (select count(*) from order_experts e where e.expert_code = p.expert_code) as orders_assigned
from profiles p where p.role = 'expert' order by p.username;

-- 2. Expert logins with no expert name (these see nothing) — should be empty
select username, full_name from profiles where role = 'expert' and (expert_code is null or expert_code = '');

-- 3. Fix: link any expert login whose name was missing
update profiles set expert_code = upper(full_name)
where role = 'expert' and (expert_code is null or expert_code = '');

-- 4. Last 20 orders with their assigned experts
select o.id, o.date, o.agent_code, o.extra->>'name' as customer, o.status,
       string_agg(e.service_type || ': ' || e.expert_code, ', ') as experts
from orders o left join order_experts e on e.order_id = o.id
where o.date >= current_date - 2
group by o.id order by o.created_at desc limit 20;
