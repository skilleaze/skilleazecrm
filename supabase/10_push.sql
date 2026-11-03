-- Skilleaze HQ · Push notifications (run once in SQL Editor, after 09_chat.sql)

create table if not exists push_subs (
  endpoint   text primary key,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  username   text not null,
  p256dh     text not null,
  auth       text not null,
  ua         text,
  created_at timestamptz not null default now(),
  last_ok    timestamptz
);
create index if not exists push_subs_user on push_subs(username);

alter table push_subs enable row level security;
drop policy if exists ps_own on push_subs;
create policy ps_own on push_subs for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and username = my_username());

-- live updates for complaints (chat_messages was added in 09_chat.sql)
do $$ begin alter publication supabase_realtime add table customer_issues; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table chat_messages;   exception when others then null; end $$;

select 'ok' as push_ready;
