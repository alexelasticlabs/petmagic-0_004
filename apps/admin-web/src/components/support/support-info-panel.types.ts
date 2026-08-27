import type { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import type { Locale } from "@/lib/i18n";

export type SupportConversationController = ReturnType<typeof useSupportConversationController>;
export type SupportConversationText = SupportConversationController["text"];

export type SupportInfoPanelProps = {
  locale: Locale;
  controller: SupportConversationController;
  claimRequestId?: number;
};
