<template>
  <div class="w-full">
    <!-- Label -->
    <label v-if="label" :for="name" class="block text-sm font-medium text-gray-700 mb-1">
      {{ label }}
    </label>

    <!-- Input -->
    <input
      :id="name"
      :type="type"
      :name="name"
      :placeholder="placeholder"
      :value="modelValue"
      @input="updateValue"
      class="w-full rounded-xl border px-4 py-2.5 text-gray-700 placeholder-gray-400 shadow-sm transition-all duration-200
        focus:outline-none focus:ring-2 focus:ring-offset-1
        disabled:opacity-50 disabled:cursor-not-allowed
        "
      :class="[
        variant === 'default' && 'border-gray-300 focus:ring-blue-500',
        variant === 'success' && 'border-green-400 focus:ring-green-500',
        variant === 'error' && 'border-red-400 focus:ring-red-500'
      ]"
    />

    <!-- Mensaje de error -->
    <p v-if="error" class="mt-1 text-sm text-red-600">{{ error }}</p>
  </div>
</template>

<script setup>
const props = defineProps({
  modelValue: {
    type: [String, Number],
    default: ''
  },
  type: {
    type: String,
    default: 'text'
  },
  name: {
    type: String,
    default: ''
  },
  placeholder: {
    type: String,
    default: ''
  },
  label: {
    type: String,
    default: ''
  },
  error: {
    type: String,
    default: ''
  },
  variant: {
    type: String,
    default: 'default' // 'default' | 'success' | 'error'
  }
});

const emit = defineEmits(['update:modelValue']);

const updateValue = (event) => {
  emit('update:modelValue', event.target.value);
};
</script>
