-- Skilleaze CRM · faster sign-in (run once in SQL Editor → New query → Run)
-- Adds a "last changed" time to each table so the CRM only downloads what changed.

do $$ declare t text; begin
  foreach t in array array['orders','ad_days','transfers','expenses','customer_issues']
  loop
    execute format('alter table %I add column if not exists updated_at timestamptz not null default now();', t);
    execute format('create index if not exists %1$s_updated_at on %1$s(updated_at);', t);
  end loop;
end $$;

create or replace function touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

do $$ declare t text; begin
  foreach t in array array['orders','ad_days','transfers','expenses','customer_issues','app_kv']
  loop
    execute format('drop trigger if exists trg_touch_%1$s on %1$s; create trigger trg_touch_%1$s before insert or update on %1$s for each row execute function touch_updated_at();', t);
  end loop;
end $$;

-- order_experts changes should also mark the order as changed
create or replace function touch_order_from_expert() returns trigger language plpgsql security definer as $$
begin
  update orders set updated_at = now() where id = coalesce(new.order_id, old.order_id);
  return coalesce(new, old);
end $$;
drop trigger if exists trg_touch_order_expert on order_experts;
create trigger trg_touch_order_expert after insert or update or delete on order_experts for each row execute function touch_order_from_expert();

select 'ok' as done;
