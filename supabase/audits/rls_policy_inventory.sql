select
  tablename,
  policyname,
  cmd as operation
from pg_policies
where schemaname = 'public'
order by tablename, policyname;