-- MtaaFlow migration 007: least-privilege application table permissions.
--
-- This migration is intentionally fail-closed and single-run. It verifies
-- the reviewed RLS inventory and ownership before changing grants. It does
-- not modify Storage, role memberships, service_role ACLs, existing functions,
-- triggers, or existing sequences.
--
-- Function defaults: explicit default EXECUTE grants to anon/authenticated are
-- revoked, but PostgreSQL's built-in PUBLIC EXECUTE default is preserved.
-- Option B is deliberately NOT applied. If separately approved, its exact
-- command is:
-- ALTER DEFAULT PRIVILEGES FOR ROLE postgres
--   REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
-- PostgreSQL cannot make that built-in revoke schema-specific; it affects
-- future postgres-created routines in every schema, not just public.
--
-- The current store_settings columns contain storefront configuration only:
-- currency, language, theme_color, announcement, show_contact_info, and
-- allow_guest_checkout, plus identifiers and timestamps. Its published-store
-- SELECT policy remains available to both anon and authenticated.

BEGIN;

DO $preflight$
DECLARE
  v_public oid := 'public'::regnamespace;
  v_anon oid;
  v_authenticated oid;
  v_service_role oid;
  v_postgres oid;
  v_current oid;
  v_actual_count integer;
  v_expected_count integer := 22;
  v_policy_mismatch boolean;
  v_role_name text;
  v_other_role record;
BEGIN
  SELECT oid INTO v_anon FROM pg_roles WHERE rolname = 'anon';
  SELECT oid INTO v_authenticated FROM pg_roles WHERE rolname = 'authenticated';
  SELECT oid INTO v_service_role FROM pg_roles WHERE rolname = 'service_role';
  SELECT oid INTO v_postgres FROM pg_roles WHERE rolname = 'postgres';
  SELECT oid INTO v_current FROM pg_roles WHERE rolname = current_user;

  IF current_user <> 'postgres'
     OR session_user <> 'postgres'
     OR v_current IS DISTINCT FROM v_postgres THEN
    RAISE EXCEPTION
      'Migration 007 must run with current_user and session_user both postgres';
  END IF;

  IF v_anon IS NULL OR v_authenticated IS NULL
     OR v_service_role IS NULL OR v_postgres IS NULL THEN
    RAISE EXCEPTION 'One or more required Supabase roles are missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (VALUES
      ('stores'), ('categories'), ('products'), ('product_variants'),
      ('product_images'), ('profiles'), ('customers'), ('orders'),
      ('order_items'), ('order_status_history'), ('store_social_links'),
      ('store_settings')
    ) AS expected(table_name)
    LEFT JOIN pg_class c
      ON c.relnamespace = v_public
     AND c.relname = expected.table_name
     AND c.relkind IN ('r', 'p')
    WHERE c.oid IS NULL
       OR c.relowner <> v_postgres
       OR NOT c.relrowsecurity
  ) THEN
    RAISE EXCEPTION
      'Expected application table missing, not owned by postgres, or RLS disabled';
  END IF;

  -- The complete current store_settings row is public-safe storefront
  -- configuration. Fail closed if its column set changes; reassess any new
  -- field before maintaining table-level SELECT for client roles.
  IF EXISTS (
    (
      SELECT column_name
      FROM (VALUES
        ('id'), ('store_id'), ('currency'), ('language'), ('theme_color'),
        ('announcement'), ('show_contact_info'), ('allow_guest_checkout'),
        ('created_at'), ('updated_at')
      ) AS expected(column_name)
      EXCEPT
      SELECT a.attname::text
      FROM pg_attribute a
      WHERE a.attrelid = 'public.store_settings'::regclass
        AND a.attnum > 0
        AND NOT a.attisdropped
    )
    UNION ALL
    (
      SELECT a.attname::text
      FROM pg_attribute a
      WHERE a.attrelid = 'public.store_settings'::regclass
        AND a.attnum > 0
        AND NOT a.attisdropped
      EXCEPT
      SELECT column_name
      FROM (VALUES
        ('id'), ('store_id'), ('currency'), ('language'), ('theme_color'),
        ('announcement'), ('show_contact_info'), ('allow_guest_checkout'),
        ('created_at'), ('updated_at')
      ) AS expected(column_name)
    )
  ) THEN
    RAISE EXCEPTION
      'store_settings column set differs from reviewed public-safe baseline';
  END IF;

  -- Do not let direct membership paths reintroduce client privileges after
  -- direct grants are revoked. USAGE tests inherited privilege paths; SET
  -- catches memberships that let a client assume another role in PostgreSQL 17.
  FOR v_role_name IN SELECT unnest(ARRAY['anon', 'authenticated']) LOOP
    FOR v_other_role IN
      SELECT oid, rolname
      FROM pg_roles
      WHERE rolname <> v_role_name::name
    LOOP
      IF pg_has_role(v_role_name::name, v_other_role.oid, 'USAGE')
         OR pg_has_role(v_role_name::name, v_other_role.oid, 'SET') THEN
        RAISE EXCEPTION
          'Role % has a membership path to %; review memberships before migration',
          v_role_name, v_other_role.rolname;
      END IF;
    END LOOP;
  END LOOP;

  -- PUBLIC ACL grants are left untouched. If any exist on these tables, stop
  -- because they can preserve effective access for anon/authenticated.
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    CROSS JOIN LATERAL aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) acl
    WHERE c.relnamespace = v_public
      AND c.relname IN (
        'stores', 'categories', 'products', 'product_variants',
        'product_images', 'profiles', 'customers', 'orders',
        'order_items', 'order_status_history', 'store_social_links',
        'store_settings'
      )
      AND c.relkind IN ('r', 'p')
      AND acl.grantee = 0
  ) OR EXISTS (
    SELECT 1
    FROM pg_attribute a
    CROSS JOIN LATERAL aclexplode(a.attacl) acl
    WHERE a.attrelid IN (
      SELECT c.oid
      FROM pg_class c
      WHERE c.relnamespace = v_public
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
      AND acl.grantee = 0
  ) THEN
    RAISE EXCEPTION
      'PUBLIC table or column ACL grants exist; review before changing client grants';
  END IF;

  -- No global defaults can be cancelled by a per-schema revoke.
  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
    WHERE d.defaclnamespace = 0
      AND d.defaclobjtype IN ('r', 'S', 'f')
      AND acl.grantee IN (0, v_anon, v_authenticated)
  ) THEN
    RAISE EXCEPTION
      'Relevant global default ACL exists; public-schema revokes are insufficient';
  END IF;

  -- This migration only changes postgres/public defaults. Stop if another
  -- creator currently grants these client roles or PUBLIC future access in
  -- public; do not broaden the migration to other creators.
  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
    WHERE d.defaclnamespace = v_public
      AND d.defaclobjtype IN ('r', 'S', 'f')
      AND d.defaclrole <> v_postgres
      AND acl.grantee IN (0, v_anon, v_authenticated)
  ) THEN
    RAISE EXCEPTION
      'Another creator has relevant public-schema defaults; review separately';
  END IF;

  -- Do not leave a postgres/public PUBLIC default that would reintroduce
  -- client access on future objects. This migration preserves PUBLIC ACLs;
  -- resolve such a baseline separately rather than silently changing it.
  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
    WHERE d.defaclrole = v_postgres
      AND d.defaclnamespace = v_public
      AND d.defaclobjtype IN ('r', 'S', 'f')
      AND acl.grantee = 0
  ) THEN
    RAISE EXCEPTION
      'postgres/public PUBLIC defaults exist; review before migration';
  END IF;

  -- Require the known excessive postgres/public client defaults so this is
  -- not silently applied against a materially different baseline.
  IF NOT EXISTS (
    SELECT 1 FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
    WHERE d.defaclrole = v_postgres AND d.defaclnamespace = v_public
      AND d.defaclobjtype = 'r'
      AND acl.grantee = v_anon AND acl.privilege_type = 'SELECT'
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
    WHERE d.defaclrole = v_postgres AND d.defaclnamespace = v_public
      AND d.defaclobjtype = 'r'
      AND acl.grantee = v_authenticated AND acl.privilege_type = 'SELECT'
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
    WHERE d.defaclrole = v_postgres AND d.defaclnamespace = v_public
      AND d.defaclobjtype = 'S'
      AND acl.grantee IN (v_anon, v_authenticated)
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
    WHERE d.defaclrole = v_postgres AND d.defaclnamespace = v_public
      AND d.defaclobjtype = 'f'
      AND acl.grantee IN (v_anon, v_authenticated)
      AND acl.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'postgres/public client defaults differ from the reviewed audit baseline';
  END IF;

  -- Verify the complete reviewed policy inventory, including policy
  -- expressions. The preflight audit exposes the live catalog text for review;
  -- any difference from this baseline fails closed.
  WITH expected(
    tablename, policyname, permissive, roles, cmd, qual, with_check
  ) AS (
    VALUES
      ('profiles', 'Sellers can view their own profile', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(id = ( SELECT auth.uid() AS uid))', NULL::text),
      ('profiles', 'Sellers can update their own profile', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'UPDATE',
       '(id = ( SELECT auth.uid() AS uid))',
       '(id = ( SELECT auth.uid() AS uid))'),
      ('stores', 'Owners can view their stores', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(owner_id = ( SELECT auth.uid() AS uid))', NULL::text),
      ('stores', 'Owners can create stores', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'INSERT', NULL::text,
       '(owner_id = ( SELECT auth.uid() AS uid))'),
      ('stores', 'Owners can update their stores', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'UPDATE',
       '(owner_id = ( SELECT auth.uid() AS uid))',
       '(owner_id = ( SELECT auth.uid() AS uid))'),
      ('stores', 'Owners can delete their stores', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'DELETE',
       '(owner_id = ( SELECT auth.uid() AS uid))', NULL::text),
      ('stores', 'Public can view published stores', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '(is_published = true)', NULL::text),
      ('categories', 'Categories are publicly readable', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       'true', NULL::text),
      ('products', 'Public can view active products in published stores', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '((is_active = true) AND (EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.is_published = true)))))',
       NULL::text),
      ('products', 'Owners can manage their products', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'),
      ('product_variants', 'Public can view variants of published products', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM products p JOIN stores s ON (s.id = p.store_id) WHERE ((p.id = product_id) AND (p.is_active = true) AND (s.is_published = true))))',
       NULL::text),
      ('product_variants', 'Owners can manage their variants', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'),
      ('product_images', 'Public can view images of published products', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM products p JOIN stores s ON (s.id = p.store_id) WHERE ((p.id = product_id) AND (p.is_active = true) AND (s.is_published = true))))',
       NULL::text),
      ('product_images', 'Owners can manage their product images', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM products p JOIN stores s ON (s.id = p.store_id) WHERE ((p.id = product_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM products p JOIN stores s ON (s.id = p.store_id) WHERE ((p.id = product_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'),
      ('customers', 'Owners can view their customers', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       NULL::text),
      ('orders', 'Owners can view their orders', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       NULL::text),
      ('order_items', 'Owners can view their order items', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM orders o JOIN stores s ON (s.id = o.store_id) WHERE ((o.id = order_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       NULL::text),
      ('order_status_history', 'Owners can view their order history', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM orders o JOIN stores s ON (s.id = o.store_id) WHERE ((o.id = order_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       NULL::text),
      ('store_social_links', 'Public can view published store social links', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '((is_visible = true) AND (EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.is_published = true)))))',
       NULL::text),
      ('store_social_links', 'Owners can manage social links', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'),
      ('store_settings', 'Public can view published store settings', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.is_published = true))))',
       NULL::text),
      ('store_settings', 'Owners can manage store settings', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))')
  ),
  actual AS (
    SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'stores', 'categories', 'products', 'product_variants',
        'product_images', 'profiles', 'customers', 'orders',
        'order_items', 'order_status_history', 'store_social_links',
        'store_settings'
      )
  )
  SELECT count(*) INTO v_actual_count FROM actual;

  IF v_actual_count <> v_expected_count THEN
    RAISE EXCEPTION
      'Expected exactly % application RLS policies; found %',
      v_expected_count, v_actual_count;
  END IF;

  WITH expected(
    tablename, policyname, permissive, roles, cmd, qual, with_check
  ) AS (
    VALUES
      ('profiles', 'Sellers can view their own profile', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(id = ( SELECT auth.uid() AS uid))', NULL::text),
      ('profiles', 'Sellers can update their own profile', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'UPDATE',
       '(id = ( SELECT auth.uid() AS uid))',
       '(id = ( SELECT auth.uid() AS uid))'),
      ('stores', 'Owners can view their stores', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(owner_id = ( SELECT auth.uid() AS uid))', NULL::text),
      ('stores', 'Owners can create stores', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'INSERT', NULL::text,
       '(owner_id = ( SELECT auth.uid() AS uid))'),
      ('stores', 'Owners can update their stores', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'UPDATE',
       '(owner_id = ( SELECT auth.uid() AS uid))',
       '(owner_id = ( SELECT auth.uid() AS uid))'),
      ('stores', 'Owners can delete their stores', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'DELETE',
       '(owner_id = ( SELECT auth.uid() AS uid))', NULL::text),
      ('stores', 'Public can view published stores', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '(is_published = true)', NULL::text),
      ('categories', 'Categories are publicly readable', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       'true', NULL::text),
      ('products', 'Public can view active products in published stores', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '((is_active = true) AND (EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.is_published = true)))))',
       NULL::text),
      ('products', 'Owners can manage their products', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'),
      ('product_variants', 'Public can view variants of published products', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM products p JOIN stores s ON (s.id = p.store_id) WHERE ((p.id = product_id) AND (p.is_active = true) AND (s.is_published = true))))',
       NULL::text),
      ('product_variants', 'Owners can manage their variants', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'),
      ('product_images', 'Public can view images of published products', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM products p JOIN stores s ON (s.id = p.store_id) WHERE ((p.id = product_id) AND (p.is_active = true) AND (s.is_published = true))))',
       NULL::text),
      ('product_images', 'Owners can manage their product images', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM products p JOIN stores s ON (s.id = p.store_id) WHERE ((p.id = product_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM products p JOIN stores s ON (s.id = p.store_id) WHERE ((p.id = product_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'),
      ('customers', 'Owners can view their customers', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       NULL::text),
      ('orders', 'Owners can view their orders', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       NULL::text),
      ('order_items', 'Owners can view their order items', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM orders o JOIN stores s ON (s.id = o.store_id) WHERE ((o.id = order_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       NULL::text),
      ('order_status_history', 'Owners can view their order history', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM orders o JOIN stores s ON (s.id = o.store_id) WHERE ((o.id = order_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       NULL::text),
      ('store_social_links', 'Public can view published store social links', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '((is_visible = true) AND (EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.is_published = true)))))',
       NULL::text),
      ('store_social_links', 'Owners can manage social links', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))'),
      ('store_settings', 'Public can view published store settings', 'PERMISSIVE',
       ARRAY['anon', 'authenticated']::name[], 'SELECT',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.is_published = true))))',
       NULL::text),
      ('store_settings', 'Owners can manage store settings', 'PERMISSIVE',
       ARRAY['authenticated']::name[], 'ALL',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))',
       '(EXISTS ( SELECT 1 FROM stores s WHERE ((s.id = store_id) AND (s.owner_id = ( SELECT auth.uid() AS uid))))')
  )
  SELECT EXISTS (
    (SELECT * FROM expected
     EXCEPT
     SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
     FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename IN (
         'stores', 'categories', 'products', 'product_variants',
         'product_images', 'profiles', 'customers', 'orders',
         'order_items', 'order_status_history', 'store_social_links',
         'store_settings'
       ))
    UNION ALL
    (SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
     FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename IN (
         'stores', 'categories', 'products', 'product_variants',
         'product_images', 'profiles', 'customers', 'orders',
         'order_items', 'order_status_history', 'store_social_links',
         'store_settings'
       )
     EXCEPT
     SELECT * FROM expected)
  ) INTO v_policy_mismatch;

  IF v_policy_mismatch THEN
    RAISE EXCEPTION
      'Live policy inventory/expressions differ from reviewed baseline';
  END IF;
END;
$preflight$;

-- Column ACLs are separate from table ACLs, so remove any direct column
-- grants explicitly before revoking table-level privileges. Only the two
-- client roles are targeted; other grantees and grantors are preserved.
DO $revoke_column_grants$
DECLARE
  v_column record;
BEGIN
  FOR v_column IN
    SELECT DISTINCT
      n.nspname AS schema_name,
      c.relname AS table_name,
      a.attname AS column_name
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN LATERAL aclexplode(a.attacl) acl
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'stores', 'categories', 'products', 'product_variants',
        'product_images', 'profiles', 'customers', 'orders',
        'order_items', 'order_status_history', 'store_social_links',
        'store_settings'
      )
      AND c.relkind IN ('r', 'p')
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND acl.grantee IN (
        (SELECT oid FROM pg_roles WHERE rolname = 'anon'),
        (SELECT oid FROM pg_roles WHERE rolname = 'authenticated')
      )
  LOOP
    EXECUTE format(
      'REVOKE ALL PRIVILEGES (%I) ON TABLE %I.%I FROM anon, authenticated RESTRICT',
      v_column.column_name,
      v_column.schema_name,
      v_column.table_name
    );
  END LOOP;
END;
$revoke_column_grants$;

-- Remove direct table-level privileges from client roles. RESTRICT is the
-- PostgreSQL default; no dependent grants are cascaded away.
REVOKE ALL PRIVILEGES ON TABLE
  public.profiles,
  public.stores,
  public.categories,
  public.products,
  public.product_variants,
  public.product_images,
  public.customers,
  public.orders,
  public.order_items,
  public.order_status_history,
  public.store_social_links,
  public.store_settings
FROM anon, authenticated RESTRICT;

-- Anonymous clients may read only the approved public storefront tables.
-- Existing RLS policies continue to enforce row-level visibility.
GRANT SELECT ON TABLE
  public.stores,
  public.categories,
  public.products,
  public.product_variants,
  public.product_images,
  public.store_social_links,
  public.store_settings
TO anon;

-- Authenticated users need SELECT for owner-scoped policies and seller UI.
GRANT SELECT ON TABLE
  public.profiles,
  public.stores,
  public.categories,
  public.products,
  public.product_variants,
  public.product_images,
  public.customers,
  public.orders,
  public.order_items,
  public.order_status_history,
  public.store_social_links,
  public.store_settings
TO authenticated;

-- Seller-management writes are scoped by the existing owner RLS policies.
GRANT INSERT, UPDATE, DELETE ON TABLE
  public.stores,
  public.products,
  public.product_variants,
  public.product_images,
  public.store_social_links,
  public.store_settings
TO authenticated;

-- Profiles are self-readable and self-updatable; creation remains in the
-- existing Auth trigger. No direct profile INSERT is granted.
GRANT UPDATE ON TABLE public.profiles TO authenticated;

-- Fail closed if effective table privileges do not exactly match the target.
-- PUBLIC grants and membership paths were rejected by the preflight, so this
-- also verifies the intended direct grants before the transaction can commit.
DO $verify_table_privileges$
DECLARE
  v_priv_check record;
BEGIN
  FOR v_priv_check IN
    WITH app_tables(table_name) AS (
      VALUES
        ('stores'), ('categories'), ('products'), ('product_variants'),
        ('product_images'), ('profiles'), ('customers'), ('orders'),
        ('order_items'), ('order_status_history'), ('store_social_links'),
        ('store_settings')
    ),
    client_roles(role_name) AS (
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
      e.role_name IS NOT NULL AS expected_privilege,
      has_table_privilege(
        r.role_name::name,
        format('public.%I', t.table_name),
        p.privilege_name
      ) AS effective_privilege
    FROM client_roles r
    CROSS JOIN app_tables t
    CROSS JOIN privileges p
    LEFT JOIN expected e
      ON e.role_name = r.role_name
     AND e.table_name = t.table_name
     AND e.privilege_name = p.privilege_name
  LOOP
    IF v_priv_check.effective_privilege
       IS DISTINCT FROM v_priv_check.expected_privilege THEN
      RAISE EXCEPTION
        'Unexpected effective % privilege on public.% for role %',
        v_priv_check.privilege_name,
        v_priv_check.table_name,
        v_priv_check.role_name;
    END IF;
  END LOOP;
END;
$verify_table_privileges$;

-- No direct column ACLs should remain for either client role. Their intended
-- column access, where allowed, comes only from the table-level grant matrix.
DO $verify_column_privileges$
DECLARE
  v_anon oid;
  v_authenticated oid;
BEGIN
  SELECT oid INTO v_anon FROM pg_roles WHERE rolname = 'anon';
  SELECT oid INTO v_authenticated
  FROM pg_roles
  WHERE rolname = 'authenticated';

  IF EXISTS (
    SELECT 1
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN LATERAL aclexplode(a.attacl) acl
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'stores', 'categories', 'products', 'product_variants',
        'product_images', 'profiles', 'customers', 'orders',
        'order_items', 'order_status_history', 'store_social_links',
        'store_settings'
      )
      AND c.relkind IN ('r', 'p')
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND a.attacl IS NOT NULL
      AND acl.grantee IN (v_anon, v_authenticated)
  ) THEN
    RAISE EXCEPTION
      'Direct client column ACLs remain on application tables';
  END IF;
END;
$verify_column_privileges$;

-- Correct only postgres/public defaults. Do not modify postgres/storage,
-- supabase_admin, PUBLIC, service_role, or any role membership.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

-- Verify the intended defaults are absent before commit.
DO $verify_defaults$
DECLARE
  v_public oid := 'public'::regnamespace;
  v_anon oid;
  v_authenticated oid;
  v_postgres oid;
BEGIN
  SELECT oid INTO v_anon FROM pg_roles WHERE rolname = 'anon';
  SELECT oid INTO v_authenticated FROM pg_roles WHERE rolname = 'authenticated';
  SELECT oid INTO v_postgres FROM pg_roles WHERE rolname = 'postgres';

  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) acl
    WHERE d.defaclrole = v_postgres
      AND d.defaclnamespace = v_public
      AND d.defaclobjtype IN ('r', 'S', 'f')
      AND acl.grantee IN (v_anon, v_authenticated)
  ) THEN
    RAISE EXCEPTION
      'Client defaults remain for postgres/public tables, sequences, or functions';
  END IF;
END;
$verify_defaults$;

COMMIT;
