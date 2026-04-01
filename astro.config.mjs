// @ts-check
import { defineConfig } from 'astro/config';
import icon from "astro-icon";
import sitemap from "@astrojs/sitemap";
import compressor from "astro-compressor";

// https://astro.build/config
export default defineConfig({
  site: 'https://bartabacchichantilly.it',
  output: 'static',
  compressHTML: true,
  prefetch: {
    prefetchAll: false,
    defaultStrategy: 'viewport',
  },
  build: {
    inlineStylesheets: 'auto',
    assets: '_astro',
  },
  vite: {
    build: {
      cssMinify: 'lightningcss',
      minify: 'terser',
    },
  },
  integrations: [
    icon({
      include: {
        mdi: ["*"],
      }
    }),
    sitemap(),
    compressor({ gzip: true, brotli: true }),
  ],
});
