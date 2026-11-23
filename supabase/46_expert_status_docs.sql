-- Skilleaze HQ · experts: Share draft / Submit always save; order documents open for the assigned expert. Safe to run again.

-- 1. Status guard: when the app changes the status but sends the old task-status map (single-service orders),
--    the map follows the new status instead of pulling the status back.
create or replace function sync_tst_with_status() returns trigger language plpgsql security definer set search_path = public as $fn$
declare n int;
begin
  if new.status is distinct from old.status
     and jsonb_typeof(new.extra->'tst') = 'object'
     and (new.extra->'tst') = coalesce(old.extra->'tst', 'null'::jsonb) then
    select count(*) into n from jsonb_object_keys(new.extra->'tst');
    if n <= 1 then
      new.extra := jsonb_set(new.extra, '{tst}', (select coalesce(jsonb_object_agg(k, to_jsonb(new.status)), '{}'::jsonb) from jsonb_object_keys(new.extra->'tst') k));
    end if;
  end if;
  return new;
end $fn$;
drop trigger if exists trg_a_sync_tst on orders;
create trigger trg_a_sync_tst before update on orders for each row execute function sync_tst_with_status();
-- (runs before trg_keep_status_forward: triggers fire in name order)

-- 2. Order documents: anyone who may open the order may open its files (incl. LinkedIn / Portfolio experts on combined orders)
create or replace function can_open_order_doc(oid text) returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from orders o where o.id = oid and (
       is_mgmt() or is_ops() or is_pmgr()
    or (o.branch = 'cloud' and o.agent_code = my_agent())
    or (o.branch = 'puttur' and o.cse_id = my_staff())
    or (my_expert() is not null and (
         upper(coalesce(o.extra->>'expert', '')) = upper(my_expert())
      or exists (select 1 from order_experts e where e.order_id = o.id and upper(e.expert_code) = upper(my_expert()))
      or exists (select 1 from jsonb_each_text(case when jsonb_typeof(o.extra->'wx') = 'object' then o.extra->'wx' else '{}'::jsonb end) x where upper(x.value) = upper(my_expert()))))))
$fn$;
drop policy if exists st_orderdocs_read on storage.objects;
create policy st_orderdocs_read on storage.objects for select using (
  bucket_id = 'proofs' and split_part(name, '/', 1) = 'orderdocs' and can_open_order_doc(split_part(name, '/', 2)));

-- 3. Repair: single-service orders whose saved task map disagrees with the status the expert last set
alter table orders disable trigger trg_guard_orders;
update orders o set extra = jsonb_set(o.extra, '{tst}', (select jsonb_object_agg(k, to_jsonb(o.status)) from jsonb_object_keys(o.extra->'tst') k)), updated_at = now()
where jsonb_typeof(o.extra->'tst') = 'object'
  and (select count(*) from jsonb_object_keys(o.extra->'tst')) = 1
  and (select v from jsonb_each_text(o.extra->'tst') e(k, v) limit 1) is distinct from o.status
  and o.status <> 'CLOSED';
alter table orders enable trigger trg_guard_orders;

select 'expert status + documents ready' as ok;
