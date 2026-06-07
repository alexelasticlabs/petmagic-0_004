import type { SupportConversationSource, SupportConversationStatus } from "@/lib/api-client";
import type { Dictionary } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type StatusActionDescriptor = {
  status: SupportConversationStatus;
  label: string;
  variant: "primary" | "secondary" | "danger";
};

export function statusLabel(status: string, text: Dictionary) {
  switch (normalizeStatus(status).toLowerCase()) {
    case "new":
      return text.supportStatusOpen;
    case "inprogress":
      return text.supportStatusInProgress;
    case "waitingforuser":
      return text.supportStatusWaitingForUser;
    case "closed":
      return text.supportStatusClosed;
    default:
      return sanitizeSensitiveText(status, 48);
  }
}

export function toneForStatus(status: string) {
  switch (normalizeStatus(status).toLowerCase()) {
    case "new":
      return "warning" as const;
    case "waitingforuser":
      return "primary" as const;
    case "inprogress":
      return "primary" as const;
    case "closed":
      return "neutral" as const;
    default:
      return "neutral" as const;
  }
}

export function statusHint(status: SupportConversationStatus, text: Dictionary) {
  switch (normalizeStatus(status)) {
    case "New":
      return text.supportStatusOpenHint;
    case "InProgress":
      return text.supportStatusInProgressHint;
    case "WaitingForUser":
      return text.supportStatusWaitingForUserHint;
    case "Closed":
      return text.supportStatusClosedHint;
    default:
      return text.supportConversationDescription;
  }
}

export function getAvailableStatusActions(
  status: SupportConversationStatus,
  text: Dictionary
): StatusActionDescriptor[] {
  switch (normalizeStatus(status)) {
    case "New":
      return [
        { status: "Closed", label: text.supportCloseConversationAction, variant: "secondary" },
      ];
    case "InProgress":
      return [
        { status: "Closed", label: text.supportCloseConversationAction, variant: "secondary" },
      ];
    case "WaitingForUser":
      return [
        {
          status: "Closed",
          label: text.supportCloseConversationAction,
          variant: "secondary",
        },
      ];
    case "Closed":
      return [
        { status: "InProgress", label: text.supportReopenConversationAction, variant: "primary" },
      ];
    default:
      return [];
  }
}

export function sourceLabel(source: SupportConversationSource | string, text: Dictionary) {
  switch (source.toLowerCase()) {
    case "mobilechat":
    case "direct":
      return text.supportSourceMobileChat;
    case "mobileassistant":
      return text.supportSourceMobileAssistant;
    case "admincreated":
      return text.supportSourceAdminCreated;
    case "system":
      return text.supportSourceSystem;
    default:
      return text.supportSourceUnknown;
  }
}

export function priorityLabel(priority: string, text: Dictionary) {
  switch (priority.toLowerCase()) {
    case "critical":
      return text.supportPriorityCritical;
    case "high":
      return text.supportPriorityHigh;
    case "low":
      return text.supportPriorityLow;
    default:
      return text.supportPriorityNormal;
  }
}

export function priorityTone(priority: string) {
  switch (priority.toLowerCase()) {
    case "critical":
      return "danger" as const;
    case "high":
      return "warning" as const;
    case "low":
      return "neutral" as const;
    default:
      return "success" as const;
  }
}

export function toneForGeneration(status: string) {
  switch (status.toLowerCase()) {
    case "completed":
      return "success" as const;
    case "failed":
      return "danger" as const;
    case "processing":
      return "warning" as const;
    default:
      return "info" as const;
  }
}

function normalizeStatus(status: SupportConversationStatus | string): string {
  switch (status.toLowerCase()) {
    case "open":
    case "waitingforsupport":
      return "New";
    case "resolved":
      return "Closed";
    case "new":
      return "New";
    case "inprogress":
      return "InProgress";
    case "waitingforuser":
      return "WaitingForUser";
    case "closed":
      return "Closed";
    default:
      return status;
  }
}
