import { describe, expect, it } from "vitest";

import {
  eventStatusOptions,
  getEconomyText,
  ledgerSourceOptions,
  purchaseStatusOptions,
  subscriptionProviderOptions,
  subscriptionStatusOptions,
} from "@/components/economy-page.content";

describe("economy-page content", () => {
  it("returns complete text bundles for ru and en", () => {
    const ruText = getEconomyText("ru");
    const enText = getEconomyText("en");

    expect(Object.keys(ruText).sort()).toEqual(Object.keys(enText).sort());
    expect(ruText.title).toBe("Экономика");
    expect(enText.title).toBe("Economy");
    expect(ruText.providerConfigDeleteConfirm).toBe("Удалить этот маршрут оплаты?");
    expect(enText.providerConfigDeleteConfirm).toBe("Delete this payment route?");
  });

  it("provides expected select options for filters", () => {
    expect(ledgerSourceOptions.ru[0]).toEqual({ value: "", label: "Все источники" });
    expect(ledgerSourceOptions.en[0]).toEqual({ value: "", label: "All sources" });

    expect(purchaseStatusOptions.ru.map((item) => item.value)).toEqual([
      "",
      "pending",
      "succeeded",
      "failed",
    ]);
    expect(subscriptionProviderOptions.en.map((item) => item.value)).toEqual([
      "",
      "app_store",
      "google_play",
      "stripe",
    ]);
    expect(subscriptionStatusOptions.en.map((item) => item.value)).toEqual([
      "",
      "active",
      "trialing",
      "past_due",
      "canceled",
      "expired",
    ]);
    expect(eventStatusOptions.ru.map((item) => item.value)).toEqual([
      "",
      "active",
      "canceled",
      "expired",
      "processed",
      "failed",
    ]);
  });
});
