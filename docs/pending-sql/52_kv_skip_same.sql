-- 52 · app_kv: ignore saves that do not change the value (safe to run twice)
-- Why (health check 25 Nov 09:25 IST): a stale app tab (ishfa, build from before 24 Nov 21:25) re-uploads the
-- ~0.9 MB app_kv.puttur every ~4 s. 348 of 356 uploads in 3 h were byte-for-byte the same value, yet each one
-- bumped updated_at (so every open app downloaded it again, and realtime woke the stale tab for the next round)
-- and wrote two full copies into activity_log (activity_log is now ~7 GB of a 7.2 GB database).
-- Fix: a BEFORE UPDATE trigger that runs last (name sorts after trg_kv_guard / trg_puttur_ads_keep /
-- trg_touch_app_kv) and skips the row update when the final value equals the stored one. Nothing is refused:
-- the save still returns OK, the stored value is already the same, there is just no new row version, no audit
-- copy and no realtime event. Real changes are saved and logged exactly as before.

create or replace function public.kv_skip_same()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if new.key = old.key and new.value is not distinct from old.value then
    return null;
  end if;
  return new;
end $fn$;

revoke all on function public.kv_skip_same() from public, anon, authenticated;

drop trigger if exists trg_zz_kv_skip_same on public.app_kv;
create trigger trg_zz_kv_skip_same before update on public.app_kv
  for each row execute function public.kv_skip_same();
