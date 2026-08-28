import { describe, expect, it } from "vitest";

import { getQueueExplanation } from "@/components/dashboard-operations-health";

describe("dashboard operations-health guidance", () => {
  it("does not describe a dead-letter push as a normal queue delay", () => {
    expect(getQueueExplanation("ru", 0, 1)).toEqual({
      summary: "1 отправл. не будет доставлено автоматически: все попытки исчерпаны.",
      nextStep:
        "Проверьте запись в журнале worker, устраните причину и инициируйте событие повторно. Повтор сам по себе не запускается, чтобы не отправить дубль.",
    });
  });

  it("keeps a normal zero-queue state quiet", () => {
    expect(getQueueExplanation("en", 0, 0)).toEqual({
      summary: "No new deliveries are waiting; this path is operating normally.",
    });
  });
});
