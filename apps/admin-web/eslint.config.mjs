import { defineConfig, globalIgnores } from "eslint/config";
import importPlugin from "eslint-plugin-import";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    files: ["src/**/*.{ts,tsx}"],
    plugins: {
      import: importPlugin,
    },
    rules: {
      "no-console": [
        "warn",
        {
          allow: ["error", "warn"],
        },
      ],
      "import/no-duplicates": "error",
      "import/newline-after-import": "warn",
      "import/order": [
        "warn",
        {
          alphabetize: {
            order: "asc",
            caseInsensitive: true,
          },
          groups: [["builtin", "external"], ["internal"], ["parent", "sibling", "index"], ["type"]],
          "newlines-between": "always",
          pathGroups: [
            {
              pattern: "@/**",
              group: "internal",
              position: "before",
            },
          ],
          pathGroupsExcludedImportTypes: ["builtin"],
        },
      ],
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    ".next-e2e/**",
    ".next-*/**",
    "out/**",
    "build/**",
    "coverage/**",
    "test-results/**",
    "playwright-report/**",
    "blob-report/**",
    // Production build and test artifacts are generated code, not application source.
    "artifacts/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
