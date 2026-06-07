import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  eventStatusOptions,
  getEconomyText,
  ledgerSourceOptions,
  purchaseStatusOptions,
  subscriptionProviderOptions,
  subscriptionStatusOptions,
} from "@/components/economy-page.content";

const economyPagePath = fileURLToPath(new URL("./economy-page.tsx", import.meta.url));
const providerConfigsSectionPath = fileURLToPath(
  new URL("./economy-page-provider-configs-section.tsx", import.meta.url)
);
const subscriptionsSectionPath = fileURLToPath(
  new URL("./economy-page-subscriptions-section.tsx", import.meta.url)
);
const subscriptionPlansSectionPath = fileURLToPath(
  new URL("./economy-page-subscription-plans-section.tsx", import.meta.url)
);
const economyControllerPath = fileURLToPath(
  new URL("./use-economy-page-controller.ts", import.meta.url)
);

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
      "refunded",
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

  it("surfaces sanitized backend errors for economy mutations", () => {
    const source = readFileSync(economyPagePath, "utf8");

    expect(source).toContain("message: getAdminErrorMessage(error, text.packSaveError)");
    expect(source).toContain("message: getAdminErrorMessage(error, text.planSaveError)");
    expect(source).toContain("message: getAdminErrorMessage(error, text.providerConfigSaveError)");
    expect(source).toContain("message: getAdminErrorMessage(error, text.providerConfigCreateError)");
    expect(source).toContain("message: getAdminErrorMessage(error, text.providerConfigCloneError)");
    expect(source).toContain("message: getAdminErrorMessage(error, text.providerConfigDeleteError)");
    expect(source).toContain("message: getAdminErrorMessage(error, text.providerConfigTestError)");
    expect(source).toContain("message: getAdminErrorMessage(error, text.cancelSubscriptionError)");
    expect(source).toContain("message: getAdminErrorMessage(error, text.refundPurchaseError)");
    expect(source).toContain("throw new Error(text.packMissingDraft)");
    expect(source).not.toContain('throw new Error("Missing draft")');
    expect(source).not.toContain("onError: () => {\n      setFeedback({ tone: \"danger\", message: text.packSaveError });");
  });

  it("keeps economy financial mutations guarded by an Admin session in the component layer", () => {
    const source = readFileSync(economyPagePath, "utf8");
    const ruText = getEconomyText("ru");
    const enText = getEconomyText("en");

    expect(ruText.financialActionsAdminOnly).toBe("Финансовые действия доступны только Admin.");
    expect(enText.financialActionsAdminOnly).toBe(
      "Financial actions are available to Admin only."
    );
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain('const canManageEconomy = session?.user.roles.includes("Admin") ?? false;');
    expect(source).toContain("function assertCanManageEconomy()");
    expect(source).toContain("throw new Error(text.financialActionsAdminOnly);");
    expect(source.match(/assertCanManageEconomy\(\);/g) ?? []).toHaveLength(11);
    expect(source).toContain("function requestCancelSubscription(subscription: AdminEconomySubscription)");
    expect(source).toContain("function requestRefundPurchase(purchase: AdminEconomyPurchase)");
    expect(source).toContain("reportEconomyAccessDenied(error);");
    expect(source).toContain(
      "if (cancelSubscriptionMutation.isPending || !canCancelSubscription(subscription)) {"
    );
    expect(source).toContain(
      "if (refundPurchaseMutation.isPending || !canRefundPurchase(purchase)) {"
    );
    expect(source).toContain("onCancelSubscription={requestCancelSubscription}");
    expect(source).toContain("onClick={() => requestRefundPurchase(item)}");
    expect(source).not.toContain("onCancelSubscription={setCancelTarget}");
    expect(source).not.toContain("onClick={() => setRefundTarget(item)}");
  });

  it("keeps the economy page error state recoverable with a guarded retry action", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const controllerSource = readFileSync(economyControllerPath, "utf8");

    expect(controllerSource).toContain("const refetchAll = useCallback(async () => {");
    expect(controllerSource).toContain("ledgerQuery.refetch()");
    expect(controllerSource).toContain("purchasesQuery.refetch()");
    expect(controllerSource).toContain("subscriptionsQuery.refetch()");
    expect(controllerSource).toContain("isFetching,");
    expect(controllerSource).toContain("refetchAll,");
    expect(economySource).toContain("disabled={isFetching}");
    expect(economySource).toContain("void refetchAll().catch(() => undefined);");
    expect(economySource).toContain('{locale === "ru" ? "Повторить" : "Retry"}');
  });

  it("keeps payment route delete confirmations open until the backend action succeeds", () => {
    const source = readFileSync(providerConfigsSectionPath, "utf8");

    expect(source).toContain("if (deleteProviderConfigPending) {\n            return;\n          }");
    expect(source).toContain("onDeleteProviderConfig(configurationPendingDeleteId).then");
    expect(source).toContain("if (succeeded) {");
    expect(source).not.toContain(
      "onDeleteProviderConfig(configurationPendingDeleteId);\n          setConfigurationPendingDeleteId(null);"
    );
  });

  it("keeps payment route form inputs bounded and avoids exponent number fields", () => {
    const source = readFileSync(providerConfigsSectionPath, "utf8");

    expect(source).toContain("normalizeEconomyPercentInput(event.target.value)");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_CODE_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH}");
    expect(source).toContain('pattern="[0-9]*"');
    expect(source).not.toContain('type="number"');
  });

  it("sanitizes payment and subscription display strings before rendering backend values", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    const providerConfigsSource = readFileSync(providerConfigsSectionPath, "utf8");

    expect(economySource).toContain("import { sanitizeSensitiveText }");
    expect(economySource).toContain("function safeText");
    expect(economySource).toContain("return safeText(value, 32).slice(0, 8);");
    expect(economySource).toContain("safeText(item.reason)");
    expect(economySource).toContain("safeText(item.packDisplayName)");
    expect(economySource).toContain("const safeCurrencyCode = safeText(currencyCode.toUpperCase(), 12)");
    expect(economySource).toContain("return labels[value]?.[locale] ?? safeText(value, 48);");
    expect(economySource).toContain("currency: safeCurrencyCode");
    expect(economySource).toContain("Fall through to a non-throwing display");
    expect(subscriptionsSource).toContain("import { sanitizeSensitiveText }");
    expect(readFileSync(subscriptionPlansSectionPath, "utf8")).toContain(
      "import { sanitizeSensitiveText }"
    );
    expect(readFileSync(subscriptionPlansSectionPath, "utf8")).toContain(
      "label: `${safeText(plan.name, 80)} • ${humanizeBillingPeriod(plan.billingPeriod, locale)}`"
    );
    expect(readFileSync(subscriptionPlansSectionPath, "utf8")).toContain(
      "<strong>{safeText(plan.planId, 80)}</strong>"
    );
    expect(subscriptionsSource).toContain("function formatExternalEventId");
    expect(subscriptionsSource).toContain("safeText(item.planName || item.planId)");
    expect(subscriptionsSource).toContain("formatExternalEventId(");
    expect(providerConfigsSource).toContain("import { sanitizeSensitiveText }");
    expect(providerConfigsSource).toContain("safeText(matchResult.decisionMessage");
    expect(providerConfigsSource).toContain("safeText(matchResult.matchedConfiguration.region");
    expect(economySource).toContain("safeText(\n                cancelTarget.planName ?? cancelTarget.planId");
    expect(economySource).not.toContain(
      "${text.cancelSubscriptionDescription} ${shortGuid(cancelTarget.userId)} / ${cancelTarget.planName ?? cancelTarget.planId}"
    );
  });

  it("does not double-submit refund confirmations", () => {
    const source = readFileSync(economyPagePath, "utf8");
    const matches = source.match(/refundPurchaseMutation\.mutate\(refundTarget\)/g) ?? [];

    expect(source).toContain("if (refundPurchaseMutation.isPending) {\n            return;\n          }");
    expect(matches).toHaveLength(1);
  });

  it("does not double-submit subscription cancel confirmations", () => {
    const source = readFileSync(economyPagePath, "utf8");
    const matches = source.match(/cancelSubscriptionMutation\.mutate\(cancelTarget\)/g) ?? [];

    expect(source).toContain(
      "if (cancelSubscriptionMutation.isPending) {\n            return;\n          }"
    );
    expect(matches).toHaveLength(1);
  });

  it("invalidates related economy and user caches after financial mutations", () => {
    const source = readFileSync(economyPagePath, "utf8");

    expect(source).toContain("onSuccess: async (_, subscription) => {");
    expect(source).toContain("adminQueryKeys.economyUserSubscriptionSummary(subscription.userId)");
    expect(source).toContain("queryKey: adminQueryKeys.usersRoot");
    expect(source).toContain("adminQueryKeys.userDetail(subscription.userId)");
    expect(source).toContain("adminQueryKeys.userAnalytics(subscription.userId)");
    expect(source).toContain("onSuccess: async (_, purchase) => {");
    expect(source).toContain('queryKey: ["admin", "economy", "ledger"]');
    expect(source).toContain("adminQueryKeys.userDetail(purchase.userId)");
    expect(source).toContain("adminQueryKeys.userAnalytics(purchase.userId)");
  });

  it("disables payment and subscription pagination while stale backend requests are fetching", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    const controllerSource = readFileSync(economyControllerPath, "utf8");

    expect(controllerSource).toContain("purchasesIsFetching: purchasesQuery.isFetching");
    expect(controllerSource).toContain("subscriptionsIsFetching: subscriptionsQuery.isFetching");
    expect(economySource).toContain("disabled={purchasePage === 0 || purchasesIsFetching}");
    expect(economySource).toContain("disabled={!purchasesHasMore || purchasesIsFetching}");
    expect(subscriptionsSource).toContain(
      "disabled={subscriptionPage === 0 || subscriptionsIsFetching}"
    );
    expect(subscriptionsSource).toContain(
      "disabled={!subscriptionsHasMore || subscriptionsIsFetching}"
    );
  });
});
