import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import tailwind from '@tailwindcss/vite';
export default defineConfig({site:'https://l4l4dev.github.io',base:'/TIL',trailingSlash:'always',integrations:[sitemap()],vite:{plugins:[tailwind()]},markdown:{shikiConfig:{themes:{light:'github-light',dark:'dracula'}}}});
