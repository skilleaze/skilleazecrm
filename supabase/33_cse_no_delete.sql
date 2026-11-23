-- Skilleaze HQ · consultants can edit their own enquiries but never delete them. Safe to run again.
drop policy if exists enq_delete on enquiries;
create policy enq_delete on enquiries for delete using ((select is_mgmt()) or (select is_pmgr()));
select 'ok' as consultant_edit_no_delete;
