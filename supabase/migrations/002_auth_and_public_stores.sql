
-- MTAAFLOW: MIGRATION 002
-- Seller profile automation and public storefront access

-- 1. Automatically create a profile after signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- Prevent direct execution by application users
revoke all on function public.handle_new_user()
from public, anon, authenticated;

-- 2. Attach the function to Supabase Auth
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- 3. Allow visitors to read published stores
create policy "Public can view published stores"
on public.stores
for select
to anon, authenticated
using (is_published = true);
