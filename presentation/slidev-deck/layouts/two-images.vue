<template>
  <div class="slidev-layout tpsm-two-image-slide">
    <h1><slot /></h1>
    <div class="two-image-grid">
      <img :src="imageA" alt="" />
      <img :src="imageB" alt="" />
    </div>
    <footer class="slide-mark">TPSM Project</footer>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  imageA: string
  imageB: string
}>()
</script>
