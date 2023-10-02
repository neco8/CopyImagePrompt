import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";
import sassPlugin from "vite-plugin-sass";

export default defineConfig({
  plugins: [elmPlugin(), sassPlugin()],
  build: {
    outDir: "_site",
    assetsDir: ".",
  },
  base: "CopyImagePrompt",
});
