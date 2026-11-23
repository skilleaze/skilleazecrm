-- Skilleaze HQ · LinkedIn experts can record orders they got themselves (count only). Safe to run again.
do $$ declare c text; d text; begin
  select conname, pg_get_constraintdef(oid) into c, d from pg_constraint where conrelid = 'hr_records'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%kind%' limit 1;
  if c is not null and d not ilike '%''manual''%' then
    execute format('alter table hr_records drop constraint %I', c);
    execute format('alter table hr_records add constraint %I %s', c, regexp_replace(d, '\]\)', ', ''manual''::text])'));
  end if; end $$;

drop policy if exists hr_manual_ins on hr_records;
drop policy if exists hr_manual_del on hr_records;
drop policy if exists hr_manual_read on hr_records;
create policy hr_manual_ins on hr_records for insert with check (kind = 'manual' and person_key = (select my_pkey()) and (select my_expert()) is not null);
create policy hr_manual_del on hr_records for delete using (kind = 'manual' and (person_key = (select my_pkey()) or (select is_mgmt()) or (select is_ops())));
create policy hr_manual_read on hr_records for select using (kind = 'manual' and ((select is_mgmt()) or (select is_ops())));

select pg_get_constraintdef(oid) as kinds_allowed from pg_constraint where conrelid = 'hr_records'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%kind%';
