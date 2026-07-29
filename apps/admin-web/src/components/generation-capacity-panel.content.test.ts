import { describe, expect, it } from "vitest";

import { getGenerationCapacityAlertText } from "@/components/generation-capacity-panel.content";

describe("generation capacity alert localization", () => {
  it("localizes known server alerts for the active locale", () => {
    const backendAlert = {
      alertId: "fal-balance-low",
      title: "Backend English title",
      message: "Backend English message",
    };

    expect(getGenerationCapacityAlertText("ru", backendAlert)).toEqual({
      title: "Низкий баланс fal.ai",
      message: "Пополните баланс provider до достижения критического порога.",
    });
    expect(getGenerationCapacityAlertText("en", backendAlert)).toEqual({
      title: "fal.ai balance is low",
      message: "Replenish the provider balance before it reaches the critical threshold.",
    });
  });

  it("keeps backend copy as the fallback for unknown alert identifiers", () => {
    expect(
      getGenerationCapacityAlertText("ru", {
        alertId: "future-provider-alert",
        title: "Provider maintenance",
        message: "The provider is in maintenance mode.",
      })
    ).toEqual({
      title: "Provider maintenance",
      message: "The provider is in maintenance mode.",
    });
  });

  it("localizes the evidence-required ambiguous submit alert", () => {
    const backendAlert = {
      alertId: "generation-provider-submission-unknown",
      title: "Provider submissions require reconciliation",
      message: "One ambiguous submission occupies capacity.",
    };

    expect(getGenerationCapacityAlertText("ru", backendAlert)).toEqual({
      title: "Нужна сверка отправок в fal.ai",
      message:
        "Неоднозначные provider submits занимают capacity. Разрешите их только по подтверждённым данным fal.ai.",
    });
    expect(getGenerationCapacityAlertText("en", backendAlert)).toEqual({
      title: "fal.ai submissions require reconciliation",
      message:
        "Ambiguous provider submits occupy capacity. Resolve them only with confirmed fal.ai evidence.",
    });
  });

  it("localizes provider webhook dead-letter alerts", () => {
    const backendAlert = {
      alertId: "generation-provider-webhook-dead-letter",
      title: "Provider webhook reconciliation requires intervention",
      message: "One webhook event was dead-lettered.",
    };

    expect(getGenerationCapacityAlertText("ru", backendAlert)).toEqual({
      title: "Webhook провайдера требует вмешательства",
      message:
        "Событие исчерпало автоматические попытки reconciliation и перемещено в dead-letter. Проверьте worker logs и состояние provider attempt.",
    });
    expect(getGenerationCapacityAlertText("en", backendAlert)).toEqual({
      title: "Provider webhook requires intervention",
      message:
        "An event exhausted automatic reconciliation retries and was dead-lettered. Review worker logs and the provider attempt state.",
    });
  });

  it("localizes worker runtime and policy revision alerts", () => {
    expect(
      getGenerationCapacityAlertText("ru", {
        alertId: "generation-worker-runtime-config-unknown",
        title: "Backend runtime title",
        message: "Backend runtime message",
      })
    ).toEqual({
      title: "Runtime-конфигурация generation worker неизвестна",
      message: "Активные worker не сообщили единую конфигурацию Scheduler V2 и bounded lanes.",
    });
    expect(
      getGenerationCapacityAlertText("en", {
        alertId: "generation-worker-policy-revision-stale",
        title: "Backend revision title",
        message: "Backend revision message",
      })
    ).toEqual({
      title: "Generation worker policy revision is stale",
      message:
        "Wait for a heartbeat with the current revision or stop rollout and inspect worker logs.",
    });
    expect(
      getGenerationCapacityAlertText("ru", {
        alertId: "generation-worker-instance-count-unexpected",
        title: "Backend worker count title",
        message: "Backend worker count message",
      })
    ).toEqual({
      title: "Запущено больше одного generation worker",
      message:
        "Архитектура рассчитана на один Render worker. Проверьте Blueprint, Dashboard scaling и активные инстансы.",
    });
  });
});
