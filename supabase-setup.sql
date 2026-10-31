-- Coffee site database setup. Paste into Supabase > SQL Editor and run ONCE.
-- Safe to re-run: it only adds what's missing and refreshes the rules.
--
-- Before running, replace these two placeholders:
--   OWNER_EMAIL_HERE   -> the owner's login email
--   NTFY_TOPIC_HERE    -> a long, random, private ntfy topic name

-- ========== MENU ==========
create table if not exists menu (
  id bigint generated always as identity primary key,
  name text not null,
  price text,
  category text default 'Menu',
  description text
);
alter table menu
  add column if not exists variants jsonb default '[]'::jsonb,
  add column if not exists options jsonb default '[]'::jsonb,
  add column if not exists options_label text default 'Flavors',
  add column if not exists sort_order int default 0,
  add column if not exists available boolean default true;

alter table menu enable row level security;
drop policy if exists "public read" on menu;
drop policy if exists "owner write" on menu;
create policy "public read" on menu for select using (true);
create policy "owner write" on menu for all to authenticated
  using ((auth.jwt()->>'email') = 'OWNER_EMAIL_HERE')
  with check ((auth.jwt()->>'email') = 'OWNER_EMAIL_HERE');

-- starter item (only if the menu is empty)
insert into menu (name, category, description, variants, options_label, options, sort_order)
select 'Latte', 'Coffee', 'Espresso with steamed milk, served your way.',
  '[{"label":"Iced","price":"5.50"},{"label":"Hot","price":"4.75"}]'::jsonb,
  'Choose a flavor',
  '[{"name":"Vanilla"},{"name":"Caramel"},{"name":"Hazelnut"},{"name":"Mocha","price":"+0.50"},{"name":"Lavender","price":"+0.50"}]'::jsonb,
  1
where not exists (select 1 from menu);

-- ========== ORDERS ==========
create table if not exists orders (
  id bigint generated always as identity primary key,
  code text not null,
  customer_name text not null,
  note text,
  items jsonb not null,
  total numeric(8,2) not null,
  status text not null default 'new',
  created_at timestamptz not null default now()
);
alter table orders enable row level security;
drop policy if exists "anyone can place orders" on orders;
drop policy if exists "owner reads orders" on orders;
drop policy if exists "owner updates orders" on orders;
drop policy if exists "owner deletes orders" on orders;

-- Customers can only ADD orders (never read or change them), with sanity limits.
create policy "anyone can place orders" on orders for insert to anon, authenticated
  with check (
    status = 'new'
    and char_length(customer_name) between 1 and 60
    and (note is null or char_length(note) <= 300)
    and jsonb_typeof(items) = 'array'
    and jsonb_array_length(items) between 1 and 30
    and total >= 0 and total < 1000
  );
create policy "owner reads orders" on orders for select to authenticated
  using ((auth.jwt()->>'email') = 'OWNER_EMAIL_HERE');
create policy "owner updates orders" on orders for update to authenticated
  using ((auth.jwt()->>'email') = 'OWNER_EMAIL_HERE')
  with check ((auth.jwt()->>'email') = 'OWNER_EMAIL_HERE');
create policy "owner deletes orders" on orders for delete to authenticated
  using ((auth.jwt()->>'email') = 'OWNER_EMAIL_HERE');

-- ========== LIVE UPDATES ==========
do $$ begin
  begin alter publication supabase_realtime add table menu;   exception when others then null; end;
  begin alter publication supabase_realtime add table orders; exception when others then null; end;
end $$;

-- ========== PHONE ALERT (ntfy) ==========
create extension if not exists pg_net;

create or replace function notify_new_order() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare lines text;
begin
  select string_agg(
    (it->>'qty') || ' x ' || (it->>'name') ||
    case when coalesce(it->>'variant','') <> '' or coalesce(it->>'option','') <> ''
      then ' (' || concat_ws(', ', nullif(it->>'variant',''), nullif(it->>'option','')) || ')' else '' end,
    E'\n')
  into lines
  from jsonb_array_elements(new.items) it;

  perform net.http_post(
    url := 'https://ntfy.sh',
    body := jsonb_build_object(
      'topic', 'NTFY_TOPIC_HERE',
      'title', 'New order #' || new.code || ' - ' || new.customer_name,
      'message', coalesce(lines, '') || E'\nTotal $' || to_char(new.total, 'FM999990.00')
                 || coalesce(E'\nNote: ' || new.note, ''),
      'priority', 4,
      'tags', jsonb_build_array('coffee')
    )
  );
  return new;
exception when others then
  return new;   -- never block an order because the alert failed
end $$;

drop trigger if exists on_order_created on orders;
create trigger on_order_created after insert on orders
  for each row execute function notify_new_order();
