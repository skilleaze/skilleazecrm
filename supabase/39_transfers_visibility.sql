-- 39 · Head of operations sees every agent's transfer, live
-- Safe to run again.

-- 1. Live updates: make sure transfers (and the other synced tables) send change signals
do $$
declare t text;
begin
  foreach t in array array['transfers','orders','ad_days','expenses','customer_issues','app_kv','order_experts'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- 2. Read access: management + head of operations see all transfers, agents see their own
drop policy if exists t_read on transfers;
create policy t_read on transfers for select
  using ((select is_mgmt()) or (select is_head()) or agent_code = (select my_agent()));

-- 3. Every change stamps updated_at so other devices pick it up
create or replace function transfers_touch() returns trigger language plpgsql as $fn$
begin new.updated_at := now(); return new; end
$fn$;
drop trigger if exists trg_transfers_touch on transfers;
create trigger trg_transfers_touch before insert or update on transfers for each row execute function transfers_touch();

-- 4. Check: who is Head of operations on the server
select p.username, p.role, p.ops_scope, p.active from profiles p where p.role = 'ops' order by 1;

-- 5. Check: every transfer from 2 Nov, per agent
select agent_code, status, count(*) as transfers, sum(amount) as amount, max(created_at) as last_added
from transfers where date >= '2026-11-02'
group by 1, 2 order by 1, 2;
