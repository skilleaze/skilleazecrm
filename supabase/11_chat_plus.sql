-- Skilleaze HQ · Chat photos, voice messages and group photos (run once, after 09_chat.sql)

alter table chat_groups add column if not exists photo text;

alter table chat_messages drop constraint if exists chat_messages_body_check;
alter table chat_messages add constraint chat_messages_body_check check (length(body) between 1 and 4000);

insert into storage.buckets (id, name, public) values ('chat', 'chat', false) on conflict (id) do nothing;

drop policy if exists st_chat_up   on storage.objects;
drop policy if exists st_chat_read on storage.objects;
drop policy if exists st_chat_del  on storage.objects;
create policy st_chat_up   on storage.objects for insert with check (bucket_id = 'chat' and auth.uid() is not null and chat_is_member(split_part(name, '/', 1)));
create policy st_chat_read on storage.objects for select using (bucket_id = 'chat' and auth.uid() is not null and chat_can_read(split_part(name, '/', 1)));
create policy st_chat_del  on storage.objects for delete using (bucket_id = 'chat' and (owner = auth.uid() or is_mgmt()));

select 'ok' as chat_plus_ready;
