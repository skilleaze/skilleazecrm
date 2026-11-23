create or replace function touch_login(changed boolean default false) returns void language sql security definer set search_path = public as $$
  update profiles set last_login = now(), must_change_pw = case when changed then false else must_change_pw end where id = auth.uid()
$$;
create or replace function clear_my_pw_flag() returns void language sql security definer set search_path = public as $$
  update profiles set must_change_pw = false where id = auth.uid()
$$;
grant execute on function touch_login(boolean) to authenticated;
grant execute on function clear_my_pw_flag() to authenticated;

-- Eta already set her own password: stop asking her
update profiles set must_change_pw = false where username = 'eta';

select username, role, must_change_pw, last_login from profiles where username in ('eta') or (must_change_pw and active) order by must_change_pw desc, username limit 60;
