select
  tablename,
  policyname,
  cmd as operation,
  qual as using_expression,
  with_check as check_expression
from pg_policies
where schemaname = 'public'
order by tablename, policyname;