
-- MTAAFLOW: MIGRATION 005
-- Secure product image storage

-- Public visitors can view product images
create policy "Public can view product images"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'product-images'
);

-- Store owners can upload images
-- Path format: store_id/product_id/image-name.webp
create policy "Owners can upload product images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[1]
      and s.owner_id = (select auth.uid())
  )
);

-- Store owners can update their images
create policy "Owners can update product images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[1]
      and s.owner_id = (select auth.uid())
  )
)
with check (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[1]
      and s.owner_id = (select auth.uid())
  )
);

-- Store owners can delete their images
create policy "Owners can delete product images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'product-images'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[1]
      and s.owner_id = (select auth.uid())
  )
);
