-- ================================================================
-- ChivasPass — Rol cliente + política email en tickets
-- ================================================================

-- Agregar 'cliente' a los roles permitidos
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN ('dueño', 'agencia', 'conductor', 'negocio', 'cliente'));

-- Los clientes ven sus propios tickets por email
CREATE POLICY "btickets: customer email view"
  ON public.business_tickets FOR SELECT
  USING (customer_email = auth.email());
