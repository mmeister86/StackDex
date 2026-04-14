import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["convex/**/*.test.ts"],
    setupFiles: ["convex/test.setup.ts"],
  },
});
