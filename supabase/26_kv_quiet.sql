-- Skilleaze HQ · stop old app copies flooding the logs, without letting anyone change shared settings (safe to run again)

-- Who may really change a shared setting (same rules as before)
create or replace function kv_may_write(k text) returns boolean language sql stable security definer set search_path = public as $$
  select is_mgmt() or is_ops() or is_pmgr()
      or (k = 'puttur' and my_staff() is not null)
      or (k = 'issueSeen' and auth.uid() is not null)
      or (k = 'inv_' || auth.uid()::text)
$$;

-- Not allowed → the save is quietly ignored (nothing changes) instead of an error that old app copies retry forever
create or replace function kv_guard() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if kv_may_write(new.key) then return new; end if;
  return null;
end $$;
drop trigger if exists trg_kv_guard on app_kv;
create trigger trg_kv_guard before insert or update on app_kv for each row execute function kv_guard();

drop policy if exists kv_write on app_kv;
drop policy if exists kv_ins on app_kv;
drop policy if exists kv_upd on app_kv;
drop policy if exists kv_del on app_kv;
create policy kv_ins on app_kv for insert with check (auth.uid() is not null);
create policy kv_upd on app_kv for update using (auth.uid() is not null) with check (auth.uid() is not null);
create policy kv_del on app_kv for delete using (kv_may_write(key));

select 'ok' as kv_quiet_ready;
