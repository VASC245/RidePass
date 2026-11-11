<template>
  <div class="w-full">
    <label v-if="label" :for="inputId" class="mb-1.5 block text-sm font-medium text-gray-800">
      {{ label }}
    </label>

    <input
      :id="inputId"
      :type="type"
      :name="name"
      :placeholder="placeholder"
      :value="modelValue"
      :aria-invalid="variant === 'error' || !!error || undefined"
      :aria-describedby="error ? inputId + '-error' : undefined"
      class="field-control"
      :class="[
        (variant === 'error' || error) && 'field-control--error',
        variant === 'success' && 'field-control--success',
      ]"
      v-bind="$attrs"
      @input="updateValue"
    />

    <p v-if="error" :id="inputId + '-error'" class="mt-1.5 text-sm text-bad-700">{{ error }}</p>
  </div>
</template>

<script setup>
import { computed, useId } from 'vue'

defineOptions({ inheritAttrs: false })

const props = defineProps({
  modelValue:  { type: [String, Number], default: '' },
  type:        { type: String, default: 'text' },
  name:        { type: String, default: '' },
  placeholder: { type: String, default: '' },
  label:       { type: String, default: '' },
  error:       { type: String, default: '' },
  variant:     { type: String, default: 'default' }, // 'default' | 'success' | 'error'
})

const emit = defineEmits(['update:modelValue'])

const autoId = useId()
const inputId = computed(() => props.name || autoId)

const updateValue = (event) => {
  emit('update:modelValue', event.target.value)
}
</script>
