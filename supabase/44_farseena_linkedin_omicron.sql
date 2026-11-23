-- Skilleaze HQ · Khadeejath Farseena: LinkedIn expert for Agent OMICRON. Keeps all her other works and links. Safe to run again.
alter table app_kv disable trigger trg_kv_guard;

-- 1. Works: keep what she has, add LinkedIn (CV stays)
insert into app_kv (key, value, updated_at) values ('expertSkills', '{}'::jsonb, now()) on conflict (key) do nothing;
update app_kv set value = jsonb_set(coalesce(value, '{}'::jsonb), '{KHADEEJATH FARSEENA}',
  (select to_jsonb(array(select distinct x from unnest(
     coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(value->'KHADEEJATH FARSEENA') = 'array' then value->'KHADEEJATH FARSEENA' else '["cv"]'::jsonb end)), '{}') || array['linkedin']) x)))),
  updated_at = now()
where key = 'expertSkills';

-- 2. Link her to OMICRON in the app's expert map (keeps her other agents)
insert into app_kv (key, value, updated_at) values ('expertAgents', '{}'::jsonb, now()) on conflict (key) do nothing;
update app_kv set value = jsonb_set(coalesce(value, '{}'::jsonb), '{KHADEEJATH FARSEENA}',
  (select to_jsonb(array(select distinct x from unnest(
     coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(value->'KHADEEJATH FARSEENA') = 'array' then value->'KHADEEJATH FARSEENA' else '[]'::jsonb end)), '{}') || array['OMICRON']) x)))),
  updated_at = now()
where key = 'expertAgents';

alter table app_kv enable trigger trg_kv_guard;

-- 3. Same link in the database tables the dashboards and saves use
insert into experts (code, name) values ('KHADEEJATH FARSEENA', 'KHADEEJATH FARSEENA') on conflict (code) do nothing;
insert into expert_skills (expert_code, skill)
select 'KHADEEJATH FARSEENA', s from unnest(array['cv', 'linkedin']) s
where not exists (select 1 from expert_skills where expert_code = 'KHADEEJATH FARSEENA' and skill = s);
insert into expert_agents (expert_code, agent_code)
select 'KHADEEJATH FARSEENA', 'OMICRON'
where not exists (select 1 from expert_agents where expert_code = 'KHADEEJATH FARSEENA' and agent_code = 'OMICRON');

-- 4. Check
select (select value->'KHADEEJATH FARSEENA' from app_kv where key = 'expertSkills') as works,
       (select value->'KHADEEJATH FARSEENA' from app_kv where key = 'expertAgents') as agents_in_app,
       (select string_agg(agent_code, ', ') from expert_agents where expert_code = 'KHADEEJATH FARSEENA') as agents_in_db,
       (select string_agg(username || case when active then '' else ' (inactive)' end, ', ') from profiles where expert_code = 'KHADEEJATH FARSEENA') as login;
