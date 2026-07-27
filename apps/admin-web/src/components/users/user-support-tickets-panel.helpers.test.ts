import { describe, expect, it } from "vitest";

import { getUserSupportTicketsPlaceholderData } from "@/components/users/user-support-tickets-panel.helpers";

describe("getUserSupportTicketsPlaceholderData", () => {
  it("keeps pagination data for the same user but never renders another user's tickets", () => {
    const userATickets = { items: [{ conversationId: "conversation-a" }] };
    const userAQueryKey = ["admin", "users", "user-a", "support", "tickets", 1, 20] as const;

    expect(getUserSupportTicketsPlaceholderData(userATickets, userAQueryKey, "user-a")).toBe(
      userATickets
    );
    expect(
      getUserSupportTicketsPlaceholderData(userATickets, userAQueryKey, "user-b")
    ).toBeUndefined();
  });
});
