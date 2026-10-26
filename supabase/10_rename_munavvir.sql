-- Rename Munavvir's login: mohammed.munavvir → muhammed.munavvir
update auth.users set email = 'muhammed.munavvir@skilleaze.com' where email = 'mohammed.munavvir@skilleaze.com';
update auth.identities set identity_data = jsonb_set(identity_data, '{email}', '"muhammed.munavvir@skilleaze.com"'), provider_id = coalesce((select id::text from auth.users where email = 'muhammed.munavvir@skilleaze.com'), provider_id)
  where provider = 'email' and identity_data->>'email' = 'mohammed.munavvir@skilleaze.com';
update profiles set username = 'muhammed.munavvir' where username = 'mohammed.munavvir';
select username, role, (select email from auth.users u where u.id = p.id) as email from profiles p where username like '%munavvir%';
