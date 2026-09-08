<template>
  <div style="font-family:'DM Sans',sans-serif;background:#F3F4F6;min-height:calc(100vh - 64px)">

    <!-- Breadcrumb -->
    <div style="background:#fff;border-bottom:1px solid #E5E7EB;padding:10px clamp(1rem,4vw,3rem)">
      <div class="max-w-7xl mx-auto flex items-center gap-2 text-sm" style="color:#6B7280">
        <RouterLink to="/" style="color:#6B7280;text-decoration:none" class="hover:text-orange-500">Inicio</RouterLink>
        <span style="color:#D1D5DB">›</span>
        <span style="color:#111827;font-weight:600">Contactar con ventas</span>
      </div>
    </div>

    <!-- Split layout -->
    <div class="contact-grid">

      <!-- ── LEFT — gradient panel ── -->
      <div class="panel-left">
        <div class="left-content">

          <span class="eyebrow-badge">📍 Baños de Agua Santa, Ecuador</span>

          <h1 class="contact-headline">
            Vende más<br/>
            <span class="contact-headline-accent">tours con</span><br/>
            ChivaPass
          </h1>

          <p class="contact-sub">
            La plataforma líder para gestionar y vender entradas en Baños.
            Tours en chiva, atracciones turísticas y mucho más —
            todo desde un solo panel.
          </p>

          <!-- Stats -->
          <div class="contact-stats">
            <div class="contact-stat">
              <div class="stat-num">100%</div>
              <div class="stat-label">Ticket digital QR</div>
            </div>
            <div class="contact-stat">
              <div class="stat-num">0%</div>
              <div class="stat-label">Comisiones ocultas</div>
            </div>
            <div class="contact-stat">
              <div class="stat-num">24/7</div>
              <div class="stat-label">Disponible siempre</div>
            </div>
          </div>

          <!-- Testimonial — oculto en móvil -->
          <div class="contact-testimonial">
            <p class="t-text">
              "Con ChivaPass vendemos más boletos en línea sin filas
              ni complicaciones. Nuestros clientes reciben su QR al instante."
            </p>
            <div class="flex items-center gap-3 mt-3">
              <div class="t-avatar">🚍</div>
              <div>
                <p class="t-name">Carlos Mora</p>
                <p class="t-role">Dueño de Chiva · Baños, Ecuador</p>
              </div>
            </div>
          </div>

        </div>
      </div>

      <!-- ── RIGHT — form panel ── -->
      <div class="panel-right">
        <div class="form-card">

          <!-- Formulario -->
          <div v-if="!sent">
            <h2 class="form-title">Habla con nuestro equipo</h2>
            <p class="form-subtitle">Cuéntanos sobre tu negocio y te contactamos en menos de 24 horas.</p>

            <form @submit.prevent="submitForm" novalidate>
              <div class="form-grid">

                <div class="field">
                  <label>Nombre <span class="req">*</span></label>
                  <input v-model="f.nombre" :class="{'field-error': errors.nombre}" type="text" placeholder="Juan" @input="errors.nombre=false" />
                </div>

                <div class="field">
                  <label>Apellidos <span class="req">*</span></label>
                  <input v-model="f.apellidos" :class="{'field-error': errors.apellidos}" type="text" placeholder="Pérez Torres" @input="errors.apellidos=false" />
                </div>

                <div class="field">
                  <label>Correo electrónico <span class="req">*</span></label>
                  <input v-model="f.email" :class="{'field-error': errors.email}" type="email" placeholder="juan@correo.com" @input="errors.email=false" />
                </div>

                <div class="field">
                  <label>Teléfono / WhatsApp <span class="req">*</span></label>
                  <input v-model="f.phone" :class="{'field-error': errors.phone}" type="tel" placeholder="+593 99 999 9999" @input="errors.phone=false" />
                </div>

                <div class="field">
                  <label>Nombre de tu chiva o negocio <span class="req">*</span></label>
                  <input v-model="f.negocio" :class="{'field-error': errors.negocio}" type="text" placeholder="Ej: Chiva El Tungurahua" @input="errors.negocio=false" />
                </div>

                <div class="field">
                  <label>País <span class="req">*</span></label>
                  <select v-model="f.pais" :class="{'field-error': errors.pais}" @change="errors.pais=false">
                    <option value="" disabled>Selecciona...</option>
                    <option value="ec">🇪🇨 Ecuador</option>
                    <option value="co">🇨🇴 Colombia</option>
                    <option value="pe">🇵🇪 Perú</option>
                    <option value="bo">🇧🇴 Bolivia</option>
                    <option value="otro">Otro</option>
                  </select>
                </div>

                <div class="field">
                  <label>¿Cuántos tours realizas al mes? <span class="req">*</span></label>
                  <select v-model="f.tours" :class="{'field-error': errors.tours}" @change="errors.tours=false">
                    <option value="" disabled>Selecciona...</option>
                    <option value="1-5">1 a 5 tours</option>
                    <option value="6-15">6 a 15 tours</option>
                    <option value="16-30">16 a 30 tours</option>
                    <option value="30+">Más de 30 tours</option>
                    <option value="aun-no">Aún no tengo tours activos</option>
                  </select>
                </div>

                <div class="field">
                  <label>Tipo de negocio <span class="req">*</span></label>
                  <select v-model="f.tipo" :class="{'field-error': errors.tipo}" @change="errors.tipo=false">
                    <option value="" disabled>Selecciona...</option>
                    <option value="chiva">🚍 Dueño de Chiva</option>
                    <option value="atraccion">🏔️ Atracción Turística</option>
                    <option value="agencia">🏢 Agencia de Viajes</option>
                    <option value="restaurante">🍽️ Restaurante</option>
                    <option value="otro">🎯 Otro</option>
                  </select>
                </div>

                <div class="field full">
                  <label>Motivo para contactarnos <span class="req">*</span></label>
                  <select v-model="f.motivo" :class="{'field-error': errors.motivo}" @change="errors.motivo=false">
                    <option value="" disabled>Selecciona...</option>
                    <option value="registro">Quiero registrar mi negocio</option>
                    <option value="planes">Tengo dudas sobre los planes y precios</option>
                    <option value="demo">Me gustaría ver una demo</option>
                    <option value="soporte">Necesito soporte técnico</option>
                    <option value="integracion">Quiero integrar pagos con tarjeta</option>
                    <option value="otro">Otro</option>
                  </select>
                </div>

              </div>

              <div class="form-divider">Información procesada de forma segura</div>

              <button type="submit" :disabled="loading" class="btn-submit">
                <span v-if="loading" class="spinner-inline"></span>
                {{ loading ? 'Enviando...' : 'Enviar solicitud' }}
              </button>

              <p class="form-note">
                Al enviar, aceptas que ChivaPass te contacte con información sobre la plataforma.
                Nunca compartimos tus datos con terceros.
              </p>
            </form>
          </div>

          <!-- Estado de éxito -->
          <div v-else class="success-state">
            <div class="success-icon">✅</div>
            <h3 class="success-title">¡Mensaje enviado!</h3>
            <p class="success-msg">
              Gracias por contactarnos. Nuestro equipo revisará tu solicitud
              y te responderá en menos de 24 horas por WhatsApp o correo.
            </p>
            <RouterLink to="/" class="success-cta">Explorar ChivaPass →</RouterLink>
          </div>

        </div>
      </div>

    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'

const sent    = ref(false)
const loading = ref(false)

const f = reactive({
  nombre: '', apellidos: '', email: '', phone: '',
  negocio: '', pais: '', tours: '', tipo: '', motivo: '',
})

const errors = reactive({
  nombre: false, apellidos: false, email: false, phone: false,
  negocio: false, pais: false, tours: false, tipo: false, motivo: false,
})

const submitForm = async () => {
  let valid = true
  for (const key of Object.keys(errors)) {
    if (!f[key]) { errors[key] = true; valid = false }
  }
  if (!valid) return

  loading.value = true
  await new Promise(r => setTimeout(r, 1200))
  loading.value = false
  sent.value = true
}
</script>

<style scoped>
.contact-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  min-height: calc(100vh - 106px);
}

/* ── LEFT ── */
.panel-left {
  background: linear-gradient(155deg, #FFF8EC 0%, #FFE8C8 20%, #FF8C35 55%, #D04010 80%, #9B2226 100%);
  padding: clamp(3rem,6vw,5rem) clamp(2rem,5vw,4rem);
  display: flex;
  flex-direction: column;
  justify-content: center;
  position: relative;
  overflow: hidden;
}
.panel-left::before {
  content: '';
  position: absolute;
  width: 500px; height: 500px;
  border-radius: 50%;
  background: rgba(255,255,255,.07);
  top: -120px; left: -120px;
}
.panel-left::after {
  content: '';
  position: absolute;
  width: 300px; height: 300px;
  border-radius: 50%;
  background: rgba(0,0,0,.08);
  bottom: -80px; right: -80px;
}
.left-content { position: relative; z-index: 1; }

.eyebrow-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: rgba(255,255,255,.18);
  border: 1px solid rgba(255,255,255,.35);
  color: #fff;
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  padding: 5px 12px;
  border-radius: 999px;
  margin-bottom: 1.5rem;
}
.contact-headline {
  font-family: 'Bebas Neue', sans-serif;
  font-size: clamp(3rem, 5.5vw, 5.5rem);
  line-height: 0.95;
  color: #fff;
  letter-spacing: -0.01em;
  margin-bottom: 1.5rem;
}
.contact-headline-accent { color: #FFE8C8; }
.contact-sub {
  font-size: 1rem;
  color: rgba(255,255,255,.82);
  line-height: 1.65;
  max-width: 420px;
  margin-bottom: 2.5rem;
}
.contact-stats { display: flex; gap: 2rem; flex-wrap: wrap; }
.contact-stat {
  border-left: 3px solid rgba(255,255,255,.4);
  padding-left: 1rem;
}
.stat-num {
  font-family: 'Bebas Neue', sans-serif;
  font-size: 2rem; color: #fff; line-height: 1;
}
.stat-label {
  font-size: 0.72rem; font-weight: 500;
  color: rgba(255,255,255,.7);
  letter-spacing: 0.05em; text-transform: uppercase; margin-top: 2px;
}
.contact-testimonial {
  margin-top: 3rem;
  background: rgba(255,255,255,.12);
  border: 1px solid rgba(255,255,255,.22);
  border-radius: 16px;
  padding: 1.25rem 1.5rem;
  backdrop-filter: blur(4px);
}
.t-text { font-size: 0.875rem; color: rgba(255,255,255,.9); line-height: 1.6; font-style: italic; margin: 0; }
.t-avatar {
  width: 36px; height: 36px; border-radius: 50%;
  background: rgba(255,255,255,.25);
  display: flex; align-items: center; justify-content: center; font-size: 18px;
  flex-shrink: 0;
}
.t-name { font-size: 0.82rem; font-weight: 600; color: #fff; margin: 0; }
.t-role { font-size: 0.72rem; color: rgba(255,255,255,.65); margin: 0; }

/* ── RIGHT ── */
.panel-right {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: clamp(2rem,4vw,3.5rem) clamp(1.5rem,4vw,3rem);
}
.form-card {
  background: #fff;
  border-radius: 20px;
  box-shadow: 0 4px 6px -1px rgba(0,0,0,.07), 0 20px 60px -10px rgba(0,0,0,.12);
  padding: 2.5rem;
  width: 100%;
  max-width: 520px;
}
.form-title { font-size: 1.375rem; font-weight: 700; color: #111827; margin-bottom: 0.25rem; letter-spacing: -0.02em; }
.form-subtitle { font-size: 0.875rem; color: #6B7280; margin-bottom: 1.75rem; line-height: 1.5; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem 1.25rem; }
.field { display: flex; flex-direction: column; gap: 5px; }
.field.full { grid-column: 1 / -1; }
.field label { font-size: 0.78rem; font-weight: 600; color: #374151; }
.req { color: #EA580C; margin-left: 2px; }
.field input,
.field select {
  font-family: 'DM Sans', sans-serif;
  font-size: 0.875rem;
  color: #111827;
  background: #F9FAFB;
  border: 1.5px solid #E5E7EB;
  border-radius: 10px;
  padding: 10px 14px;
  outline: none;
  appearance: none;
  -webkit-appearance: none;
  width: 100%;
  transition: border-color .15s, box-shadow .15s, background .15s;
}
.field select {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%236B7280' stroke-width='2'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 12px center;
  padding-right: 36px;
}
.field input:focus,
.field select:focus {
  border-color: #EA580C;
  background: #fff;
  box-shadow: 0 0 0 3px rgba(234,88,12,.12);
}
.field-error { border-color: #EF4444 !important; box-shadow: 0 0 0 3px rgba(239,68,68,.12) !important; }
.form-divider {
  margin: 1.5rem 0 1rem;
  display: flex; align-items: center; gap: 12px;
  color: #D1D5DB; font-size: 0.78rem;
}
.form-divider::before, .form-divider::after { content: ''; flex: 1; height: 1px; background: #E5E7EB; }
.btn-submit {
  font-family: 'DM Sans', sans-serif;
  font-size: 0.9375rem; font-weight: 700;
  color: #fff; background: #111827;
  border: none; border-radius: 12px;
  padding: 13px 32px; width: 100%; cursor: pointer;
  margin-top: 1.5rem;
  transition: background .2s, transform .1s, box-shadow .2s;
  display: flex; align-items: center; justify-content: center; gap: 8px;
}
.btn-submit:hover { background: #000; box-shadow: 0 4px 20px rgba(0,0,0,.25); }
.btn-submit:active { transform: scale(0.985); }
.btn-submit:disabled { background: #374151; cursor: not-allowed; }
.spinner-inline {
  width: 16px; height: 16px;
  border: 2px solid rgba(255,255,255,.4);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin .6s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.form-note { font-size: 0.72rem; color: #9CA3AF; text-align: center; margin-top: 0.875rem; line-height: 1.5; }

/* Success */
.success-state { display: flex; flex-direction: column; align-items: center; text-align: center; padding: 2rem 1rem; gap: 1rem; }
.success-icon { width: 64px; height: 64px; background: #DCFCE7; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 2rem; }
.success-title { font-size: 1.25rem; font-weight: 700; color: #111827; }
.success-msg { font-size: 0.875rem; color: #6B7280; line-height: 1.6; max-width: 320px; }
.success-cta {
  font-size: 0.875rem; font-weight: 600;
  color: #fff; background: #EA580C;
  border-radius: 10px; padding: 11px 24px;
  text-decoration: none; transition: background .15s;
}
.success-cta:hover { background: #C2500A; }

/* ── Responsive ── */
@media (max-width: 900px) {
  .contact-grid { grid-template-columns: 1fr; }
  .panel-left { padding: 3rem 1.5rem 2.5rem; }
  .contact-headline { font-size: clamp(2.5rem, 10vw, 4rem); }
  .contact-stats { gap: 1.25rem; }
  .contact-testimonial { display: none; }
  .panel-right { padding: 2rem 1rem; }
  .form-card { max-width: 100%; }
}
@media (max-width: 580px) {
  .form-grid { grid-template-columns: 1fr; }
  .field.full { grid-column: 1; }
  .form-card { padding: 1.75rem 1.25rem; }
}
</style>
