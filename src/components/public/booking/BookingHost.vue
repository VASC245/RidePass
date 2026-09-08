<template>
  <TourBookingModal
    :tour="selectedTour"
    @close="selectedTour = null"
    @completed="onTourCompleted"
  />
  <AttractionBookingModal
    :biz="selectedBiz"
    @close="selectedBiz = null"
    @completed="onBizCompleted"
  />
  <DirectoryInfoModal
    :biz="infoBiz"
    @close="infoBiz = null"
  />
  <LoginWall
    :show="wallShow"
    @close="wallShow = false"
    @continue-as-guest="onGuest"
  />
</template>

<script setup>
import { ref } from 'vue'
import { useAuthStore } from '@/stores/authStore'
import TourBookingModal from './TourBookingModal.vue'
import AttractionBookingModal from './AttractionBookingModal.vue'
import DirectoryInfoModal from '@/components/public/DirectoryInfoModal.vue'
import LoginWall from '@/components/public/LoginWall.vue'

const emit = defineEmits(['tours-changed', 'biz-changed'])

const authStore    = useAuthStore()
const selectedTour = ref(null)
const selectedBiz  = ref(null)
const infoBiz      = ref(null)
const wallShow     = ref(false)
const wallTarget   = ref(null) // 'tour' | 'biz'
const wallData     = ref(null)
const guestBypass  = ref(false)

const openTour = (tour) => {
  if (!authStore.user && !guestBypass.value) {
    wallTarget.value = 'tour'
    wallData.value   = tour
    wallShow.value   = true
    return
  }
  selectedBiz.value  = null
  selectedTour.value = tour
}

const openBiz = (biz) => {
  // Fichas del directorio (sin dueño): solo información, sin flujo de compra ni login
  if (biz?.unaffiliated) {
    infoBiz.value = biz
    return
  }
  if (!authStore.user && !guestBypass.value) {
    wallTarget.value = 'biz'
    wallData.value   = biz
    wallShow.value   = true
    return
  }
  selectedTour.value = null
  selectedBiz.value  = biz
}

const onGuest = () => {
  guestBypass.value = true
  wallShow.value    = false
  if (wallTarget.value === 'tour') openTour(wallData.value)
  else if (wallTarget.value === 'biz') openBiz(wallData.value)
}

const onTourCompleted = () => {
  selectedTour.value = null
  emit('tours-changed')
}

const onBizCompleted = () => {
  selectedBiz.value = null
  emit('biz-changed')
}

defineExpose({ openTour, openBiz })
</script>
