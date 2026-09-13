-- El libro de saldos (owner_balance / agency_balance) solo se alimentaba en
-- verify_pending_payment, es decir, con transferencias verificadas. Las ventas
-- en efectivo del dueño y los cobros con tarjeta (kushki-charge -> confirm_sale)
-- nunca entraban. Ahora un trigger sobre sales_simple registra cualquier venta
-- que pase a 'pagado' y revierte el asiento si luego se cancela.

ALTER TABLE public.owner_balance  ADD COLUMN IF NOT EXISTS sale_id uuid REFERENCES public.sales_simple(id) ON DELETE SET NULL;
ALTER TABLE public.owner_balance  ADD COLUMN IF NOT EXISTS payment_method text;
ALTER TABLE public.agency_balance ADD COLUMN IF NOT EXISTS sale_id uuid REFERENCES public.sales_simple(id) ON DELETE SET NULL;
ALTER TABLE public.agency_balance ADD COLUMN IF NOT EXISTS payment_method text;
CREATE UNIQUE INDEX IF NOT EXISTS owner_balance_sale_uidx  ON public.owner_balance(sale_id)  WHERE sale_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS agency_balance_sale_uidx ON public.agency_balance(sale_id) WHERE sale_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.record_sale_balance()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_comprobante uuid;
BEGIN
  IF NEW.status = 'pagado' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'pagado') THEN
    SELECT id INTO v_comprobante FROM public.pending_payments
     WHERE sale_id = NEW.id ORDER BY created_at DESC LIMIT 1;

    INSERT INTO public.owner_balance (owner_id, assigned_chiva_id, comprobante_id, boletos_vendidos, monto_total, sale_id, payment_method)
    VALUES (NEW.owner_id, NEW.assigned_chiva_id, v_comprobante, public.sale_seat_count(NEW.seats),
            coalesce(NEW.owner_gain, NEW.total_sale, 0), NEW.id, NEW.payment_method)
    ON CONFLICT (sale_id) WHERE sale_id IS NOT NULL DO NOTHING;

    IF NEW.agency_id IS NOT NULL THEN
      INSERT INTO public.agency_balance (agency_id, assigned_chiva_id, comprobante_id, boletos_vendidos, monto_total, sale_id, payment_method)
      VALUES (NEW.agency_id, NEW.assigned_chiva_id, v_comprobante, public.sale_seat_count(NEW.seats),
              coalesce(NEW.agency_gain, 0), NEW.id, NEW.payment_method)
      ON CONFLICT (sale_id) WHERE sale_id IS NOT NULL DO NOTHING;
    END IF;

  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pagado' AND NEW.status IN ('cancelado', 'rechazado', 'expirado') THEN
    DELETE FROM public.owner_balance  WHERE sale_id = NEW.id;
    DELETE FROM public.agency_balance WHERE sale_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.record_sale_balance() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_record_sale_balance ON public.sales_simple;
CREATE TRIGGER trg_record_sale_balance
  AFTER INSERT OR UPDATE OF status ON public.sales_simple
  FOR EACH ROW EXECUTE FUNCTION public.record_sale_balance();

-- verify_pending_payment ya no inserta saldos: lo hace el trigger al confirmar.
CREATE OR REPLACE FUNCTION public.verify_pending_payment(p_payment_id uuid, p_estado text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_pay record;
BEGIN
  IF p_estado NOT IN ('verificado', 'rechazado') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;
  SELECT * INTO v_pay FROM public.pending_payments WHERE id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_NOT_FOUND'; END IF;
  IF v_pay.owner_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE = '42501';
  END IF;
  IF v_pay.estado <> 'pendiente' THEN RAISE EXCEPTION 'ALREADY_PROCESSED'; END IF;
  UPDATE public.pending_payments
     SET estado = p_estado, verified_by = auth.uid(), verified_at = now()
   WHERE id = p_payment_id;
  IF v_pay.sale_id IS NOT NULL THEN
    IF p_estado = 'verificado' THEN
      PERFORM public.confirm_sale(v_pay.sale_id, v_pay.numero_comprobante);
    ELSE
      PERFORM public.cancel_sale(v_pay.sale_id);
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'estado', p_estado, 'sale_id', v_pay.sale_id);
END;
$$;

-- Relleno: enlazar asientos existentes con su venta y registrar las ventas
-- pagadas que nunca entraron (efectivo y tarjeta).
UPDATE public.owner_balance ob SET sale_id = pp.sale_id, payment_method = 'transferencia'
  FROM public.pending_payments pp
 WHERE ob.comprobante_id = pp.id AND ob.sale_id IS NULL AND pp.sale_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM public.owner_balance o2 WHERE o2.sale_id = pp.sale_id);
UPDATE public.agency_balance ab SET sale_id = pp.sale_id, payment_method = 'transferencia'
  FROM public.pending_payments pp
 WHERE ab.comprobante_id = pp.id AND ab.sale_id IS NULL AND pp.sale_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM public.agency_balance a2 WHERE a2.sale_id = pp.sale_id);

INSERT INTO public.owner_balance (owner_id, assigned_chiva_id, boletos_vendidos, monto_total, sale_id, payment_method, created_at)
SELECT s.owner_id, s.assigned_chiva_id, public.sale_seat_count(s.seats), coalesce(s.owner_gain, s.total_sale, 0), s.id, s.payment_method, s.created_at
  FROM public.sales_simple s
 WHERE s.status = 'pagado'
   AND NOT EXISTS (SELECT 1 FROM public.owner_balance o WHERE o.sale_id = s.id);
INSERT INTO public.agency_balance (agency_id, assigned_chiva_id, boletos_vendidos, monto_total, sale_id, payment_method, created_at)
SELECT s.agency_id, s.assigned_chiva_id, public.sale_seat_count(s.seats), coalesce(s.agency_gain, 0), s.id, s.payment_method, s.created_at
  FROM public.sales_simple s
 WHERE s.status = 'pagado' AND s.agency_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM public.agency_balance a WHERE a.sale_id = s.id);
