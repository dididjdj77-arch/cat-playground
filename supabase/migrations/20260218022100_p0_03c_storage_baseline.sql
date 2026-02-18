begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('assets', 'assets', false, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('assets-public', 'assets-public', true, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set name = excluded.name,
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists assets_owner_select on storage.objects;
create policy assets_owner_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'assets'
  and auth.uid() is not null
  and (storage.foldername(name))[1] in ('avatars', 'posts', 'cats')
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists assets_owner_insert on storage.objects;
create policy assets_owner_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'assets'
  and auth.uid() is not null
  and (storage.foldername(name))[1] in ('avatars', 'posts', 'cats')
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists assets_owner_update on storage.objects;
create policy assets_owner_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'assets'
  and auth.uid() is not null
  and (storage.foldername(name))[1] in ('avatars', 'posts', 'cats')
  and (storage.foldername(name))[2] = auth.uid()::text
)
with check (
  bucket_id = 'assets'
  and auth.uid() is not null
  and (storage.foldername(name))[1] in ('avatars', 'posts', 'cats')
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists assets_owner_delete on storage.objects;
create policy assets_owner_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'assets'
  and auth.uid() is not null
  and (storage.foldername(name))[1] in ('avatars', 'posts', 'cats')
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists assets_public_read on storage.objects;
create policy assets_public_read
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'assets-public'
  and (storage.foldername(name))[1] = 'posts'
);

drop policy if exists assets_public_service_insert on storage.objects;
create policy assets_public_service_insert
on storage.objects
for insert
to service_role
with check (
  bucket_id = 'assets-public'
  and (storage.foldername(name))[1] = 'posts'
);

drop policy if exists assets_public_service_update on storage.objects;
create policy assets_public_service_update
on storage.objects
for update
to service_role
using (
  bucket_id = 'assets-public'
  and (storage.foldername(name))[1] = 'posts'
)
with check (
  bucket_id = 'assets-public'
  and (storage.foldername(name))[1] = 'posts'
);

drop policy if exists assets_public_service_delete on storage.objects;
create policy assets_public_service_delete
on storage.objects
for delete
to service_role
using (
  bucket_id = 'assets-public'
  and (storage.foldername(name))[1] = 'posts'
);

commit;
