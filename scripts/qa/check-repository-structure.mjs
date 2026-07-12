#!/usr/bin/env node

import { readdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];

const gitlinks = execFileSync("git", ["ls-files", "--stage", "-z"], {
  cwd: repositoryRoot,
  encoding: "utf8",
})
  .split("\0")
  .filter(Boolean)
  .filter((entry) => entry.startsWith("160000 "))
  .map((entry) => entry.slice(entry.indexOf("\t") + 1));

if (gitlinks.length > 0) {
  failures.push(`Gitlinks are not permitted in this monorepo: ${gitlinks.join(", ")}`);
}

const ignoredDirectories = new Set([
  ".dart_tool",
  ".git",
  ".next",
  ".turbo",
  ".wrangler",
  "bin",
  "build",
  "dist",
  "node_modules",
  "obj",
]);

const nestedGitMetadata = findNestedGitMetadata(repositoryRoot);
if (nestedGitMetadata.length > 0) {
  failures.push(
    `Nested Git metadata is not permitted; move or remove it before committing: ${nestedGitMetadata.join(", ")}`,
  );
}

if (failures.length > 0) {
  console.error(`Repository structure validation failed:\n- ${failures.join("\n- ")}`);
  process.exit(1);
}

console.log("Repository structure validation passed.");

function findNestedGitMetadata(directory, relativeDirectory = "") {
  const matches = [];

  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === ".git") {
      if (relativeDirectory.length > 0) {
        matches.push(`${relativeDirectory}/.git`);
      }
      continue;
    }

    if (!entry.isDirectory() || ignoredDirectories.has(entry.name)) {
      continue;
    }

    const childRelativePath = relativeDirectory
      ? `${relativeDirectory}/${entry.name}`
      : entry.name;
    matches.push(...findNestedGitMetadata(resolve(directory, entry.name), childRelativePath));
  }

  return matches;
}
