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
        globPatterns: ["**/*.{js,css,html,ico,png,svg,xml}"],
      },
      includeAssets: ["/assets/favicon.ico/*"],
      manifest: {
        name: "image-prompts-to-commands",
        short_name: "imagprmptr",
        description:
          "Convert image prompts as JSON array of strings to Midjourney commands App.",
        scope: "/CopyImagePrompt/",
        start_url: "/CopyImagePrompt/",
        icons: [
          {
            src: "/assets/favicon.ico/android-chrome-192x192.png",
            sizes: "192x192",
            type: "image/png",
          },
          {
            src: "/assets/favicon.ico/android-chrome-512x512.png",
            sizes: "512x512",
            type: "image/png",
          },
          {
            src: "/assets/favicon.ico/android-chrome-512x512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "any",
          },
          {
            src: "/assets/favicon.ico/android-chrome-512x512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "maskable",
          },
        ],
        theme_color: "#ffffff",
        background_color: "#ffffff",
        display: "standalone",
      },
    }),
  ],
  publicDir: "public",
  build: {
    outDir: "_site",
  },
  base: "/CopyImagePrompt",
});
