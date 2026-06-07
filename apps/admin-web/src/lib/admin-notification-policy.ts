export type NotificationPolicyTone = "info" | "success" | "warning" | "error";

export function isActionableAdminNotification(input: {
  source: string;
  tone: NotificationPolicyTone;
}) {
  if (input.source === "support-realtime") {
    return true;
  }

  return input.tone === "error" || input.tone === "warning";
}

export function shouldCreateSupportRealtimeNotification(input: {
  currentPath: string;
  conversationId: string;
  isDocumentVisible: boolean;
  isWindowFocused: boolean;
}) {
  const activeConversationPath = `/support/${encodeURIComponent(input.conversationId)}`;
  const isSameConversationOpen = input.currentPath === activeConversationPath;

  if (!isSameConversationOpen) {
    return true;
  }

  return !input.isDocumentVisible || !input.isWindowFocused;
}
