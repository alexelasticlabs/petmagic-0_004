import { describe, expect, it } from "vitest";

import { getUserActivityPresentation } from "@/components/users/user-activity-presentation";
import { getUserDetailWorkspaceText } from "@/components/users/user-detail-page.content";

describe("user activity presentation", () => {
  it("translates known audit keys into administrator-facing language", () => {
    const text = getUserDetailWorkspaceText("ru");

    expect(
      getUserActivityPresentation(
        {
          kind: "audit",
          title: "user.legal_documents.accepted",
          details: "Accepted terms v1 and privacy v1.",
        },
        text
      )
    ).toEqual({ title: "Подтверждены документы" });
    expect(
      getUserActivityPresentation(
        { kind: "audit", title: "auth.external_login_succeeded", details: "Google" },
        text
      )
    ).toEqual({ title: "Вход через внешний сервис" });
  });

  it("does not repeat machine-readable wallet details in the general activity feed", () => {
    const text = getUserDetailWorkspaceText("ru");

    expect(
      getUserActivityPresentation(
        {
          kind: "wallet",
          title: "Admin token grant",
          details: "+100 tokens - generation_spend:6d9d",
        },
        text
      )
    ).toEqual({ title: "Изменён баланс PawSpark" });
  });

  it("never exposes unknown audit payloads", () => {
    const text = getUserDetailWorkspaceText("ru");

    expect(
      getUserActivityPresentation(
        { kind: "audit", title: "internal.event.v2", details: "secret diagnostic payload" },
        text
      )
    ).toEqual({ title: "Системное событие" });
  });
});
