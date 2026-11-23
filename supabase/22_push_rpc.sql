create or replace function push_claim(p_endpoint text, p_p256dh text, p_auth text, p_ua text) returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into push_subs (endpoint, user_id, username, p256dh, auth, ua)
  values (p_endpoint, auth.uid(), my_username(), p_p256dh, p_auth, p_ua)
  on conflict (endpoint) do update set user_id = auth.uid(), username = my_username(), p256dh = excluded.p256dh, auth = excluded.auth, ua = excluded.ua;
end $$;
grant execute on function push_claim(text, text, text, text) to authenticated;
select 'ok' as push_claim_ready;
