import { getMessageAttachments } from "@/components/support/support-conversation-helpers";
import type { AdminSupportConversation } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

export type SupportConversationPageProps = {
  locale: Locale;
  conversationId: string;
  navigationMode?: "route" | "local";
  onConversationSelect?: (conversationId: string) => void;
};

export type FullscreenImage = {
  mediaType?: "image" | "video";
  attachmentFileUrl: string;
  fileName?: string | null;
  messageId?: string;
  senderDisplayName?: string | null;
  createdAtUtc?: string | null;
  fileSizeBytes?: number | null;
  durationSeconds?: number | null;
};

export type SupportMessage = AdminSupportConversation["messages"][number];
export type SupportMessageAttachment = ReturnType<typeof getMessageAttachments>[number];
