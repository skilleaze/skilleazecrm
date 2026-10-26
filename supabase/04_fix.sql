-- Skilleaze CRM · fix 04 (run once)
-- Lets Puttur customer support save enquiries, and lets everyone mark customer issues as read.
drop policy if exists kv_write on app_kv;
create policy kv_write on app_kv for all
  using (is_mgmt() or is_ops() or is_pmgr()
         or (key = 'puttur' and my_staff() is not null)
         or (key = 'issueSeen' and auth.uid() is not null))
  with check (is_mgmt() or is_ops() or is_pmgr()
         or (key = 'puttur' and my_staff() is not null)
         or (key = 'issueSeen' and auth.uid() is not null));

-- Photos bucket (safe to run again)
insert into storage.buckets (id, name, public) values ('photos','photos', true) on conflict do nothing;

select 'ok' as done;
