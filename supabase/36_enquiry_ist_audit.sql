-- 36_enquiry_ist_audit.sql · 16 Nov 2026 · READ ONLY: changes nothing.
-- Lists Puttur enquiries whose IST creation date differs from the date the old CRM showed (createdAt + 5:30 counted twice).
-- Affected = created between 18:30 and 23:59 IST. No data fix is needed: the CRM now works the date out from created time in IST.
with e as (
  select id, extra->>'name' as name, extra->>'by' as consultant, (extra->>'createdAt')::bigint as ms
  from enquiries where coalesce((extra->>'deleted')::boolean, false) = false and extra ? 'createdAt'
)
select consultant, id, name,
       to_timestamp(ms / 1000.0) at time zone 'Asia/Kolkata' as created_ist,
       (to_timestamp(ms / 1000.0) at time zone 'Asia/Kolkata')::date as correct_day,
       ((to_timestamp(ms / 1000.0) at time zone 'Asia/Kolkata') + interval '5 hours 30 minutes')::date as old_shown_day
from e
where ((to_timestamp(ms / 1000.0) at time zone 'Asia/Kolkata') + interval '5 hours 30 minutes')::date
      <> (to_timestamp(ms / 1000.0) at time zone 'Asia/Kolkata')::date
order by ms;
