-- Enlace entre pending_payments y sales_simple
-- Permite liberar asientos correctamente cuando se rechaza un comprobante

ALTER TABLE public.pending_payments
  ADD COLUMN IF NOT EXISTS sale_id uuid REFERENCES public.sales_simple(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_pending_sale ON public.pending_payments(sale_id);

-- Permitir status 'pendiente' y 'cancelado' en sales_simple
-- (la columna no tenía CHECK constraint, solo DEFAULT 'pagado' — no se necesita ALTER)
