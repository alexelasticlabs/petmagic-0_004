import { describe, expect, it } from "vitest";

import { getUserWalletLedgerPresentation } from "@/components/users/user-wallet-presentation";
import { getDictionary } from "@/lib/i18n";

describe("user wallet ledger presentation", () => {
  it("keeps a support note only for manual balance adjustments", () => {
    const text = getDictionary("ru");

    expect(
      getUserWalletLedgerPresentation(
        { delta: 100, source: "admin_grant", reason: "Бонус за проблему с генерацией" },
        text
      )
    ).toEqual({ operationLabel: "Ручная корректировка", note: "Бонус за проблему с генерацией" });
    expect(
      getUserWalletLedgerPresentation(
        { delta: -50, source: "admin_debit", reason: "Корректировка баланса" },
        text
      )
    ).toEqual({ operationLabel: "Ручная корректировка", note: "Корректировка баланса" });
  });

  it("hides internal sources and structured reasons", () => {
    const text = getDictionary("ru");

    expect(
      getUserWalletLedgerPresentation(
        { delta: -8, source: "generation_spend", reason: "generation_spend:6d9d" },
        text
      )
    ).toEqual({ operationLabel: "Списание за генерацию" });
    expect(
      getUserWalletLedgerPresentation(
        { delta: 100, source: "admin_grant", reason: "purchase:order-123" },
        text
      )
    ).toEqual({ operationLabel: "Ручная корректировка" });
    expect(
      getUserWalletLedgerPresentation(
        { delta: 10, source: "future_source", reason: "diagnostic:raw" },
        text
      )
    ).toEqual({ operationLabel: "Изменение баланса" });
  });
});
