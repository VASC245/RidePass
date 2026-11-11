-- El dueño fija el precio por persona de sus tours (antes el panel lo
-- forzaba a $2). Se acota en la base para que nadie publique un tour a $0
-- o con un precio absurdo, aunque escriba directo contra la API.
alter table public.tours
  add constraint tours_base_price_range check (base_price >= 0.5 and base_price <= 1000);
