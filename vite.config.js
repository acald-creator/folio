import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [vue()],
  publicDir: false,
  build: {
    outDir: "app/assets/builds",
    emptyOutDir: false,
    rollupOptions: {
      input: "frontend/main.js",
      output: {
        entryFileNames: "folio.js",
        chunkFileNames: "folio-[name].js",
        assetFileNames: "folio[extname]",
        format: "es"
      }
    }
  }
})
