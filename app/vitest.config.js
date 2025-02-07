import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./spec/javascript/test_setup.js'],
    include: ['spec/javascript/**/*.spec.js'],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./app"),
      "@js": path.resolve(__dirname, "./app/javascript"),
      "@test": path.resolve(__dirname, "./spec/javascript"),
    },
  },
  env: {
    NODE_ENV: "test",
  },
});
