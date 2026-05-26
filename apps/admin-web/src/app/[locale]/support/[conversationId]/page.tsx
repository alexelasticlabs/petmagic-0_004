import { notFound } from "next/navigation";

import { SupportConversationPage } from "@/components/support/support-conversation-page";
import { isLocale, type Locale } from "@/lib/i18n";

type SupportConversationRouteProps = {
  params: Promise<{ locale: string; conversationId: string }>;
};

export default async function SupportConversationRoute({ params }: SupportConversationRouteProps) {
  const resolved = await params;
  if (!isLocale(resolved.locale)) {
    notFound();
  }

  return (
    <SupportConversationPage
      locale={resolved.locale as Locale}
      conversationId={resolved.conversationId}
    />
  );
}
