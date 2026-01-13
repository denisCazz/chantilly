// @ts-check
import { defineConfig } from 'astro/config';
import icon from "astro-icon";
import react from "@astrojs/react";

// https://astro.build/config
export default defineConfig({
  site: 'https://bartabacchichantilly.it',
  integrations: [
    icon({
      include: {
        mdi: ["*"],
      }
    }),
    react()
  ]
});
