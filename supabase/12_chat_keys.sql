-- Skilleaze HQ · fix chat photo & voice uploads for direct chats
-- Storage folder names use "," instead of "|" (Supabase does not allow "|" in file names).
drop policy if exists st_chat_up   on storage.objects;
drop policy if exists st_chat_read on storage.objects;
drop policy if exists st_chat_del  on storage.objects;
create policy st_chat_up   on storage.objects for insert with check (bucket_id = 'chat' and auth.uid() is not null and chat_is_member(replace(split_part(name, '/', 1), ',', '|')));
create policy st_chat_read on storage.objects for select using (bucket_id = 'chat' and auth.uid() is not null and chat_can_read(replace(split_part(name, '/', 1), ',', '|')));
create policy st_chat_del  on storage.objects for delete using (bucket_id = 'chat' and (owner = auth.uid() or is_mgmt()));
select 'ok' as chat_keys_ready;
