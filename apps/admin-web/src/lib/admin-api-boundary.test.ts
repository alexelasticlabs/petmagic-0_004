import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const appRoot = fileURLToPath(new URL("../..", import.meta.url));
const srcRoot = join(appRoot, "src");
const scriptsRoot = join(appRoot, "scripts");
const packageJsonPath = join(appRoot, "package.json");

const forbiddenPackages = [
  "@aws-sdk/client-rds-data",
  "@mikro-orm/core",
  "@mikro-orm/mongodb",
  "@mikro-orm/postgresql",
  "@neondatabase/serverless",
  "@planetscale/database",
  "@prisma/client",
  "@supabase/postgrest-js",
  "@supabase/supabase-js",
  "@vercel/postgres",
  "better-sqlite3",
  "drizzle-kit",
  "drizzle-orm",
  "kysely",
  "knex",
  "mariadb",
  "mikro-orm",
  "mssql",
  "mongoose",
  "mongodb",
  "mysql",
  "mysql2",
  "pg",
  "prisma",
  "postgres",
  "redis",
  "sequelize",
  "slonik",
  "sqlite",
  "sqlite3",
  "typeorm",
];

const forbiddenSourcePatterns = [
  /\bDATABASE_URL\b/,
  /\bConnectionStrings\b/,
  /\bDbContext\b/,
  /\bEntityManager\b/,
  /\bKnex\b/,
  /\bNpgsql\b/,
  /\bPrismaClient\b/,
  /\bSequelize\b/,
  /\bcreateClient\(\s*process\.env\.DATABASE_URL\b/,
  /\bcreateConnection\b/,
  /\bcreateClient\(\s*\{?\s*url:\s*process\.env\.DATABASE_URL\b/,
  /\bdrizzle\s*\(/,
  /\bkysely\b/i,
  /\bPetMagic\.(?:Application|Host|Infrastructure|Modules)\b/,
  /(?:^|[\\/])backend[\\/]src[\\/]/i,
  /from\s+["'][^"']*(?:backend[\\/]src|src[\\/]Host|src[\\/]Modules|PetMagic\.(?:Application|Host|Infrastructure|Modules))[^"']*["']/,
  /require\(\s*["'][^"']*(?:backend[\\/]src|src[\\/]Host|src[\\/]Modules|PetMagic\.(?:Application|Host|Infrastructure|Modules))[^"']*["']\s*\)/,
  /\bsql\s*`(?:\s|--|\/\*|select|insert|update|delete)/i,
  /from\s+["'](?:@aws-sdk\/client-rds-data|@neondatabase\/serverless|@planetscale\/database|@prisma\/client|@supabase\/supabase-js|@vercel\/postgres|better-sqlite3|drizzle-orm|kysely|knex|mongodb|mysql2?|pg|postgres|sequelize|slonik|sqlite3?|typeorm)["']/,
];

function listSourceFiles(directory: string): string[] {
  return readdirSync(directory)
    .flatMap((name) => {
      const path = join(directory, name);
      const stats = statSync(path);

      if (stats.isDirectory()) {
        return listSourceFiles(path);
      }

      return /\.(ts|tsx|js|jsx)$/.test(name) ? [path] : [];
    })
    .filter((path) => !path.endsWith(".test.ts") && !path.endsWith(".test.tsx"));
}

function listAdminCodeFiles(): string[] {
  return [srcRoot, scriptsRoot].flatMap((directory) => listSourceFiles(directory));
}

describe("admin API boundary", () => {
  it("does not depend on direct database client packages", () => {
    const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8")) as {
      dependencies?: Record<string, string>;
      devDependencies?: Record<string, string>;
    };
    const dependencyNames = new Set([
      ...Object.keys(packageJson.dependencies ?? {}),
      ...Object.keys(packageJson.devDependencies ?? {}),
    ]);

    for (const packageName of forbiddenPackages) {
      expect(
        dependencyNames.has(packageName),
        `${packageName} must stay behind the backend API`
      ).toBe(false);
    }
  });

  it("keeps admin source routed through HTTP API clients instead of database access", () => {
    const violations: string[] = [];

    for (const file of listAdminCodeFiles()) {
      const source = readFileSync(file, "utf8");
      for (const pattern of forbiddenSourcePatterns) {
        if (pattern.test(source)) {
          violations.push(`${relative(appRoot, file)} matches ${pattern}`);
        }
      }
    }

    expect(violations).toEqual([]);
  });
});
