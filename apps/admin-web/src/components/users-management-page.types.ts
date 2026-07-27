import type { Dictionary, Locale } from "@/lib/i18n";

export type UsersManagementPageProps = {
  locale: Locale;
};

export type AccountStatus = "active" | "blocked" | "unconfirmed";

export type RangeDays = 7 | 30 | 90;

export type RoleFilter = "all" | "Admin" | "Moderator" | "User";
export type PremiumFilter = "all" | "premium" | "free";
export type StatusFilter = "all" | "active" | "blocked" | "unconfirmed";
export type UserSortMode =
  "created_desc" | "created_asc" | "last_activity_desc" | "last_activity_asc";

export type UserRoleText = Pick<Dictionary, "userRoleAdmin" | "userRoleModerator" | "userRoleUser">;
