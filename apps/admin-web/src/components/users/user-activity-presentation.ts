import type { UserDetailWorkspaceText } from "@/components/users/user-detail-page.content";
import type { AdminUserActivityItem } from "@/lib/api-client";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type UserActivityPresentation = {
  title: string;
  details?: string;
};

function isSuccessfulActivity(title: string) {
  return title.includes("succeeded") || title.includes("completed");
}

function getAuditActivityTitle(title: string, text: UserDetailWorkspaceText) {
  switch (title) {
    case "user.legal_documents.accepted":
      return text.activityDocumentsAccepted;
    case "auth.external_login_succeeded":
      return text.activityExternalLogin;
    case "auth.login.succeeded":
      return text.activityLogin;
    case "auth.login.failed":
      return text.activityFailedLogin;
    case "user.profile.updated":
    case "user.avatar.updated":
    case "user.avatar.removed":
      return text.activityProfileUpdated;
    case "user.blocked":
    case "user.unblocked":
    case "user.role.assigned":
    case "user.role.revoked":
    case "user.premium.updated":
      return text.activityAccessUpdated;
    default:
      return text.activitySystem;
  }
}

export function getUserActivityPresentation(
  item: Pick<AdminUserActivityItem, "kind" | "title" | "details">,
  text: UserDetailWorkspaceText
): UserActivityPresentation {
  const kind = item.kind.trim().toLowerCase();
  const title = item.title.trim().toLowerCase();
  const safeDetails = sanitizeSensitiveText(item.details ?? "", 180);

  switch (kind) {
    case "purchase":
      return {
        title: isSuccessfulActivity(title) ? text.activityPurchaseCompleted : text.activityPurchase,
        details: safeDetails || undefined,
      };
    case "wallet":
      return { title: text.activityWallet };
    case "generation":
      return {
        title: title.includes("failed") ? text.activityGenerationFailed : text.activityGeneration,
        details: safeDetails || undefined,
      };
    case "template-event":
      return { title: text.activityTemplate, details: safeDetails || undefined };
    case "audit":
      return { title: getAuditActivityTitle(title, text) };
    default:
      return { title: text.activitySystem };
  }
}
