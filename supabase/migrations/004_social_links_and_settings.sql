
-- MTAAFLOW: MIGRATION 004
-- Social links and store settings

-- 1. Store social links
create table public.store_social_links (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,

  platform text not null
    check (platform in (
      'instagram', 'tiktok', 'facebook',
      'whatsapp', 'youtube', 'pinterest', 'x'
    )),

  profile_url text not null,
  is_visible boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (store_id, platform)
);

create index social_links_store_idx
on public.store_social_links(store_id);

-- 2. Store settings
create table public.store_settings (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null unique
    references public.stores(id) on delete cascade,

  currency text not null default 'KES'
    check (currency = 'KES'),

  language text not null default 'en'
    check (language in ('en', 'sw')),

  theme_color text default '#111827',
  announcement text,
  show_contact_info boolean not null default true,
  allow_guest_checkout boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Enable RLS
alter table public.store_social_links enable row level security;
alter table public.store_settings enable row level security;

-- 4. Public can view visible social links of published stores
create policy "Public can view published store social links"
on public.store_social_links
for select
to anon, authenticated
using (
  is_visible = true
  and exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.is_published = true
  )
);

-- 5. Owners can manage their social links
create policy "Owners can manage social links"
on public.store_social_links
for all
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

-- 6. Public can view settings of published stores
create policy "Public can view published store settings"
on public.store_settings
for select
to anon, authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id
      and s.is_published = true
  )
);

-- 7. Owners can manage their store settings
create policy "Owners can manage store settings"
on public.store_settings
for all
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
