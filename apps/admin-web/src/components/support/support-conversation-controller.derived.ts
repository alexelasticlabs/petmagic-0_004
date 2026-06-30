import {
  type SidePanelTab,
} from "@/components/support/support-conversation-controller.helpers";
import {
  buildActivityTimeline,
  buildConversationTimeline,
  formatSafeSupportDisplay,
  getConversationSla,
} from "@/components/support/support-conversation-helpers";
import { getAvailableStatusActions } from "@/components/support/support-status-helpers";
import {
  type AdminEconomyPurchase,
  type AdminSupportConversation,
  type AdminUserAnalytics,
  type AdminUserDetail,
} from "@/lib/api-client";
import { type Dictionary, type Locale } from "@/lib/i18n";
import { maskEmail } from "@/lib/sensitive-display";

type SupportConversationDerivedCopy = {
  deletedUserName: string;
  deletedUserEmail: string;
};

type SupportConversationDerivedParams = {
  locale: Locale;
  activeSidePanelTab: SidePanelTab;
  text: Dictionary;
  copy: SupportConversationDerivedCopy;
  conversation?: AdminSupportConversation;
  canViewSubjectUserContext: boolean;
  isSubjectUserDeleted: boolean;
  user?: AdminUserDetail;
  analytics?: AdminUserAnalytics;
  recentUserPurchases: AdminEconomyPurchase[];
};

export function getSupportConversationDerivedState({
  locale,
  activeSidePanelTab,
  text,
  copy,
  conversation,
  canViewSubjectUserContext,
  isSubjectUserDeleted,
  user,
  analytics,
  recentUserPurchases,
}: SupportConversationDerivedParams) {
  const userEmailDisplay = conversation?.userEmail?.trim()
    ? maskEmail(conversation.userEmail)
    : isSubjectUserDeleted
      ? copy.deletedUserEmail
      : "";
  const userDisplayName = conversation?.userDisplayName?.trim()
    ? formatSafeSupportDisplay(conversation.userDisplayName, text.supportConversationTitle, 72)
    : userEmailDisplay ||
      (isSubjectUserDeleted ? copy.deletedUserName : "") ||
      text.supportConversationTitle;

  const sidePanelTabs: ReadonlyArray<{ value: SidePanelTab; label: string }> = [
    { value: "user", label: text.supportViewUserTab },
    { value: "activity", label: text.supportViewActivityTab },
    { value: "dialog", label: text.supportViewDialogTab },
    { value: "attachments", label: text.supportViewAttachmentsTab },
  ];

  const sidePanelTitle =
    activeSidePanelTab === "user"
      ? text.supportUserInformationTitle
      : activeSidePanelTab === "activity"
        ? text.supportActivityTitle
        : activeSidePanelTab === "dialog"
          ? text.supportDialogTitle
          : text.supportAttachmentsTitle;

  const sidePanelDescription =
    activeSidePanelTab === "activity"
      ? text.supportActivityDescription
      : activeSidePanelTab === "dialog"
        ? text.supportDialogDescription
        : activeSidePanelTab === "attachments"
          ? text.supportAttachmentsDescription
          : null;

  const accountCreatedAt = user?.createdAtUtc ?? conversation?.createdAtUtc ?? null;
  const conversationWaitingSince =
    conversation?.waitingSinceUtc ??
    conversation?.lastMessageAtUtc ??
    conversation?.createdAtUtc ??
    null;
  const conversationSla = getConversationSla(
    conversationWaitingSince,
    locale,
    conversation?.adminUnreadCount ?? 0
  );
  const recentFailures = analytics?.failureBreakdown.slice(0, 4) ?? [];
  const failedGenerations =
    analytics?.recentGenerations.filter((generation) => generation.status.toLowerCase() === "failed") ??
    [];
  const totalPurchases = canViewSubjectUserContext
    ? (analytics?.summary.totalPurchases ?? recentUserPurchases.length)
    : 0;
  const lastUserPurchaseAtUtc =
    recentUserPurchases[0]?.confirmedAtUtc ?? recentUserPurchases[0]?.createdAtUtc ?? null;
  const lastActivityAtUtc =
    analytics?.summary.lastActivityAtUtc ??
    conversation?.lastMessageAtUtc ??
    conversation?.updatedAtUtc ??
    conversation?.createdAtUtc ??
    null;
  const activityTimeline = buildActivityTimeline(analytics);
  const availableStatusActions = conversation
    ? getAvailableStatusActions(conversation.status, text)
    : [];
  const primaryStatusAction =
    availableStatusActions.find((action) => action.variant === "primary") ?? null;
  const secondaryStatusActions = availableStatusActions.filter(
    (action) => action.variant === "secondary"
  );
  const destructiveStatusAction =
    availableStatusActions.find((action) => action.variant === "danger") ?? null;
  const conversationTimeline = buildConversationTimeline({
    conversation,
    userDisplayName,
    labels: {
      conversationCreated: text.supportTimelineConversationCreated,
      adminReply: text.supportTimelineAdminReply,
      userMessage: text.supportTimelineUserMessage,
    },
  });

  return {
    accountCreatedAt,
    activityTimeline,
    conversationSla,
    conversationTimeline,
    destructiveStatusAction,
    failedGenerations,
    lastActivityAtUtc,
    lastUserPurchaseAtUtc,
    operatorPriority: conversation?.priority ?? "Normal",
    operatorTags: conversation?.tags ?? [],
    primaryStatusAction,
    recentFailures,
    sidePanelDescription,
    sidePanelTabs,
    sidePanelTitle,
    secondaryStatusActions,
    totalPurchases,
    userDisplayName,
    userEmailDisplay,
  };
}
