create or replace function claim_order(p_id text, p_type text default 'cv') returns text
language plpgsql security definer set search_path = public as $$
declare me text := my_expert(); cur text;
begin
  if me is null then raise exception 'Only experts can pick up orders'; end if;
  perform 1 from orders where id = p_id for update;
  if not found then raise exception 'Order not found'; end if;
  if not exists (select 1 from orders o where o.id = p_id and (o.agent_code = any(my_expert_agents()) or ('P:' || coalesce(o.cse_id, '')) = any(my_expert_agents()))) then
    raise exception 'This order is not from one of your agents';
  end if;
  select expert_code into cur from order_experts where order_id = p_id and service_type = p_type;
  if coalesce(cur, '') = '' then
    select nullif(coalesce(extra->'wx'->>p_type, case when p_type = 'cv' then extra->>'expert' end), '') into cur from orders where id = p_id;
  end if;
  if coalesce(cur, '') <> '' then return cur; end if;
  insert into order_experts (order_id, service_type, expert_code) values (p_id, p_type, me)
    on conflict (order_id, service_type) do nothing;
  select expert_code into cur from order_experts where order_id = p_id and service_type = p_type;
  return cur;
end $$;
grant execute on function claim_order(text, text) to authenticated;
select 'ok' as claim_lock_ready;
