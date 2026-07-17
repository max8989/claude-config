import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import { VitePWA } from "vite-plugin-pwa"

// injectManifest strategy: Workbox precaches the built assets but the service
// worker itself is our own src/sw.ts (so it can carry the Web Push handlers).
// registerType "prompt" pairs with components/ReloadPrompt — a new SW waits
// until the user accepts the reload toast rather than swapping assets under a
// running page. Regenerate icons/colors from the skill's answers.
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      strategies: "injectManifest",
      srcDir: "src",
      filename: "sw.ts",
      registerType: "prompt",
      manifest: {
        name: "__APP_NAME__",
        short_name: "__APP_SHORT_NAME__",
        description: "__APP_DESC__",
        lang: "__APP_LANG__",
        start_url: "/",
        display: "standalone",
        background_color: "__BG_LIGHT__",
        theme_color: "__ACCENT__",
        icons: [
          { src: "/icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "/icon-512.png", sizes: "512x512", type: "image/png" },
          { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
        ],
      },
    }),
  ],
  build: {
    // Vendor code changes far less often than app code — keep it in its own
    // chunks so redeploys don't re-download the whole framework.
    rollupOptions: {
      output: {
        manualChunks: {
          ionic: ["@ionic/react", "@ionic/react-router", "ionicons"],
          react: ["react", "react-dom", "react-router-dom"],
          data: ["@tanstack/react-query", "pocketbase"],
        },
      },
    },
  },
  server: {
    // The Node API (npm run dev in api/, port 3000) fronts everything,
    // including the PocketBase auth passthrough.
    proxy: { "/api": "http://localhost:3000" },
  },
})
