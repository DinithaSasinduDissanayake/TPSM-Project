<template>
  <div class="slidev-layout tpsm-image-slide">
    <h1><slot /></h1>
    <main>
      <img :src="image" alt="" />
    </main>
    <footer class="slide-mark">TPSM Project</footer>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  image: string
}>()
</script>
