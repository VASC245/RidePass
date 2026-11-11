// Cargo por servicio al comprador en ventas web: 8 % + $0,30, redondeado a
// 5 centavos. El vendedor recibe su precio íntegro.
//
// Esta copia solo sirve para MOSTRAR el desglose antes de reservar. El valor
// real lo calcula la base de datos (public.platform_fee) al crear la venta y
// es el que devuelven public-reserve y kushki-charge. Si cambian los
// parámetros en app_settings hay que actualizar también estas constantes.
export const FEE_PCT = 8;
export const FEE_FIXED = 0.3;

export const platformFee = (amount) => {
  const n = Number(amount);
  if (!Number.isFinite(n) || n <= 0) return 0;
  return Math.round((n * FEE_PCT / 100 + FEE_FIXED) / 0.05) * 0.05;
};

export const money = (n) => Number(n ?? 0).toFixed(2);
