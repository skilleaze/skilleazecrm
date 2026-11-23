-- Skilleaze HQ · add CV expert Saudath Haseena (linked to Agent Beta)
-- Login: saudath.haseena  ·  first-time password: Sxeps-9127#

-- 1. Login
do $$ declare uid uuid; begin
  select id into uid from auth.users where email = 'saudath.haseena@skilleaze.com';
  if uid is null then
    uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', 'saudath.haseena@skilleaze.com',
      crypt('Sxeps-9127#', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid, uid::text, jsonb_build_object('sub', uid::text, 'email', 'saudath.haseena@skilleaze.com', 'email_verified', true), 'email', now(), now(), now());
  end if;
  insert into profiles (id, username, full_name, role, expert_code, title, must_change_pw, active)
  values (uid, 'saudath.haseena', 'Saudath Haseena', 'expert', 'SAUDATH HASEENA', 'CV expert', true, true)
  on conflict (id) do update set role = 'expert', expert_code = 'SAUDATH HASEENA', active = true;
end $$;

-- 2. Expert, skill and agent link
insert into experts (code, name) values ('SAUDATH HASEENA', 'Saudath Haseena') on conflict (code) do nothing;
insert into expert_skills (expert_code, skill) values ('SAUDATH HASEENA', 'cv') on conflict do nothing;
insert into expert_agents (expert_code, agent_code) values ('SAUDATH HASEENA', 'BETA') on conflict do nothing;

-- 3. CRM lists (expert list + who she works for)
update app_kv set value = value || '[["SAUDATH HASEENA","cv"]]'::jsonb, updated_at = now()
  where key = 'experts' and jsonb_typeof(value) = 'array' and not value @> '[["SAUDATH HASEENA","cv"]]'::jsonb;
insert into app_kv (key, value, updated_at) values ('expertAgents', '{"SAUDATH HASEENA":["BETA"]}'::jsonb, now())
  on conflict (key) do update set value = app_kv.value || '{"SAUDATH HASEENA":["BETA"]}'::jsonb, updated_at = now();

-- 4. Move Beta's "Souda Haseena" orders to her
update order_experts set expert_code = 'SAUDATH HASEENA' where expert_code = 'SOUDA HASEENA';
update orders set extra = jsonb_set(extra, '{expert}', '"SAUDATH HASEENA"'), created_at = created_at
  where extra->>'expert' = 'SOUDA HASEENA';

select (select count(*) from profiles where username = 'saudath.haseena') as login,
       (select count(*) from order_experts where expert_code = 'SAUDATH HASEENA') as orders_assigned,
       'ok' as done;
