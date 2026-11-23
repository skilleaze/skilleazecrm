-- Skilleaze HQ · saving the same expert link twice no longer fails (old app copies included). Safe to run again.
create or replace function oe_replace_dupe() returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from order_experts where order_id = new.order_id and service_type = new.service_type;
  return new;
end $$;
drop trigger if exists trg_oe_replace_dupe on order_experts;
create trigger trg_oe_replace_dupe before insert on order_experts for each row execute function oe_replace_dupe();

create or replace function orders_insert_as_update() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from orders where id = new.id) then return null; end if;
  return new;
end $$;
drop trigger if exists trg_orders_insert_as_update on orders;
create trigger trg_orders_insert_as_update before insert on orders for each row execute function orders_insert_as_update();

select 'ok' as no_dupes_ready;
