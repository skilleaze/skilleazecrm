-- Skilleaze HQ · Chat (run once in SQL Editor)

create table if not exists chat_groups (
  id          text primary key,
  name        text not null default '',
  branch      text not null default 'cloud' check (branch in ('cloud','puttur')),
  kind        text not null default 'group' check (kind in ('group','dm')),
  auto        text,                                   -- cloud-all / cloud-sales / cloud-experts / puttur-all
  members     text[] not null default '{}',           -- usernames added by hand (or the 2 people of a direct chat)
  removed     text[] not null default '{}',           -- usernames taken out of an automatic group
  archived    boolean not null default false,
  created_by  uuid references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists chat_messages (
  id          text primary key,
  group_id    text not null references chat_groups(id) on delete cascade,
  sender      text not null,                          -- username
  body        text not null check (length(body) between 1 and 4000),
  created_by  uuid references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now()
);
create index if not exists chat_messages_group_time on chat_messages(group_id, created_at);
create index if not exists chat_messages_time on chat_messages(created_at);

create or replace function my_username() returns text language sql stable security definer set search_path = public as
$$ select username from profiles where id = auth.uid() and active $$;

create or replace function chat_auto_ok(a text) returns boolean language sql stable security definer set search_path = public as $$
  select case a
    when 'cloud-all'     then my_role()::text in ('sales','expert','ops','management')
    when 'cloud-sales'   then my_role()::text in ('sales','ops','management')
    when 'cloud-experts' then my_role()::text in ('expert','ops','management')
    when 'puttur-all'    then my_role()::text in ('manager','cse','ops','management')
    else false end
$$;

-- member = can read and write
create or replace function chat_is_member(gid text) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from chat_groups g where g.id = gid and not g.archived and (
    my_username() = any(g.members)
    or (g.kind = 'group' and g.auto is not null and chat_auto_ok(g.auto) and not (coalesce(my_username(),'') = any(g.removed)))))
$$;
-- management can also read every chat (incl. direct chats)
create or replace function chat_can_read(gid text) returns boolean language sql stable security definer set search_path = public as $$
  select is_mgmt() or chat_is_member(gid)
$$;

alter table chat_groups   enable row level security;
alter table chat_messages enable row level security;

drop policy if exists cg_read on chat_groups;
drop policy if exists cg_new  on chat_groups;
drop policy if exists cg_edit on chat_groups;
drop policy if exists cm_read on chat_messages;
drop policy if exists cm_new  on chat_messages;
drop policy if exists cm_del  on chat_messages;

create policy cg_read on chat_groups for select using (is_mgmt() or chat_is_member(id));
create policy cg_new  on chat_groups for insert with check (is_mgmt() or (kind = 'dm' and my_username() = any(members) and cardinality(members) = 2));
create policy cg_edit on chat_groups for update using (is_mgmt()) with check (is_mgmt());

create policy cm_read on chat_messages for select using (chat_can_read(group_id));
create policy cm_new  on chat_messages for insert with check (sender = my_username() and chat_is_member(group_id));
create policy cm_del  on chat_messages for delete using (is_mgmt() or created_by = auth.uid());

insert into chat_groups (id, name, branch, kind, auto) values
  ('g-cloud-official', 'Skilleaze Cloud Official', 'cloud',  'group', 'cloud-all'),
  ('g-cloud-sales',    'Skilleaze Sales',          'cloud',  'group', 'cloud-sales'),
  ('g-cloud-experts',  'Skilleaze Experts',        'cloud',  'group', 'cloud-experts'),
  ('g-puttur-all',     'Skilleaze Puttur',         'puttur', 'group', 'puttur-all')
on conflict (id) do nothing;

do $$ begin
  alter publication supabase_realtime add table chat_messages;
exception when others then null; end $$;

select 'ok' as chat_ready;
