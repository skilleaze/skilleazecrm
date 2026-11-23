-- Skilleaze HQ · make logins and permissions stay fixed (safe to run again)

-- 1. Permission checks: give them back now, and re-apply every hour automatically
do $$ declare r record; begin
  for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prokind = 'f' loop
    execute format('grant execute on function %s to authenticated, anon', r.sig);
  end loop; end $$;
grant usage on schema public to authenticated, anon;

create or replace function skz_regrant() returns void language plpgsql security definer set search_path = public as $$
declare r record; begin
  for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prokind = 'f' loop
    execute format('grant execute on function %s to authenticated, anon', r.sig);
  end loop; end $$;

create extension if not exists pg_cron;
do $$ begin perform cron.unschedule('skz-regrant'); exception when others then null; end $$;
select cron.schedule('skz-regrant', '0 * * * *', 'select public.skz_regrant()');

-- 2. Logins: the sign-in email must be exactly username@skilleaze.com
--    (a mismatch makes "username or password incorrect" even right after a reset)
select p.username, p.role, u.email as sign_in_email, p.username || '@skilleaze.com' as should_be
from profiles p join auth.users u on u.id = p.id
where lower(u.email) <> lower(p.username || '@skilleaze.com');

update auth.users u set email = lower(p.username || '@skilleaze.com'), email_confirmed_at = coalesce(u.email_confirmed_at, now())
from profiles p
where p.id = u.id and lower(u.email) <> lower(p.username || '@skilleaze.com')
  and not exists (select 1 from auth.users x where lower(x.email) = lower(p.username || '@skilleaze.com') and x.id <> u.id);

update auth.identities i set identity_data = jsonb_set(coalesce(i.identity_data, '{}'::jsonb), '{email}', to_jsonb(lower(p.username || '@skilleaze.com')))
from profiles p
where i.user_id = p.id and i.provider = 'email';

-- 3. Active people must never be blocked; unconfirmed emails are confirmed
update auth.users u set banned_until = null from profiles p where p.id = u.id and p.active and u.banned_until is not null;
update auth.users set email_confirmed_at = now() where email_confirmed_at is null;

-- 4. Report: every expert and agent login, ready to sign in
select p.username, p.role, p.active, u.email, u.banned_until, u.last_sign_in_at
from profiles p join auth.users u on u.id = p.id
where p.role in ('expert', 'sales', 'cse')
order by p.role, p.username;
