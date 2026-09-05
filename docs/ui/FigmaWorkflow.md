# PetMagic Admin: Figma workflow

`Current` is a capture of the working UI. It is evidence, not an approved visual baseline. `Target` is the manually approved Figma frame that may drive a later implementation.

Current Figma workspace: [PetMagic Admin UI](https://www.figma.com/design/xxJP2rlARhKutxBvE37kXu).

Current reference frame: [Templates — Original PoC](https://www.figma.com/design/xxJP2rlARhKutxBvE37kXu?node-id=4-2).

The editable current-state atlas is split by the production admin navigation:

- `00 Global UI` — command palette, notification/language menus, logout confirmation and collapsed sidebar;
- `01 Dashboard` — light and dark states;
- `02 Customers & Access` — Users, Roles and User 360 tabs/panels;
- `03 Operations` — Audit, Moderation, Support, Generations, Feedback, Notifications and Operations;
- `04 Content Studio` — Templates catalogs, Video/Image editors, filters/menus, Analytics, Categories and Daily Featured;
- `05 Revenue & Risk` — all Economy workspaces;
- `06 Growth & Rewards` — Promo Codes and Gamification.

Every captured state is a `1536px` editable Figma frame built from synthetic Playwright fixtures. Do not capture production user records into the design file.

## Existing UI to Figma

1. Start the existing admin: `npm --prefix apps/admin-web run dev`.
2. Open the required local route and complete the existing Admin sign-in flow.
3. In Codex, use the official Figma plugin to capture the live page into the existing `PetMagic Admin UI` design file.
4. Keep the capture on the matching atlas page and give the frame a state-specific name such as `Templates — Create Menu`.
5. Duplicate the required `Current` frame as `Target`; edit only `Target` in Figma.

For repeatable synthetic captures, `apps/admin-web/e2e/figma-capture.ts` reads single-use capture IDs from `FIGMA_CAPTURE_MAP_JSON`. Without that environment variable the helper is a no-op and the normal E2E behavior and timeout remain unchanged.

Use the official remote Figma MCP (`https://mcp.figma.com/mcp`) through Codex OAuth. Do not add a Personal Access Token or an unofficial MCP server while that integration is available.

## Figma to Codex

1. Select the approved `Target` frame in Figma and choose **Copy link to selection**.
2. Give the node-specific URL to Codex.
3. Codex reads the frame with Figma design context, maps it to the components below, and changes the existing implementation only.
4. Preserve routes, API contracts, state handling, localization, RBAC and business logic.

Suggested prompt:

> Возьми этот Figma Target frame и приведи существующую страницу X к нему, не изменяя business logic, API contracts и routing; переиспользуй существующие components и tokens, затем запусти `npm --prefix apps/admin-web run ui:verify -- templates`.

## Code to QA

Run:

```powershell
npm --prefix apps/admin-web run ui:verify -- templates
```

The command builds an isolated Next.js output, starts the real admin UI, opens the Templates route in Chromium at `1536×1024`, checks DOM geometry and saves screenshots under `apps/admin-web/test-results/`. Artifacts are temporary and must not be treated as golden baselines or committed by default.

## Existing component map

| UI concept        | Existing source                                                                                                 |
| ----------------- | --------------------------------------------------------------------------------------------------------------- |
| AppShell / Layout | `apps/admin-web/src/components/admin-shell.tsx`                                                                 |
| Sidebar           | `apps/admin-web/src/components/admin/admin-sidebar.tsx`                                                         |
| Header            | `apps/admin-web/src/components/admin/admin-topbar.tsx`                                                          |
| Button            | `apps/admin-web/src/components/ui/button.tsx`; base styles in `src/app/globals.css`                             |
| Input             | Native feature inputs; shared tokens/reset in `src/app/globals.css`                                             |
| Select            | `apps/admin-web/src/components/ui/select.tsx`; `AdminSelectField` in `admin/admin-primitives.tsx`               |
| Tabs              | Semantic links/buttons owned by each feature; Templates tabs are in `templates/templates-catalog-workspace.tsx` |
| Card              | `AdminCard` in `admin/admin-primitives.tsx`                                                                     |
| Badge / Status    | `AdminBadge` and `AdminStatusBadge` in `admin/admin-primitives.tsx`                                             |
| Pagination        | `apps/admin-web/src/components/admin/admin-pagination.tsx`; Templates currently has feature pagination          |
| RightRail         | `TemplatesCatalogRail` in `templates/templates-catalog-workspace.tsx`                                           |
| TemplateCard      | `TemplateCatalogCard` in `templates/templates-catalog-view.card.tsx`                                            |

No Code Connect mapping files are currently present. That is not a blocker: Figma design context plus this source map is the default bridge.
