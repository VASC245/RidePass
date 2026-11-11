// Datos de cobro de chivaspass (planes y estado de cuenta). No son los datos
// bancarios del vendedor: esos viven en panel_settings.
export const PLATFORM_BANK = {
  name:     import.meta.env.VITE_PLANS_BANK_NAME    || "",
  account:  import.meta.env.VITE_PLANS_BANK_ACCOUNT || "",
  type:     import.meta.env.VITE_PLANS_BANK_TYPE    || "",
  owner:    import.meta.env.VITE_PLANS_BANK_OWNER   || "",
  ruc:      import.meta.env.VITE_PLANS_BANK_RUC     || "",
  whatsapp: import.meta.env.VITE_PLANS_WHATSAPP     || "",
};

export const hasPlatformBank = !!(PLATFORM_BANK.name && PLATFORM_BANK.account && PLATFORM_BANK.owner);

// Filas de la tarjeta de transferencia; vacías si aún no hay datos de cobro
export const platformBankRows = () => hasPlatformBank
  ? [
      { label: "Banco",   value: PLATFORM_BANK.name },
      { label: "Cuenta",  value: [PLATFORM_BANK.type, PLATFORM_BANK.account].filter(Boolean).join(" ") },
      { label: "Titular", value: PLATFORM_BANK.owner },
      ...(PLATFORM_BANK.ruc ? [{ label: "RUC", value: PLATFORM_BANK.ruc }] : []),
    ]
  : [];
