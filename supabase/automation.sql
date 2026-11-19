-- Stratt HQ · run after access.sql
-- When a deal is marked received, add the commission to Finance automatically.
create or replace function deal_received_to_transaction() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'received' and (tg_op = 'INSERT' or old.status is distinct from 'received')
     and not exists (select 1 from transactions where deal_id = new.id) then
    insert into transactions (month, direction, category, description, amount_aed, deal_id)
    values (date_trunc('month', coalesce(new.received_on, current_date))::date, 'in', 'commission', new.name, new.commission_aed, new.id);
  end if;
  return new;
end $$;

drop trigger if exists deal_received on deals;
create trigger deal_received after insert or update of status on deals
for each row execute function deal_received_to_transaction();
