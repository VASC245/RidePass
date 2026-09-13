-- Portal del cliente: lista unificada de entradas (atracciones + tours en chiva).
-- Las lecturas directas de tours / assigned_chivas están limitadas por RLS a
-- salidas públicas con ventas abiertas, así que un cliente perdía el título y
-- la fecha de sus compras pasadas. Este RPC devuelve solo las compras del
-- correo autenticado, sin exponer cédula, teléfono ni comprobante.
CREATE OR REPLACE FUNCTION public.get_my_tickets()
RETURNS TABLE (
  kind text, id uuid, title text, place text, date timestamptz,
  quantity integer, seats jsonb, total numeric, ref text,
  status text, used boolean, created_at timestamptz
)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT 'business', t.id, e.title, b.name, e.event_date,
         t.quantity, NULL::jsonb, t.total_price, t.payment_number,
         t.payment_status, coalesce(t.used, false), t.created_at
  FROM public.business_tickets t
  LEFT JOIN public.business_events e ON e.id = t.event_id
  LEFT JOIN public.businesses b ON b.id = t.business_id
  WHERE auth.email() IS NOT NULL AND lower(t.customer_email) = lower(auth.email())
  UNION ALL
  SELECT 'tour', s.id, tr.title, c.name, ac.departure_at,
         public.sale_seat_count(s.seats), s.seats, s.total_sale, s.payment_ref,
         CASE s.status WHEN 'pendiente' THEN 'pendiente'
                       WHEN 'pagado' THEN 'verificado'
                       WHEN 'abordado' THEN 'verificado'
                       ELSE 'rechazado' END,
         (s.status = 'abordado' OR s.boarded_at IS NOT NULL), s.created_at
  FROM public.sales_simple s
  LEFT JOIN public.tours tr ON tr.id = s.tour_id
  LEFT JOIN public.assigned_chivas ac ON ac.id = s.assigned_chiva_id
  LEFT JOIN public.chivas c ON c.id = ac.chiva_id
  WHERE auth.email() IS NOT NULL AND lower(s.customer_email) = lower(auth.email())
  ORDER BY created_at DESC
$$;
REVOKE ALL ON FUNCTION public.get_my_tickets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_tickets() TO authenticated, service_role;
