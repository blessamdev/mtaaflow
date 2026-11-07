-- ARCHIVED DRAFT ONLY: do not execute.
-- Preserved during consolidation of the competing 007 migration candidates.
-- This draft includes an ALTER DEFAULT PRIVILEGES statement for supabase_admin,
-- which is not authorized by the confirmed SQL Editor execution role.
--
-- MTAAFLOW: MIGRATION 007
-- Least-privilege table grants and default-privilege cleanup
--
-- Security objective:
--   * Reduce effective table-level privileges of anon and authenticated to
--     the minimum required by existing Row Level Security (RLS) policies.
--   * Remove excessive default table privileges so future tables do not
--     automatically inherit broad access.
--   * Preserve service_role and postgres administrative privileges.
--   * Preserve all existing RLS policies (none are disabled or weakened).
--
-- What this migration does NOT do:
--   * Does not disable or alter any RLS policy.
--   * Does not modify storage buckets, storage objects, or storage policies.
--   * Does not touch service_role or postgres privileges.
--   * Does not grant anonymous access to profiles, customers, orders,
--     order_items, order_status_history, or store_settings.
--   * Does not execute against Supabase; this file is for review only.

-- ============================================================
-- Step 1: Revoke all existing direct table-level privileges from
-- anon and authenticated on every application table.
-- This creates a clean slate before re-granting only what is needed.
-- ============================================================
REVOKE ALL ON TABLE public.profiles FROM anon, authenticated;
REVOKE ALL ON TABLE public.stores FROM anon, authenticated;
REVOKE ALL ON TABLE public.categories FROM anon, authenticated;
REVOKE ALL ON TABLE public.products FROM anon, authenticated;
REVOKE ALL ON TABLE public.product_variants FROM anon, authenticated;
REVOKE ALL ON TABLE public.product_images FROM anon, authenticated;
REVOKE ALL ON TABLE public.customers FROM anon, authenticated;
REVOKE ALL ON TABLE public.orders FROM anon, authenticated;
REVOKE ALL ON TABLE public.order_items FROM anon, authenticated;
REVOKE ALL ON TABLE public.order_status_history FROM anon, authenticated;
REVOKE ALL ON TABLE public.store_social_links FROM anon, authenticated;
REVOKE ALL ON TABLE public.store_settings FROM anon, authenticated;

-- ============================================================
-- Step 2: Remove excessive default table privileges for objects
-- created by postgres and supabase_admin in the public schema.
-- This ensures future tables do not automatically receive broad
-- privileges for anon or authenticated.
-- ============================================================
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;

-- ============================================================
-- Step 3: Grant anon only SELECT on approved public storefront
-- tables. These match the existing RLS SELECT policies that
-- already restrict rows to published/public data.
--
-- No INSERT/UPDATE/DELETE is granted to anon on any table.
-- profiles, customers, orders, order_items, order_status_history,
-- and store_settings are deliberately excluded.
-- ============================================================
GRANT SELECT ON TABLE public.stores TO anon;
GRANT SELECT ON TABLE public.categories TO anon;
GRANT SELECT ON TABLE public.products TO anon;
GRANT SELECT ON TABLE public.product_variants TO anon;
GRANT SELECT ON TABLE public.product_images TO anon;
GRANT SELECT ON TABLE public.store_social_links TO anon;

-- ============================================================
-- Step 4: Grant authenticated the table-level privileges required
-- by the existing RLS policies.
--
-- RLS policy reference (migrations 001-004):
--   * profiles:              SELECT + UPDATE (own profile only)
--   * stores:                SELECT + INSERT + UPDATE + DELETE (own stores)
--   * categories:            SELECT
--   * products:              SELECT + INSERT + UPDATE + DELETE (own products)
--   * product_variants:      SELECT + INSERT + UPDATE + DELETE (own variants)
--   * product_images:        SELECT + INSERT + UPDATE + DELETE (own images)
--   * customers:             SELECT (own store customers)
--   * orders:                SELECT (own store orders)
--   * order_items:           SELECT (own store order items)
--   * order_status_history:  SELECT (own store order history)
--   * store_social_links:    SELECT + INSERT + UPDATE + DELETE (own links)
--   * store_settings:        SELECT + INSERT + UPDATE + DELETE (own settings)
--
-- RLS expressions (not modified here) further restrict rows so that
-- authenticated users can only touch rows belonging to their own store
-- or profile. Table-level grants are necessary for RLS to be evaluated.
-- ============================================================
GRANT SELECT, UPDATE ON TABLE public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stores TO authenticated;
GRANT SELECT ON TABLE public.categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.products TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.product_variants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.product_images TO authenticated;
GRANT SELECT ON TABLE public.customers TO authenticated;
GRANT SELECT ON TABLE public.orders TO authenticated;
GRANT SELECT ON TABLE public.order_items TO authenticated;
GRANT SELECT ON TABLE public.order_status_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.store_social_links TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.store_settings TO authenticated;

-- ============================================================
-- Step 5: service_role and postgres are intentionally untouched.
-- service_role retains full administrative access (used by Edge
-- Functions for checkout and controlled order updates).
-- postgres retains ownership and all administrative privileges.
-- ============================================================

-- ============================================================
-- Uncertainty / items requiring confirmation before implementation:
--   1. Whether anon or authenticated inherit privileges through
--      PUBLIC membership that survive direct revocation. If a
--      PUBLIC grant exists, anon may retain access via PUBLIC.
--      Consider adding: REVOKE ALL ON TABLE ... FROM PUBLIC;
--      after verifying the live ACL inventory.
--   2. store_settings currently has a public SELECT RLS policy
--      (migration 004). This migration does not grant anon
--      table-level SELECT on store_settings, so the existing
--      policy becomes ineffective for anon. Confirm whether the
--      store_settings public SELECT policy should also be removed
--      in a separate migration once a safe public interface exists.
--   3. Default privileges may exist for other creator roles beyond
--      postgres and supabase_admin. The ACL inventory query should
--      be reviewed to confirm all creator roles are covered.
--   4. Confirm that Edge Functions (checkout, order updates) run as
--      service_role and will not be affected by removing table
--      privileges from anon and authenticated.
-- ============================================================
