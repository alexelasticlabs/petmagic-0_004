import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  getSupportReplyActor,
  getSupportActionErrorMessage,
  isSupportReplyActorCurrent,
  mergeSupportConversationMessages,
  rollbackOptimisticSupportMessage,
} from "@/components/support/support-conversation-controller.helpers";
import type { AdminSupportConversation } from "@/lib/api-client";

const mutationsPath = fileURLToPath(
  new URL("./support-conversation-controller.mutations.ts", import.meta.url)
);

function conversationPage(
  messages: Array<{ messageId: string; createdAtUtc: string }>,
  hasOlderMessages: boolean,
  oldestLoadedMessageCreatedAtUtc: string | null
): AdminSupportConversation {
  return {
    conversationId: "conversation-1",
    messages: messages.map((message) => ({
      ...message,
      conversationId: "conversation-1",
      senderUserId: "user-1",
      senderDisplayName: "Pet User",
      isFromAdmin: false,
      senderType: "User",
      body: message.messageId,
      isRead: true,
      isInternalNote: false,
    })),
    hasOlderMessages,
    oldestLoadedMessageCreatedAtUtc,
  } as AdminSupportConversation;
}

describe("mergeSupportConversationMessages", () => {
  it("moves the cursor to the older page instead of requesting the same page again", () => {
    const currentPage = conversationPage(
      [
        { messageId: "message-3", createdAtUtc: "2026-07-24T12:03:00.000Z" },
        { messageId: "message-4", createdAtUtc: "2026-07-24T12:04:00.000Z" },
      ],
      true,
      "2026-07-24T12:03:00.000Z"
    );
    const olderPage = conversationPage(
      [
        { messageId: "message-1", createdAtUtc: "2026-07-24T12:01:00.000Z" },
        { messageId: "message-2", createdAtUtc: "2026-07-24T12:02:00.000Z" },
      ],
      false,
      "2026-07-24T12:01:00.000Z"
    );

    const merged = mergeSupportConversationMessages(currentPage, olderPage, {
      replacePagination: true,
    });

    expect(merged.messages.map((message) => message.messageId)).toEqual([
      "message-1",
      "message-2",
      "message-3",
      "message-4",
    ]);
    expect(merged.hasOlderMessages).toBe(false);
    expect(merged.oldestLoadedMessageCreatedAtUtc).toBe("2026-07-24T12:01:00.000Z");
  });

  it("preserves the existing cursor when merging a realtime refresh", () => {
    const currentPage = conversationPage(
      [{ messageId: "message-3", createdAtUtc: "2026-07-24T12:03:00.000Z" }],
      true,
      "2026-07-24T12:03:00.000Z"
    );
    const realtimePage = conversationPage(
      [{ messageId: "message-4", createdAtUtc: "2026-07-24T12:04:00.000Z" }],
      false,
      null
    );

    const merged = mergeSupportConversationMessages(currentPage, realtimePage);

    expect(merged.hasOlderMessages).toBe(true);
    expect(merged.oldestLoadedMessageCreatedAtUtc).toBe("2026-07-24T12:03:00.000Z");
  });

  it("removes only the failed optimistic message after a realtime customer reply", () => {
    const currentConversation = conversationPage(
      [
        { messageId: "message-1", createdAtUtc: "2026-07-24T12:01:00.000Z" },
        { messageId: "optimistic-conversation-1-1", createdAtUtc: "2026-07-24T12:02:00.000Z" },
        { messageId: "message-2", createdAtUtc: "2026-07-24T12:03:00.000Z" },
      ],
      true,
      "2026-07-24T12:01:00.000Z"
    );
    currentConversation.lastMessagePreview = "A new customer reply";
    currentConversation.lastMessageSenderType = "User";
    currentConversation.lastMessageAtUtc = "2026-07-24T12:03:00.000Z";
    currentConversation.adminUnreadCount = 1;

    const rolledBack = rollbackOptimisticSupportMessage(
      currentConversation,
      "optimistic-conversation-1-1"
    );

    expect(rolledBack.messages.map((message) => message.messageId)).toEqual([
      "message-1",
      "message-2",
    ]);
    expect(rolledBack.lastMessagePreview).toBe("A new customer reply");
    expect(rolledBack.lastMessageSenderType).toBe("User");
    expect(rolledBack.lastMessageAtUtc).toBe("2026-07-24T12:03:00.000Z");
    expect(rolledBack.adminUnreadCount).toBe(1);

    const mutationsSource = readFileSync(mutationsPath, "utf8");
    const onErrorStart = mutationsSource.indexOf("onError: (error, variables, context) => {");
    const onErrorEnd = mutationsSource.indexOf("    onSettled:", onErrorStart);
    const onErrorSource = mutationsSource.slice(onErrorStart, onErrorEnd);

    expect(onErrorSource).toContain(
      "rollbackOptimisticSupportMessage(currentConversation, optimisticMessageId)"
    );
    expect(onErrorSource).toContain("void queryClient.invalidateQueries({ queryKey });");
    expect(onErrorSource).not.toContain("previousConversation");
  });
});

describe("support reply session actor", () => {
  it("does not treat a switched admin as the sender of a pending reply", () => {
    expect(getSupportReplyActor(null)).toBeNull();
    expect(getSupportReplyActor({ userId: "   " })).toBeNull();

    const actor = getSupportReplyActor({
      userId: "admin-a",
      displayName: "Admin A",
      email: "admin-a@example.com",
    });

    expect(actor).not.toBeNull();
    expect(isSupportReplyActorCurrent(actor, { userId: "admin-a" })).toBe(true);
    expect(isSupportReplyActorCurrent(actor, { userId: "admin-b" })).toBe(false);
    expect(isSupportReplyActorCurrent(actor, null)).toBe(false);

    const mutationsSource = readFileSync(mutationsPath, "utf8");
    expect(mutationsSource).toContain("if (!isReplyActorCurrent(actor)) {");
    expect(mutationsSource).toContain("if (!isReplyActorCurrent(variables.actor)) {");
    expect(mutationsSource).toContain("sendMutation.mutate({\n        actor,");
  });
});

describe("getSupportActionErrorMessage", () => {
  const text = {
    supportAttachmentRetryRequired: "Choose the attachment again.",
    supportAttachmentRetryUnavailable: "The attachment cannot be retried.",
    supportAttachmentTooLarge: "The attachment is too large.",
    supportAttachmentTypeInvalid: "Choose a supported attachment type.",
    supportMessageTooLong: "The message is too long.",
    supportReplyTargetInvalid: "The reply target is unavailable.",
  };

  it("maps Support attachment and reply problem codes without exposing transport text", () => {
    expect(getSupportActionErrorMessage({ code: "support.attachment_file_too_large" }, text)).toBe(
      text.supportAttachmentTooLarge
    );
    expect(getSupportActionErrorMessage({ code: "support.attachment_mime_mismatch" }, text)).toBe(
      text.supportAttachmentTypeInvalid
    );
    expect(
      getSupportActionErrorMessage({ validationErrors: ["support.reply_target_invalid"] }, text)
    ).toBe(text.supportReplyTargetInvalid);
  });

  it("falls back for unrelated or malformed codes", () => {
    expect(getSupportActionErrorMessage({ code: "templates.invalid" }, text)).toBeUndefined();
    expect(getSupportActionErrorMessage({ validationErrors: [null, 42] }, text)).toBeUndefined();
  });
});
