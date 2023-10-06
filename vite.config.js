import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";
import sassPlugin from "vite-plugin-sass";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    elmPlugin(),
    sassPlugin(),
    VitePWA({
      registerType: "autoUpdate",
      devOptions: {
        enabled: true,
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,ico,png,svg,xml,webmanifest}"]
      }
    }),
  ],
  build: {
    outDir: "_site",
  },
  base: "/CopyImagePrompt",
});
