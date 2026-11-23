-- Skilleaze HQ · verified transfers always reduce the agent's balance on every device (safe to run again)

-- 1. Transfers carry a "last changed" time so every device picks up a verification
alter table transfers add column if not exists updated_at timestamptz not null default now();
create index if not exists transfers_updated on transfers(updated_at);

-- 2. Keep the saved copy's status the same as the real status, and stamp the change time
create or replace function transfers_sync_status() returns trigger language plpgsql as $$
begin
  new.extra := jsonb_set(coalesce(new.extra, '{}'::jsonb), '{status}', to_jsonb(new.status), true);
  if new.verified_at is not null then new.extra := jsonb_set(new.extra, '{verifiedAt}', to_jsonb((extract(epoch from new.verified_at) * 1000)::bigint), true); end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_transfers_sync_status on transfers;
create trigger trg_transfers_sync_status before insert or update on transfers for each row execute function transfers_sync_status();

-- 3. Repair every existing transfer (past verifications that agents still saw as "pending")
update transfers set status = status;

-- 4. Check: verified transfers whose saved copy disagreed are now 0
select count(*) filter (where status = 'verified') as verified_transfers,
       count(*) filter (where coalesce(extra->>'status', 'verified') <> status) as still_mismatched
from transfers;
