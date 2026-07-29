import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const pagePath = fileURLToPath(new URL("./gamification-page.tsx", import.meta.url));
const stylesPath = fileURLToPath(new URL("./gamification-page.module.css", import.meta.url));
const routePath = fileURLToPath(new URL("../app/[locale]/gamification/page.tsx", import.meta.url));

describe("gamification-page visual and safety contract", () => {
  it("exposes real metrics, challenges, achievements, and user diagnostics", () => {
    const source = readFileSync(pagePath, "utf8");

    expect(source).toContain("fetchAdminGamificationDashboardMetrics");
    expect(source).toContain("fetchAdminGamificationChallenges");
    expect(source).toContain("fetchAdminGamificationAchievements");
    expect(source).toContain("fetchAdminUserGamificationOverview");
    expect(source).toContain("fetchUsers");
    expect(source).toContain("<AdminEntityLink");
    expect(source).not.toContain("isValidGamificationUserId");
    expect(source).toContain("userOverview.history");
    expect(source).toContain("item.definitionVersion");
    expect(source).toContain('role="progressbar"');
    expect(source).toContain('role="region"');
    expect(source).not.toContain("mock");
    expect(source).not.toContain("Math.random");
  });

  it("keeps streak reset explicit, reasoned, and confirmed", () => {
    const source = readFileSync(pagePath, "utf8");

    expect(source).toContain("validateGamificationResetReason(resetReason)");
    expect(source).toContain("<ConfirmationDialog");
    expect(source).toContain("resetAdminUserGamificationStreak");
    expect(source).toContain("dialogReasonLabel");
    expect(source).not.toContain("onClick={() => resetAdminUserGamificationStreak");
  });

  it("preserves a usable source order across desktop and mobile layouts", () => {
    const source = readFileSync(pagePath, "utf8");
    const css = readFileSync(stylesPath, "utf8");

    expect(source.indexOf("gamification-challenges-title")).toBeLessThan(
      source.indexOf("gamification-diagnostics-title")
    );
    expect(source.indexOf("gamification-diagnostics-title")).toBeLessThan(
      source.indexOf("gamification-achievements-title")
    );
    expect(css).toContain('grid-template-areas:\n    "challenges diagnostics"');
    expect(css).toContain("@media (max-width: 1080px)");
    expect(css).toContain('"challenges"\n      "diagnostics"\n      "achievements"');
    expect(css).toContain("@media (max-width: 720px)");
    expect(css).toContain("@media (max-width: 420px)");
  });

  it("keeps route identity in the shared topbar and starts with operational context", () => {
    const source = readFileSync(pagePath, "utf8");

    expect(source).toContain("<AdminContextBar");
    expect(source).not.toContain("gamification-workspace-title");
    expect(source).not.toContain("<AdminPageHero");
    expect(source).not.toContain("<h1");
  });

  it("keeps partial data visible while each unfinished query renders its own loading state", () => {
    const source = readFileSync(pagePath, "utf8");

    expect(source).toContain("const isMetricsInitialLoading = metricsQuery.isPending && !metrics;");
    expect(source).toContain(
      "const isChallengesInitialLoading = challengesQuery.isPending && !challengesQuery.data;"
    );
    expect(source).toContain(
      "const isAchievementsInitialLoading = achievementsQuery.isPending && !achievementsQuery.data;"
    );
    expect(source).toContain("{isMetricsInitialLoading ? (");
    expect(source).toContain("{isChallengesInitialLoading ? (");
    expect(source).toContain("{isAchievementsInitialLoading ? (");
    expect(source).not.toContain(
      "metricsQuery.isPending && challengesQuery.isPending && achievementsQuery.isPending"
    );
  });

  it("uses semantic warning contrast without a brittle sticky topbar offset", () => {
    const css = readFileSync(stylesPath, "utf8");

    expect(css).toContain("background: color-mix(in srgb, var(--warning) 10%, var(--surface-2));");
    expect(css).toContain("color: var(--warning-soft-fg);");
    expect(css).not.toContain("position: sticky;");
  });

  it("keeps dense tables readable on desktop and makes horizontal scrolling explicit on mobile", () => {
    const source = readFileSync(pagePath, "utf8");
    const css = readFileSync(stylesPath, "utf8");

    expect(source).toContain("gamification-challenges-table-scroll-hint");
    expect(source).toContain("gamification-achievements-table-scroll-hint");
    expect(source).toContain("text.tableScrollHint");
    expect(source).toContain("className={`${styles.table} ${styles.achievementTable}`}");
    expect(css).toContain(".achievementTable {");
    expect(css).toContain("table-layout: fixed;");
    expect(css).toContain(".achievementTable th:nth-child(6)");
    expect(css).toContain(".tableScrollHint {");
    expect(css).toContain("scrollbar-gutter: stable;");
    expect(css).toContain("min-width: 44rem;");
  });

  it("registers a locale-aware route instead of rendering an isolated prototype", () => {
    const route = readFileSync(routePath, "utf8");

    expect(route).toContain('import { GamificationPage } from "@/components/gamification-page";');
    expect(route).toContain("if (!isLocale(locale))");
    expect(route).toContain("<GamificationPage locale={locale} />");
  });
});
