
select
  policyname,
  cmd as operation,
  qual as using_expression,
  with_check as check_expression
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname in (
    'Owners can upload product images',
    'Owners can update product images',
    'Owners can delete product images',
    'Public can view product images'
  )
order by policyname;
