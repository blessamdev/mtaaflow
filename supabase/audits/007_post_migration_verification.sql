-- MtaaFlow Migration 007 post-migration verification.
-- All statements are read-only. Compare service_role and unrelated grants
-- with the saved pre-migration output; this script does not mutate anything.

-- 1. Effective table-level privileges for anon/authenticated.
-- Expected anon: SELECT only on stores, categories, products, variants,
-- product_images, social links, and public-safe store_settings.
-- Expected authenticated: SELECT on all 12; CRUD on seller-managed tables;
-- UPDATE on profiles only; no client writes to customer/order tables.
WITH app_tables(table_name) AS (
  VALUES
    ('stores'), ('categories'), ('products'), ('product_variants'),
    ('product_images'), ('profiles'), ('customers'), ('orders'),
    ('order_items'), ('order_status_history'), ('store_social_links'),
    ('store_settings')
),
roles(role_name) AS (
  VALUES ('anon'), ('authenticated')
),
privileges(privilege_name) AS (
  VALUES
    ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
    ('TRUNCATE'), ('REFERENCES'), ('TRIGGER'), ('MAINTAIN')
),
expected(role_name, table_name, privilege_name) AS (
  VALUES
    ('anon', 'stores', 'SELECT'),
    ('anon', 'categories', 'SELECT'),
    ('anon', 'products', 'SELECT'),
    ('anon', 'product_variants', 'SELECT'),
    ('anon', 'product_images', 'SELECT'),
    ('anon', 'store_social_links', 'SELECT'),
    ('anon', 'store_settings', 'SELECT'),
    ('authenticated', 'profiles', 'SELECT'),
    ('authenticated', 'profiles', 'UPDATE'),
    ('authenticated', 'stores', 'SELECT'),
    ('authenticated', 'stores', 'INSERT'),
    ('authenticated', 'stores', 'UPDATE'),
    ('authenticated', 'stores', 'DELETE'),
    ('authenticated', 'categories', 'SELECT'),
    ('authenticated', 'products', 'SELECT'),
    ('authenticated', 'products', 'INSERT'),
    ('authenticated', 'products', 'UPDATE'),
    ('authenticated', 'products', 'DELETE'),
    ('authenticated', 'product_variants', 'SELECT'),
    ('authenticated', 'product_variants', 'INSERT'),
    ('authenticated', 'product_variants', 'UPDATE'),
    ('authenticated', 'product_variants', 'DELETE'),
    ('authenticated', 'product_images', 'SELECT'),
    ('authenticated', 'product_images', 'INSERT'),
    ('authenticated', 'product_images', 'UPDATE'),
    ('authenticated', 'product_images', 'DELETE'),
    ('authenticated', 'customers', 'SELECT'),
    ('authenticated', 'orders', 'SELECT'),
    ('authenticated', 'order_items', 'SELECT'),
    ('authenticated', 'order_status_history', 'SELECT'),
    ('authenticated', 'store_social_links', 'SELECT'),
    ('authenticated', 'store_social_links', 'INSERT'),
    ('authenticated', 'store_social_links', 'UPDATE'),
    ('authenticated', 'store_social_links', 'DELETE'),
    ('authenticated', 'store_settings', 'SELECT'),
    ('authenticated', 'store_settings', 'INSERT'),
    ('authenticated', 'store_settings', 'UPDATE'),
    ('authenticated', 'store_settings', 'DELETE')
)
SELECT
  r.role_name,
  t.table_name,
  p.privilege_name,
  (e.role_name IS NOT NULL) AS expected,
  has_table_privilege(
    r.role_name::name,
    format('public.%I', t.table_name),
    p.privilege_name
  ) AS effective,
  has_table_privilege(
    r.role_name::name,
    format('public.%I', t.table_name),
    p.privilege_name
  ) = (e.role_name IS NOT NULL) AS matches_expected
FROM roles r
CROSS JOIN app_tables t
CROSS JOIN privileges p
LEFT JOIN expected e
  ON e.role_name = r.role_name
 AND e.table_name = t.table_name
 AND e.privilege_name = p.privilege_name
ORDER BY r.role_name, t.table_name, p.privilege_name;

-- 2. service_role effective privileges.
-- Expected: unchanged from the saved pre-migration baseline.
SELECT
  t.table_name,
  p.privilege_name,
  has_table_privilege(
    'service_role',
    format('public.%I', t.table_name),
    p.privilege_name
  ) AS effective
FROM (VALUES
  ('stores'), ('categories'), ('products'), ('product_variants'),
  ('product_images'), ('profiles'), ('customers'), ('orders'),
  ('order_items'), ('order_status_history'), ('store_social_links'),
  ('store_settings')
) t(table_name)
CROSS JOIN (VALUES
  ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
  ('TRUNCATE'), ('REFERENCES'), ('TRIGGER'), ('MAINTAIN')
) p(privilege_name)
ORDER BY t.table_name, p.privilege_name;

-- 2a. Effective table privileges for all relevant roles.
-- Expected: anon/authenticated match the target matrix above; postgres and
-- service_role match their pre-migration rows exactly.
SELECT
  role_name,
  table_name,
  privilege_name,
  has_table_privilege(
    role_name::name,
    format('public.%I', table_name),
    privilege_name
  ) AS effective
FROM (VALUES
  ('anon'), ('authenticated'), ('postgres'), ('service_role')
) roles(role_name)
CROSS JOIN (VALUES
  ('stores'), ('categories'), ('products'), ('product_variants'),
  ('product_images'), ('profiles'), ('customers'), ('orders'),
  ('order_items'), ('order_status_history'), ('store_social_links'),
  ('store_settings')
) tables(table_name)
CROSS JOIN (VALUES
  ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
  ('TRUNCATE'), ('REFERENCES'), ('TRIGGER'), ('MAINTAIN')
) privileges(privilege_name)
ORDER BY role_name, table_name, privilege_name;

-- 3. Direct table ACL entries, including PUBLIC and service_role.
-- Expected: client grants match the intended model in query 1; service_role
-- and all unrelated entries match the saved baseline. No PUBLIC grants should
-- appear on the application tables.
SELECT
  c.relname AS table_name,
  pg_get_userbyid(c.relowner) AS object_owner,
  CASE WHEN acl.grantee = 0 THEN 'PUBLIC'
       ELSE grantee_role.rolname END AS grantee,
  pg_get_userbyid(acl.grantor) AS grantor,
  acl.privilege_type,
  acl.is_grantable
FROM pg_class c
CROSS JOIN LATERAL aclexplode(
  coalesce(c.relacl, acldefault('r', c.relowner))
) acl
LEFT JOIN pg_roles grantee_role ON grantee_role.oid = acl.grantee
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relname IN (
    'stores', 'categories', 'products', 'product_variants',
    'product_images', 'profiles', 'customers', 'orders',
    'order_items', 'order_status_history', 'store_social_links',
    'store_settings'
  )
  AND c.relkind IN ('r', 'p')
ORDER BY c.relname, grantee, acl.privilege_type;

-- 3b. Existing public-schema sequence and routine ACL snapshot.
-- Expected: identical row set to pre-migration query 8a. A difference means
-- an existing function/sequence ACL changed unexpectedly; stop and investigate.
SELECT
  object_type,
  schema_name,
  object_identity,
  object_owner,
  grantee,
  grantor,
  privilege_type,
  is_grantable
FROM (
  SELECT
    'function'::text AS object_type,
    n.nspname::text AS schema_name,
    format('%I.%I(%s)', n.nspname, p.proname,
      pg_get_function_identity_arguments(p.oid)) AS object_identity,
    pg_get_userbyid(p.proowner)::text AS object_owner,
    CASE WHEN acl.grantee = 0 THEN 'PUBLIC'
         ELSE grantee_role.rolname END::text AS grantee,
    pg_get_userbyid(acl.grantor)::text AS grantor,
    acl.privilege_type::text AS privilege_type,
    acl.is_grantable
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN LATERAL aclexplode(
    coalesce(p.proacl, acldefault('f', p.proowner))
  ) acl
  LEFT JOIN pg_roles grantee_role ON grantee_role.oid = acl.grantee
  WHERE n.nspname = 'public'

  UNION ALL

  SELECT
    'sequence'::text,
    n.nspname::text,
    format('%I.%I', n.nspname, c.relname),
    pg_get_userbyid(c.relowner)::text,
    CASE WHEN acl.grantee = 0 THEN 'PUBLIC'
         ELSE grantee_role.rolname END::text,
    pg_get_userbyid(acl.grantor)::text,
    acl.privilege_type::text,
    acl.is_grantable
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN LATERAL aclexplode(
    coalesce(c.relacl, acldefault('S', c.relowner))
  ) acl
  LEFT JOIN pg_roles grantee_role ON grantee_role.oid = acl.grantee
  WHERE n.nspname = 'public'
    AND c.relkind = 'S'
) acl_snapshot
ORDER BY object_type, schema_name, object_identity, grantee, privilege_type;

-- 3c. Effective sequence and function privileges for the same roles.
-- Expected: identical to pre-migration query 8b. In particular, verify the
-- reviewed handle_new_user() access has not changed.
SELECT
  role_name,
  object_type,
  object_identity,
  privilege_name,
  effective
FROM (
  SELECT
    roles.role_name,
    'function'::text AS object_type,
    format('%I.%I(%s)', n.nspname, p.proname,
      pg_get_function_identity_arguments(p.oid)) AS object_identity,
    'EXECUTE'::text AS privilege_name,
    has_function_privilege(roles.role_name::name, p.oid, 'EXECUTE') AS effective
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN (VALUES
    ('anon'), ('authenticated'), ('postgres'), ('service_role')
  ) roles(role_name)
  WHERE n.nspname = 'public'

  UNION ALL

  SELECT
    roles.role_name,
    'sequence'::text,
    format('%I.%I', n.nspname, c.relname),
    privileges.privilege_name,
    has_sequence_privilege(
      roles.role_name::name, c.oid, privileges.privilege_name
    )
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN (VALUES
    ('anon'), ('authenticated'), ('postgres'), ('service_role')
  ) roles(role_name)
  CROSS JOIN (VALUES ('SELECT'), ('UPDATE'), ('USAGE')) privileges(privilege_name)
  WHERE n.nspname = 'public'
    AND c.relkind = 'S'
) effective_acl
ORDER BY role_name, object_type, object_identity, privilege_name;

-- 3d. Existing effective client access to public routines and sequences.
-- Expected: function rows match pre-migration query 8c; rows explained by
-- PUBLIC EXECUTE are retained under Option A. Sequence access remains absent.
-- Compare with query 3b to identify any direct client grants; this migration
-- does not alter existing routine or sequence ACLs.
SELECT
  role_name,
  object_type,
  object_identity,
  privilege_name,
  effective
FROM (
  SELECT
    roles.role_name,
    'function'::text AS object_type,
    format('%I.%I(%s)', n.nspname, p.proname,
      pg_get_function_identity_arguments(p.oid)) AS object_identity,
    'EXECUTE'::text AS privilege_name,
    has_function_privilege(roles.role_name::name, p.oid, 'EXECUTE') AS effective
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN (VALUES ('anon'), ('authenticated')) roles(role_name)
  WHERE n.nspname = 'public'

  UNION ALL

  SELECT
    roles.role_name,
    'sequence'::text,
    format('%I.%I', n.nspname, c.relname),
    privileges.privilege_name,
    has_sequence_privilege(
      roles.role_name::name, c.oid, privileges.privilege_name
    )
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN (VALUES ('anon'), ('authenticated')) roles(role_name)
  CROSS JOIN (VALUES ('SELECT'), ('UPDATE'), ('USAGE')) privileges(privilege_name)
  WHERE n.nspname = 'public'
    AND c.relkind = 'S'
) effective_client_acl
WHERE effective
ORDER BY role_name, object_type, object_identity, privilege_name;

-- 3a. PUBLIC table-level grants on the application tables.
-- Expected: zero rows.
SELECT
  c.relname AS table_name,
  acl.privilege_type,
  acl.is_grantable
FROM pg_class c
CROSS JOIN LATERAL aclexplode(
  coalesce(c.relacl, acldefault('r', c.relowner))
) acl
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relname IN (
    'stores', 'categories', 'products', 'product_variants',
    'product_images', 'profiles', 'customers', 'orders',
    'order_items', 'order_status_history', 'store_social_links',
    'store_settings'
  )
  AND c.relkind IN ('r', 'p')
  AND acl.grantee = 0
ORDER BY c.relname, acl.privilege_type;

-- 4. Column-level ACL entries.
-- Expected: no anon/authenticated column grants remain. Compare service_role
-- and unrelated grants to the baseline.
SELECT
  a.attrelid::regclass AS table_name,
  a.attname AS column_name,
  CASE WHEN acl.grantee = 0 THEN 'PUBLIC'
       ELSE grantee_role.rolname END AS grantee,
  pg_get_userbyid(acl.grantor) AS grantor,
  acl.privilege_type,
  acl.is_grantable
FROM pg_attribute a
CROSS JOIN LATERAL aclexplode(a.attacl) acl
LEFT JOIN pg_roles grantee_role ON grantee_role.oid = acl.grantee
WHERE a.attrelid IN (
  SELECT c.oid
  FROM pg_class c
  WHERE c.relnamespace = 'public'::regnamespace
    AND c.relname IN (
      'stores', 'categories', 'products', 'product_variants',
      'product_images', 'profiles', 'customers', 'orders',
      'order_items', 'order_status_history', 'store_social_links',
      'store_settings'
    )
)
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND a.attacl IS NOT NULL
ORDER BY table_name::text, column_name, grantee, acl.privilege_type;

-- 4a. Unexpected PUBLIC or client column-level grants.
-- Expected: zero rows.
SELECT
  a.attrelid::regclass AS table_name,
  a.attname AS column_name,
  CASE WHEN acl.grantee = 0 THEN 'PUBLIC'
       ELSE grantee_role.rolname END AS grantee,
  acl.privilege_type
FROM pg_attribute a
CROSS JOIN LATERAL aclexplode(a.attacl) acl
LEFT JOIN pg_roles grantee_role ON grantee_role.oid = acl.grantee
WHERE a.attrelid IN (
  SELECT c.oid
  FROM pg_class c
  WHERE c.relnamespace = 'public'::regnamespace
    AND c.relname IN (
      'stores', 'categories', 'products', 'product_variants',
      'product_images', 'profiles', 'customers', 'orders',
      'order_items', 'order_status_history', 'store_social_links',
      'store_settings'
    )
)
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND acl.grantee IN (
    0,
    (SELECT oid FROM pg_roles WHERE rolname = 'anon'),
    (SELECT oid FROM pg_roles WHERE rolname = 'authenticated')
  )
ORDER BY table_name::text, column_name, grantee, acl.privilege_type;

-- 5. RLS status.
-- Expected: all 12 tables still have RLS enabled. FORCE status is unchanged.
SELECT
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relname IN (
    'stores', 'categories', 'products', 'product_variants',
    'product_images', 'profiles', 'customers', 'orders',
    'order_items', 'order_status_history', 'store_social_links',
    'store_settings'
  )
  AND c.relkind IN ('r', 'p')
ORDER BY c.relname;

-- 5a. RLS-disabled application tables.
-- Expected: zero rows.
SELECT c.relname AS table_name
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relname IN (
    'stores', 'categories', 'products', 'product_variants',
    'product_images', 'profiles', 'customers', 'orders',
    'order_items', 'order_status_history', 'store_social_links',
    'store_settings'
  )
  AND c.relkind IN ('r', 'p')
  AND NOT c.relrowsecurity
ORDER BY c.relname;

-- 6. Complete policy inventory.
-- Expected: all 22 policies and expressions match the pre-migration inventory.
-- Both public-read and owner-management policies for store_settings remain
-- unchanged. No policies are added or removed.
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'stores', 'categories', 'products', 'product_variants',
    'product_images', 'profiles', 'customers', 'orders',
    'order_items', 'order_status_history', 'store_social_links',
    'store_settings'
  )
ORDER BY tablename, policyname;

-- 6a. Policy inventory count and store_settings policy postcondition.
-- Expected: 22 total policies, two settings policies, public SELECT to both
-- anon and authenticated with its original published-store predicate, and
-- owner ALL to authenticated with its original USING/WITH CHECK expressions.
SELECT
  (SELECT count(*) FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename IN (
       'stores', 'categories', 'products', 'product_variants',
       'product_images', 'profiles', 'customers', 'orders',
       'order_items', 'order_status_history', 'store_social_links',
       'store_settings'
     )) AS total_policy_count,
  (SELECT count(*) FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'store_settings')
    AS store_settings_policy_count,
  (SELECT count(*) FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'store_settings'
     AND policyname = 'Public can view published store settings'
     AND permissive = 'PERMISSIVE'
     AND roles = ARRAY['anon', 'authenticated']::name[]
     AND cmd = 'SELECT'
     AND qual = '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.is_published = true))))'
     AND with_check IS NULL) AS expected_public_settings_policy_count,
  (SELECT count(*) FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'store_settings'
     AND policyname = 'Owners can manage store settings'
     AND permissive = 'PERMISSIVE'
     AND roles = ARRAY['authenticated']::name[]
     AND cmd = 'ALL'
     AND qual = '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'
     AND with_check = '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))')
    AS expected_owner_settings_policy_count;

-- 6b. Store-settings column inventory.
-- Expected: identical row set and types to pre-migration query 4b. If any
-- columns changed, reassess whether table-wide client SELECT remains safe.
SELECT
  a.attname AS column_name,
  format_type(a.atttypid, a.atttypmod) AS data_type,
  a.attnotnull AS not_null
FROM pg_attribute a
WHERE a.attrelid = 'public.store_settings'::regclass
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY a.attnum;

-- 7. Default ACL entries for postgres/public and unchanged scopes.
-- Expected: no anon/authenticated defaults for postgres/public tables,
-- sequences or functions. postgres/storage and service_role entries should
-- match the pre-migration result. No supabase_admin defaults are modified.
-- The built-in PUBLIC EXECUTE default is not necessarily a pg_default_acl
-- row. This migration intentionally preserves it (Option A) pending approval.
SELECT
  pg_get_userbyid(d.defaclrole) AS object_creator,
  CASE WHEN d.defaclnamespace = 0 THEN 'GLOBAL'
       ELSE n.nspname END AS schema_scope,
  CASE d.defaclobjtype
    WHEN 'r' THEN 'tables'
    WHEN 'S' THEN 'sequences'
    WHEN 'f' THEN 'functions'
    ELSE d.defaclobjtype::text
  END AS object_type,
  CASE WHEN acl.grantee = 0 THEN 'PUBLIC'
       ELSE grantee_role.rolname END AS grantee,
  pg_get_userbyid(acl.grantor) AS grantor,
  acl.privilege_type,
  acl.is_grantable
FROM pg_default_acl d
LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
LEFT JOIN pg_roles grantee_role ON grantee_role.oid = acl.grantee
WHERE d.defaclobjtype IN ('r', 'S', 'f')
  AND (d.defaclnamespace = 0 OR n.nspname IN ('public', 'storage'))
ORDER BY object_creator, schema_scope, object_type, grantee, acl.privilege_type;

-- 7a. Explicit client default-ACL failure check for postgres/public.
-- Expected: zero rows.
SELECT
  pg_get_userbyid(d.defaclrole) AS object_creator,
  n.nspname AS schema_name,
  d.defaclobjtype AS object_type,
  grantee_role.rolname AS grantee,
  acl.privilege_type
FROM pg_default_acl d
JOIN pg_namespace n ON n.oid = d.defaclnamespace
CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
JOIN pg_roles grantee_role ON grantee_role.oid = acl.grantee
WHERE d.defaclrole = (SELECT oid FROM pg_roles WHERE rolname = 'postgres')
  AND n.nspname = 'public'
  AND d.defaclobjtype IN ('r', 'S', 'f')
  AND grantee_role.rolname IN ('anon', 'authenticated')
ORDER BY d.defaclobjtype, grantee_role.rolname, acl.privilege_type;

-- 7b. PUBLIC default ACLs.
-- Expected: exactly the same rows as the pre-migration audit. The migration
-- intentionally preserves PUBLIC ACLs rather than revoking them.
SELECT
  pg_get_userbyid(d.defaclrole) AS object_creator,
  CASE WHEN d.defaclnamespace = 0 THEN 'GLOBAL'
       ELSE n.nspname END AS schema_scope,
  d.defaclobjtype AS object_type,
  acl.privilege_type,
  acl.is_grantable
FROM pg_default_acl d
LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
WHERE acl.grantee = 0
  AND d.defaclobjtype IN ('r', 'S', 'f')
  AND (
    d.defaclnamespace = 0
    OR (d.defaclrole = (SELECT oid FROM pg_roles WHERE rolname = 'postgres')
        AND n.nspname = 'public')
  )
ORDER BY object_creator, schema_scope, object_type, acl.privilege_type;

-- 8. Client membership paths.
-- Expected: zero rows. The migration does not alter role memberships.
WITH client_roles AS (
  SELECT oid, rolname
  FROM pg_roles
  WHERE rolname IN ('anon', 'authenticated')
)
SELECT
  client.rolname AS client_role,
  target.rolname AS reachable_role,
  pg_has_role(client.oid, target.oid, 'USAGE') AS inherits_privileges,
  pg_has_role(client.oid, target.oid, 'SET') AS can_set_role
FROM client_roles client
CROSS JOIN pg_roles target
WHERE target.oid <> client.oid
  AND (
    pg_has_role(client.oid, target.oid, 'USAGE')
    OR pg_has_role(client.oid, target.oid, 'SET')
  )
ORDER BY client.rolname, target.rolname;

-- 9. Anonymous storefront smoke test.
-- Expected: queries run; rows returned are filtered by existing anon RLS
-- policies. Categories may be empty if none exist. Do not infer publication
-- coverage from an empty result.
BEGIN;
SET LOCAL ROLE anon;

SELECT id, slug, is_published
FROM public.stores
ORDER BY created_at DESC
LIMIT 20;

SELECT id, store_id, name, is_active
FROM public.products
ORDER BY created_at DESC
LIMIT 20;

SELECT id, product_id, store_id
FROM public.product_variants
ORDER BY created_at DESC
LIMIT 20;

SELECT id, product_id, storage_path
FROM public.product_images
ORDER BY created_at DESC
LIMIT 20;

SELECT id, store_id, platform, is_visible
FROM public.store_social_links
ORDER BY created_at DESC
LIMIT 20;

SELECT
  id, store_id, currency, language, theme_color, announcement,
  show_contact_info, allow_guest_checkout, created_at, updated_at
FROM public.store_settings
ORDER BY store_id
LIMIT 20;

SELECT id, name, slug
FROM public.categories
ORDER BY name
LIMIT 20;

SELECT
  has_table_privilege('anon', 'public.store_settings', 'SELECT')
    AS anon_can_select_store_settings,
  has_table_privilege('authenticated', 'public.store_settings', 'SELECT')
    AS authenticated_can_select_store_settings,
  has_table_privilege('anon', 'public.customers', 'SELECT')
    AS anon_can_select_customers,
  has_table_privilege('anon', 'public.orders', 'SELECT')
    AS anon_can_select_orders;

-- Negative visibility probes. Expected: zero for unpublished stores,
-- inactive products, and hidden social links. Run with known fixtures; an
-- empty database cannot demonstrate the positive cases.
SELECT count(*) AS visible_unpublished_stores
FROM public.stores
WHERE is_published = false;

SELECT count(*) AS visible_inactive_products
FROM public.products
WHERE is_active = false;

SELECT count(*) AS visible_hidden_social_links
FROM public.store_social_links
WHERE is_visible = false;

SELECT count(*) AS visible_unpublished_store_settings
FROM public.store_settings ss
JOIN public.stores s ON s.id = ss.store_id
WHERE s.is_published = false;

ROLLBACK;

-- Signed-in shopper storefront check. Use a valid authenticated account that
-- does not own every store. Expected: published stores and settings are
-- visible; the unpublished-settings count is zero.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '<SHOPPER_AUTH_USER_UUID>',
  true
);
SELECT s.id, s.slug, ss.currency, ss.language, ss.theme_color, ss.announcement,
       ss.show_contact_info, ss.allow_guest_checkout
FROM public.stores s
JOIN public.store_settings ss ON ss.store_id = s.id
WHERE s.is_published = true
ORDER BY s.slug;
SELECT count(*) AS visible_unpublished_store_settings
FROM public.store_settings ss
JOIN public.stores s ON s.id = ss.store_id
WHERE s.is_published = false;
ROLLBACK;

-- Optional seller-owned row visibility test. Replace the placeholder with a
-- real auth.users UUID before running; use a test account and do not write data.
-- Expected: own rows may appear; rows belonging to other sellers must not.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '<SELLER_AUTH_USER_UUID>',
  true
);
SELECT auth.uid() AS test_seller_id;
SELECT id, full_name FROM public.profiles WHERE id = auth.uid();
SELECT id, name, slug FROM public.stores WHERE owner_id = auth.uid();
SELECT id, name, store_id FROM public.products
WHERE store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid());
SELECT id, product_id, store_id FROM public.product_variants
WHERE store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid());
SELECT id, product_id, storage_path FROM public.product_images
WHERE product_id IN (
  SELECT p.id FROM public.products p
  JOIN public.stores s ON s.id = p.store_id WHERE s.owner_id = auth.uid()
);
SELECT id, store_id, platform FROM public.store_social_links
WHERE store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid());
SELECT id, store_id, allow_guest_checkout FROM public.store_settings
WHERE store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid());
SELECT id, store_id FROM public.customers
WHERE store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid());
SELECT id, store_id, order_ref FROM public.orders
WHERE store_id IN (SELECT id FROM public.stores WHERE owner_id = auth.uid());
SELECT id, order_id, product_name FROM public.order_items
WHERE order_id IN (
  SELECT o.id FROM public.orders o
  JOIN public.stores s ON s.id = o.store_id WHERE s.owner_id = auth.uid()
);
SELECT id, order_id, status FROM public.order_status_history
WHERE order_id IN (
  SELECT o.id FROM public.orders o
  JOIN public.stores s ON s.id = o.store_id WHERE s.owner_id = auth.uid()
);
ROLLBACK;
