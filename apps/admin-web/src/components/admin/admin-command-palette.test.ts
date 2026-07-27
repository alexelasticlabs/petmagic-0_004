import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const palettePath = fileURLToPath(new URL("./admin-command-palette.tsx", import.meta.url));
const contentPath = fileURLToPath(new URL("./admin-chrome.content.ts", import.meta.url));
const stylesPath = fileURLToPath(new URL("./admin-command-palette.module.css", import.meta.url));

describe("admin command palette integration contract", () => {
  it("keeps user lookup Admin-only, debounced, bounded, and abortable", () => {
    const source = readFileSync(palettePath, "utf8");

    expect(source).toContain('const canSearchUsers = roles.includes("Admin");');
    expect(source).toContain("ADMIN_COMMAND_USER_SEARCH_DEBOUNCE_MS");
    expect(source).toContain("take: ADMIN_COMMAND_USER_RESULT_LIMIT");
    expect(source).toContain("queryKey: adminQueryKeys.commandUsers(debouncedUserQuery)");
    expect(source).toContain("queryFn: ({ signal }) => fetchUsers(userSearchQueryParams, signal)");
    expect(source).toContain("enabled: canSearchUsers && isUserSearchQueryEnabled");
  });

  it("limits selection handling to the combobox so Enter remains native on controls", () => {
    const source = readFileSync(palettePath, "utf8");
    const dialogHandler = source.slice(
      source.indexOf("function handleDialogKeyDown"),
      source.indexOf('document.addEventListener("keydown", handleDialogKeyDown)')
    );
    const searchHandler = source.slice(
      source.indexOf("function handleSearchKeyDown"),
      source.indexOf("function renderResult")
    );

    expect(dialogHandler).toContain('event.key === "Escape"');
    expect(dialogHandler).toContain('event.key !== "Tab"');
    expect(dialogHandler).not.toContain('event.key === "Enter"');
    expect(dialogHandler).not.toContain('event.key === "ArrowDown"');
    expect(searchHandler).toContain('event.key === "Enter" && activeResult');
    expect(searchHandler).toContain('event.key === "ArrowDown"');
    expect(source).toContain("onKeyDown={handleSearchKeyDown}");
    expect(source).toContain("onClick={onClose}");
  });

  it("implements the combobox/listbox relationship and responsive search states", () => {
    const source = readFileSync(palettePath, "utf8");
    const content = readFileSync(contentPath, "utf8");
    const styles = readFileSync(stylesPath, "utf8");

    expect(source).toContain('role="combobox"');
    expect(source).toContain('aria-autocomplete="list"');
    expect(source).toContain('aria-haspopup="listbox"');
    expect(source).toContain("aria-expanded={true}");
    expect(source).toContain("aria-controls={resultsId}");
    expect(source).toContain("aria-activedescendant={activeOptionId}");
    expect(source).toContain("getAdminCommandPaletteOptionId(resultsId, activeResultKey)");
    expect(source).toContain("getAdminCommandPaletteOptionId(resultsId, result.key)");
    expect(source).toContain("[activeOptionId, activeResultKey]");
    expect(source).toContain('role="listbox"');
    expect(source).toContain("aria-labelledby={resultsLabelId}");
    expect(source).toContain("aria-busy={isUserSearchBusy}");
    expect(source).toContain("navigationResults.length > 0");
    expect(source).toContain("isUserSearchError");
    expect(source).toContain("isUserSearchEmpty");
    expect(source).toContain("userSearchQuery.refetch()");
    expect(content).toContain('usersLoading: "Ищем пользователей"');
    expect(content).toContain('usersErrorTitle: "Не удалось найти пользователей"');
    expect(content).toContain('usersEmptyTitle: "Пользователи не найдены"');
    expect(content).toContain('usersLoading: "Searching users"');
    expect(styles).toContain(".userSearchState {");
    expect(styles).toContain(".userSearchStateError {");
    expect(styles).toContain("@media (max-width: 420px)");
    expect(styles).toContain("@media (prefers-reduced-motion: reduce)");
  });
});
