import { type AdminSectionKey } from "@/lib/admin-navigation";

export type AdminPanelRole = "Admin" | "Moderator";

const moderatorSections = new Set<AdminSectionKey>([
  "support",
  "moderation",
  "feedback",
  "templates",
  "image-templates",
  "video-templates",
  "template-analytics",
  "template-categories",
]);

function matchesAdminPath(currentPath: string, targetPath: string): boolean {
  return currentPath === targetPath || currentPath.startsWith(`${targetPath}/`);
}

export function hasAdminPanelAccess(roles?: readonly string[] | null): boolean {
  return getAdminPanelRole(roles) !== null;
}

export function getAdminPanelRole(roles?: readonly string[] | null): AdminPanelRole | null {
  if (roles?.includes("Admin")) {
    return "Admin";
  }

  if (roles?.includes("Moderator")) {
    return "Moderator";
  }

  return null;
}

export function canAccessAdminSection(
  roles: readonly string[] | null | undefined,
  section: AdminSectionKey
): boolean {
  const role = getAdminPanelRole(roles);
  if (role === "Admin") {
    return true;
  }

  return role === "Moderator" && moderatorSections.has(section);
}

export function getDefaultAdminPath(locale: string, roles?: readonly string[] | null): string {
  const role = getAdminPanelRole(roles);
  if (role === "Moderator") {
    return `/${locale}/support`;
  }

  if (role === "Admin") {
    return `/${locale}/dashboard`;
  }

  return `/${locale}`;
}

export function canAccessAdminPath(
  roles: readonly string[] | null | undefined,
  currentPath: string
): boolean {
  if (currentPath === "/") {
    return true;
  }

  if (matchesAdminPath(currentPath, "/dashboard")) {
    return canAccessAdminSection(roles, "dashboard");
  }

  if (matchesAdminPath(currentPath, "/economy")) {
    return canAccessAdminSection(roles, "economy");
  }

  if (matchesAdminPath(currentPath, "/promo-codes")) {
    return canAccessAdminSection(roles, "promo-codes");
  }

  if (matchesAdminPath(currentPath, "/users")) {
    return canAccessAdminSection(roles, "users");
  }

  if (matchesAdminPath(currentPath, "/generations")) {
    return canAccessAdminSection(roles, "generations");
  }

  if (matchesAdminPath(currentPath, "/feedback")) {
    return canAccessAdminSection(roles, "feedback");
  }

  if (matchesAdminPath(currentPath, "/roles")) {
    return canAccessAdminSection(roles, "role-management");
  }

  if (matchesAdminPath(currentPath, "/support")) {
    return canAccessAdminSection(roles, "support");
  }

  if (matchesAdminPath(currentPath, "/moderation")) {
    return canAccessAdminSection(roles, "moderation");
  }

  if (matchesAdminPath(currentPath, "/templates/categories")) {
    return canAccessAdminSection(roles, "template-categories");
  }

  if (matchesAdminPath(currentPath, "/templates/daily-featured")) {
    return canAccessAdminSection(roles, "template-daily-featured");
  }

  if (matchesAdminPath(currentPath, "/templates/analytics")) {
    return canAccessAdminSection(roles, "template-analytics");
  }

  if (
    matchesAdminPath(currentPath, "/templates/image/editor") ||
    matchesAdminPath(currentPath, "/templates/video/editor") ||
    matchesAdminPath(currentPath, "/templates/image/test") ||
    matchesAdminPath(currentPath, "/templates/video/test")
  ) {
    return getAdminPanelRole(roles) === "Admin";
  }

  if (
    matchesAdminPath(currentPath, "/templates/image") ||
    matchesAdminPath(currentPath, "/image-templates")
  ) {
    return canAccessAdminSection(roles, "image-templates");
  }

  if (
    matchesAdminPath(currentPath, "/templates/video") ||
    matchesAdminPath(currentPath, "/video-templates")
  ) {
    return canAccessAdminSection(roles, "video-templates");
  }

  if (matchesAdminPath(currentPath, "/templates")) {
    return canAccessAdminSection(roles, "templates");
  }

  return getAdminPanelRole(roles) === "Admin";
}
