-- Skilleaze HQ · remove the Chat module completely (run once)
-- Deletes all chat messages, groups, photos and voice notes to free space.
-- Nothing else (orders, transfers, HR, logins, complaints) is touched.

-- 1. Stop live updates for chat
do $$ begin
  begin alter publication supabase_realtime drop table chat_messages; exception when others then null; end;
  begin alter publication supabase_realtime drop table chat_groups;   exception when others then null; end;
end $$;

-- 2. Storage rules for the chat folder
drop policy if exists st_chat_up   on storage.objects;
drop policy if exists st_chat_read on storage.objects;
drop policy if exists st_chat_del  on storage.objects;

-- 3. Chat tables (and everything attached to them)
drop table if exists chat_reads    cascade;
drop table if exists chat_reactions cascade;
drop table if exists chat_messages cascade;
drop table if exists chat_members  cascade;
drop table if exists chat_groups   cascade;

-- 4. Chat helper functions
drop function if exists chat_is_member(text) cascade;
drop function if exists chat_can_read(text)  cascade;
drop function if exists chat_touch()         cascade;

select 'ok' as chat_removed;

-- 5. Last step: delete the chat files (photos and voice notes)
--    Supabase does not allow deleting stored files with SQL.
--    Go to Storage → bucket "chat" → ⋯ → Empty bucket, then ⋯ → Delete bucket.
