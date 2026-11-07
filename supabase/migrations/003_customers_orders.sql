
-- MTAAFLOW: MIGRATION 003
-- Customers, orders and order history

-- 1. Customers
create table public.customers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  full_name text not null,
  phone text not null,
  email text,
  location text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (id, store_id)
);

create index customers_store_idx
on public.customers(store_id);

-- 2. Orders
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  customer_id uuid not null,
  order_ref text not null unique,

  delivery_method text not null,
  delivery_address text,

  fulfilment_status text not null default 'NEW'
    check (fulfilment_status in (
      'NEW', 'CONFIRMED', 'PREPARING',
      'READY', 'DISPATCHED', 'COMPLETED', 'CANCELLED'
    )),

  payment_status text not null default 'UNPAID'
    check (payment_status in (
      'UNPAID', 'PENDING', 'PAID', 'FAILED', 'REFUNDED'
    )),

  payment_method text,
  currency text not null default 'KES'
    check (currency = 'KES'),

  total_kes integer not null check (total_kes >= 0),

  tracking_token_hash text unique,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  foreign key (customer_id, store_id)
    references public.customers(id, store_id)
);

create index orders_store_idx
on public.orders(store_id);

create index orders_customer_idx
on public.orders(customer_id);

create index orders_created_idx
on public.orders(created_at desc);

-- 3. Order items
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,

  product_id uuid references public.products(id) on delete set null,
  variant_id uuid references public.product_variants(id) on delete set null,

  product_name text not null,
  selected_size text,
  selected_color text,

  quantity integer not null check (quantity > 0),
  unit_price_kes integer not null check (unit_price_kes >= 0),
  line_total_kes integer not null check (line_total_kes >= 0),

  created_at timestamptz not null default now()
);

create index order_items_order_idx
on public.order_items(order_id);

-- 4. Order status history
create table public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,

  status text not null,
  changed_by uuid references auth.users(id) on delete set null,
  note text,

  created_at timestamptz not null default now()
);

create index order_history_order_idx
on public.order_status_history(order_id, created_at);

-- 5. Enable Row Level Security
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;

-- 6. Sellers can read their own customers
create policy "Owners can view their customers"
on public.customers
for select
to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.owner_id = (select auth.uid())
  )
);

-- 7. Sellers can read their own orders
create policy "Owners can view their orders"
on public.orders
for select
to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.owner_id = (select auth.uid())
  )
);

-- 8. Sellers can read their own order items
create policy "Owners can view their order items"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.stores s on s.id = o.store_id
    where o.id = order_id
      and s.owner_id = (select auth.uid())
  )
);

-- 9. Sellers can read their own order history
create policy "Owners can view their order history"
on public.order_status_history
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.stores s on s.id = o.store_id
    where o.id = order_id
      and s.owner_id = (select auth.uid())
  )
);
