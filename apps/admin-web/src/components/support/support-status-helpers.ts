import type { SupportConversationStatus } from "@/lib/api-client";
import type { Dictionary } from "@/lib/i18n";

export type StatusActionDescriptor = {
  status: SupportConversationStatus;
  label: string;
  variant: "primary" | "secondary" | "danger";
};

export function statusLabel(status: string, text: Dictionary) {
  switch (status.toLowerCase()) {
    case "open":
      return text.supportStatusOpen;
    case "inprogress":
      return text.supportStatusInProgress;
    case "waitingforsupport":
      return text.supportStatusWaitingForSupport;
    case "waitingforuser":
      return text.supportStatusWaitingForUser;
    case "resolved":
      return text.supportStatusResolved;
    case "closed":
      return text.supportStatusClosed;
    default:
      return status;
  }
}

export function toneForStatus(status: string) {
  switch (status.toLowerCase()) {
    case "open":
      return "warning" as const;
    case "waitingforsupport":
      return "warning" as const;
    case "waitingforuser":
      return "primary" as const;
    case "inprogress":
      return "primary" as const;
    case "resolved":
      return "success" as const;
    case "closed":
      return "neutral" as const;
    default:
      return "neutral" as const;
  }
}

export function statusHint(status: SupportConversationStatus, text: Dictionary) {
  switch (status) {
    case "Open":
      return text.supportStatusOpenHint;
    case "InProgress":
      return text.supportStatusInProgressHint;
    case "WaitingForSupport":
      return text.supportStatusWaitingForSupportHint;
    case "WaitingForUser":
      return text.supportStatusWaitingForUserHint;
    case "Resolved":
      return text.supportStatusResolvedHint;
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
  switch (status) {
    case "Open":
      return [
        {
          status: "WaitingForSupport",
          label: text.supportMarkWaitingForSupportAction,
          variant: "secondary",
        },
        {
          status: "WaitingForUser",
          label: text.supportMarkWaitingForUserAction,
          variant: "primary",
        },
        { status: "Resolved", label: text.supportResolveConversationAction, variant: "secondary" },
        { status: "Closed", label: text.supportCloseConversationAction, variant: "danger" },
      ];
    case "InProgress":
    case "WaitingForUser":
      return [
        { status: "Resolved", label: text.supportResolveConversationAction, variant: "primary" },
        {
          status: "WaitingForSupport",
          label: text.supportMarkWaitingForSupportAction,
          variant: "secondary",
        },
        { status: "Open", label: text.supportReopenConversationAction, variant: "secondary" },
        { status: "Closed", label: text.supportCloseConversationAction, variant: "danger" },
      ];
    case "WaitingForSupport":
      return [
        {
          status: "WaitingForUser",
          label: text.supportMarkWaitingForUserAction,
          variant: "primary",
        },
        { status: "Resolved", label: text.supportResolveConversationAction, variant: "secondary" },
        { status: "Closed", label: text.supportCloseConversationAction, variant: "danger" },
      ];
    case "Resolved":
      return [
        { status: "Open", label: text.supportReopenConversationAction, variant: "secondary" },
        { status: "Closed", label: text.supportCloseConversationAction, variant: "danger" },
      ];
    case "Closed":
      return [{ status: "Open", label: text.supportReopenConversationAction, variant: "primary" }];
    default:
      return [];
  }
}

export function priorityLabel(priority: string, text: Dictionary) {
  switch (priority.toLowerCase()) {
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
    case "high":
      return "danger" as const;
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
