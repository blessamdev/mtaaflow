
-- MTAAFLOW: MIGRATION 001
-- Core business foundation

create extension if not exists pgcrypto;

-- 1. Seller profiles
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Stores
create table public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text,
  logo_url text,
  banner_url text,
  contact_phone text,
  location text,
  delivery_policy text,
  return_policy text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index stores_owner_id_idx
on public.stores(owner_id);

-- 3. Product categories
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  created_at timestamptz not null default now()
);

-- 4. Products
create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  slug text not null,
  description text,
  base_price_kes integer not null check (base_price_kes >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, slug),
  unique (id, store_id)
);

create index products_store_id_idx
on public.products(store_id);

-- 5. Product variants
create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null,
  store_id uuid not null,
  size text,
  color_name text,
  color_hex text,
  stock integer not null default 0 check (stock >= 0),
  sku text,
  price_adjustment_kes integer not null default 0,
  created_at timestamptz not null default now(),

  foreign key (product_id, store_id)
    references public.products(id, store_id)
    on delete cascade,

  unique (product_id, size, color_name)
);

create index product_variants_product_idx
on public.product_variants(product_id);

-- 6. Product images
create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  storage_path text not null,
  alt_text text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index product_images_product_idx
on public.product_images(product_id);

-- 7. Enable Row Level Security
alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_images enable row level security;

-- 8. Seller profile policies
create policy "Sellers can view their own profile"
on public.profiles for select
to authenticated
using (id = (select auth.uid()));

create policy "Sellers can update their own profile"
on public.profiles for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- 9. Store policies
create policy "Owners can view their stores"
on public.stores for select
to authenticated
using (owner_id = (select auth.uid()));

create policy "Owners can create stores"
on public.stores for insert
to authenticated
with check (owner_id = (select auth.uid()));

create policy "Owners can update their stores"
on public.stores for update
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy "Owners can delete their stores"
on public.stores for delete
to authenticated
using (owner_id = (select auth.uid()));

-- 10. Category read policy
create policy "Categories are publicly readable"
on public.categories for select
to anon, authenticated
using (true);

-- 11. Product policies
create policy "Public can view active products in published stores"
on public.products for select
to anon, authenticated
using (
  is_active = true
  and exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.is_published = true
  )
);

create policy "Owners can manage their products"
on public.products for all
to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.owner_id = (select auth.uid())
  )
);

-- 12. Variant policies
create policy "Public can view variants of published products"
on public.product_variants for select
to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id = product_id
      and p.is_active = true
      and s.is_published = true
  )
);

create policy "Owners can manage their variants"
on public.product_variants for all
to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.owner_id = (select auth.uid())
  )
);

-- 13. Image policies
create policy "Public can view images of published products"
on public.product_images for select
to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id = product_id
      and p.is_active = true
      and s.is_published = true
  )
);

create policy "Owners can manage their product images"
on public.product_images for all
to authenticated
using (
  exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id = product_id
      and s.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id = product_id
      and s.owner_id = (select auth.uid())
  )
);
