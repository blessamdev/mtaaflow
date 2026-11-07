-- MtaaFlow Migration 007 preflight checks.
-- All statements are read-only. Review every result before applying the
-- migration; these queries do not change permissions or policies.

-- 1. Confirm PostgreSQL version and the SQL Editor execution identity.
-- Expected: PostgreSQL 17.x; current_user and session_user are postgres.
SELECT
  version() AS postgres_version,
  current_setting('server_version_num') AS server_version_num,
  current_user,
  session_user,
  r.rolsuper,
  r.rolbypassrls
FROM pg_roles r
WHERE r.rolname = current_user;

-- 2. Confirm ownership and RLS state of all 12 application tables.
-- Expected: all rows exist, owner is postgres, and RLS is enabled.
SELECT
  c.relname AS table_name,
  pg_get_userbyid(c.relowner) AS table_owner,
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

-- 3. Complete live policy inventory, including full expressions.
-- Expected: the reviewed 22 policies from migrations 001-004; no additional
-- policies on these 12 tables. Compare each expression to its migration
-- definition and the live baseline before applying.
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

-- 4. Focused store_settings policy check.
-- Expected before migration: exactly these two policies; public-read roles
-- are {anon,authenticated}; owner policy is ALL to authenticated. The public
-- published-store predicate is retained for anonymous visitors and shoppers.
SELECT
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'store_settings'
ORDER BY policyname;

-- 4a. Policy inventory count and store_settings policy precondition.
-- Expected: 22 total policies across these 12 tables; exactly two settings
-- policies; public settings policy is SELECT to {anon,authenticated} with the
-- published-store predicate; owner policy is ALL to authenticated. The
-- migration checks every policy's full expressions against this live baseline.
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

-- 4b. Store-settings column inventory.
-- Expected: exactly these public-safe configuration fields, identifiers, and
-- timestamps. Any extra/missing field must be reviewed before table SELECT is
-- granted to API roles. This output is repeated in the postflight audit.
SELECT
  a.attname AS column_name,
  format_type(a.atttypid, a.atttypmod) AS data_type,
  a.attnotnull AS not_null
FROM pg_attribute a
WHERE a.attrelid = 'public.store_settings'::regclass
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY a.attnum;

-- 5. Existing table ACL entries, including PUBLIC and grantors.
-- Expected: broad direct anon/authenticated entries are present as reported.
-- Review any PUBLIC entries carefully; the migration aborts if these exist.
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

-- 5a. Effective table privileges for all relevant roles.
-- Expected before migration: anon/authenticated show the audited excessive
-- grants. Record the postgres/service_role rows so post-migration access can
-- be compared; do not infer direct grants from effective results alone.
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

-- 6. Column-level ACL entries.
-- Expected: review all entries. Column ACLs are separate from table ACLs and
-- are explicitly revoked for anon/authenticated by the proposed migration.
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
    AND c.relkind IN ('r', 'p')
)
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND a.attacl IS NOT NULL
ORDER BY table_name::text, column_name, grantee, acl.privilege_type;

-- 7. Effective membership paths for client roles.
-- Expected: no memberships that allow anon/authenticated to inherit privileges
-- or SET ROLE to another role. This includes indirect membership paths.
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

-- 8. Global and schema-specific default ACLs for tables, sequences, functions.
-- Expected: no relevant global defaults; postgres/public has client-role
-- entries; postgres/storage and service_role entries are captured unchanged.
-- Note: the built-in PUBLIC EXECUTE default for new routines is not necessarily
-- represented as a pg_default_acl row. It is intentionally preserved by the
-- canonical migration unless Option B is separately approved.
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

-- 8a. Existing public-schema sequence and routine ACL snapshot.
-- Expected before migration: the reviewed baseline, including the reported
-- handle_new_user() EXECUTE ACL. Save this result and compare it row-for-row
-- with the identically shaped post-migration snapshot.
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

-- 8b. Effective sequence and function privileges for the same roles.
-- Expected before migration: save and compare with post-migration. Existing
-- function/sequence ACLs are not changed by migration 007.
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

-- 8c. Existing effective client access to public routines and sequences.
-- Expected: function rows may be effective through PostgreSQL's preserved
-- PUBLIC EXECUTE default; compare them with the PUBLIC entries in query 8a.
-- Sequence access is expected to be absent based on the supplied audit.
-- Investigate any client function access not explained by PUBLIC, and any
-- sequence access. Query 8a exposes direct grantees for comparison.
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

-- 9. Role membership entries involving the migration role or API roles.
-- Expected: the supplied postgres memberships are unchanged; no membership
-- changes are part of this migration.
SELECT
  granted.rolname AS granted_role,
  member.rolname AS member_role,
  m.admin_option,
  m.inherit_option,
  m.set_option,
  pg_get_userbyid(m.grantor) AS grantor
FROM pg_auth_members m
JOIN pg_roles granted ON granted.oid = m.roleid
JOIN pg_roles member ON member.oid = m.member
WHERE member.rolname IN ('postgres', 'anon', 'authenticated')
   OR granted.rolname IN ('anon', 'authenticated', 'service_role')
ORDER BY member_role, granted_role;

-- 10. Read-only storefront and seller-owner smoke tests.
-- Expected: anon sees only published stores, active products, variants and
-- images linked to those products, visible social links, and public
-- categories. Use a known seller UUID for the authenticated owner test.
BEGIN;
SET LOCAL ROLE anon;
SELECT id, slug, is_published FROM public.stores ORDER BY slug;
SELECT id, store_id, name, is_active FROM public.products ORDER BY name;
SELECT id, product_id, store_id FROM public.product_variants ORDER BY id;
SELECT id, product_id, storage_path FROM public.product_images ORDER BY sort_order;
SELECT id, store_id, platform, is_visible
FROM public.store_social_links ORDER BY store_id, platform;
SELECT id, name, slug FROM public.categories ORDER BY name;
SELECT
  id, store_id, currency, language, theme_color, announcement,
  show_contact_info, allow_guest_checkout, created_at, updated_at
FROM public.store_settings
ORDER BY store_id;
SELECT
  has_table_privilege('anon', 'public.store_settings', 'SELECT')
    AS anon_can_select_store_settings,
  has_table_privilege('authenticated', 'public.store_settings', 'SELECT')
    AS authenticated_can_select_store_settings,
  has_table_privilege('anon', 'public.customers', 'SELECT')
    AS anon_can_select_customers,
  has_table_privilege('anon', 'public.orders', 'SELECT')
    AS anon_can_select_orders;
SELECT count(*) AS visible_unpublished_store_settings
FROM public.store_settings ss
JOIN public.stores s ON s.id = ss.store_id
WHERE s.is_published = false;
ROLLBACK;

-- Optional signed-in shopper storefront check. Use a valid authenticated
-- account that does not own every store. Expected: published stores and their
-- settings are visible; unpublished settings are not.
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
