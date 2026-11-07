
-- MTAAFLOW: SECURITY AUDIT 001
-- Inspect RLS status and policies

select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  p.policyname,
  p.permissive,
  p.roles,
  p.cmd as operation,
  p.qual as using_expression,
  p.with_check as check_expression
from pg_class c
join pg_namespace n
  on n.oid = c.relnamespace
left join pg_policies p
  on p.schemaname = n.nspname
  and p.tablename = c.relname
where n.nspname = 'public'
  and c.relkind = 'r'
order by c.relname, p.policyname;
