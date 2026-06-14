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
const economyStylesPath = fileURLToPath(new URL("./economy-page.module.css", import.meta.url));
const economyContentPath = fileURLToPath(new URL("./economy-page.content.ts", import.meta.url));
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
    expect(ruText.partialErrorTitle).toBe("Часть данных не обновилась");
    expect(enText.partialErrorTitle).toBe("Some data did not refresh");
  });

  it("keeps Russian economy copy localized and text keys unique", () => {
    const ruText = getEconomyText("ru");
    const source = readFileSync(economyContentPath, "utf8");

    expect(ruText.subscriptionPlansDescription).toContain("экран оплаты");
    expect(ruText.subscriptionEventsDescription).toContain("магазинов приложений");
    expect(ruText.cancelSubscriptionDescription).toContain("журнал аудита");
    expect(ruText.refundPurchaseDescription).toContain("статус заказа сменится на возврат");
    expect(ruText.externalCheckoutFlag).toBe("Внешняя оплата");
    expect(ruText.storeDisclosureFlag).toBe("Раскрытие условий магазина");
    expect(ruText.warningTitleLabel).toBe("Заголовок предупреждения");
    expect(ruText.warningMessageLabel).toBe("Текст предупреждения");

    const ruValues = Object.values(ruText).join("\n");
    expect(ruValues).not.toMatch(
      /\b(checkout|store\/Stripe|Store disclosure|warning|audit log|refunded)\b/
    );
    expect(source.match(/cancelSubscriptionError:/g) ?? []).toHaveLength(2);
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
    expect(source.match(/assertCanManageEconomy\(\);/g) ?? []).toHaveLength(12);
    expect(source).toContain("function requestCancelSubscription(subscription: AdminEconomySubscription)");
    expect(source).toContain("function requestRefundPurchase(purchase: AdminEconomyPurchase)");
    expect(source).toContain("reportEconomyAccessDenied(error);");
    expect(source).toContain("useRef,");
    expect(source).toContain("const cancelSubscriptionInFlightRef = useRef(false);");
    expect(source).toContain("const refundPurchaseInFlightRef = useRef(false);");
    expect(source).toContain("const isCancelSubscriptionSubmitting =");
    expect(source).toContain("const isRefundPurchaseSubmitting =");
    expect(source).toContain(
      "cancelSubscriptionInFlightRef.current ||\n      cancelSubscriptionMutation.isPending ||\n      !canCancelSubscription(subscription)"
    );
    expect(source).toContain(
      "refundPurchaseInFlightRef.current ||\n      refundPurchaseMutation.isPending ||\n      !canRefundPurchase(purchase)"
    );
    expect(source).toContain("onCancelSubscription={requestCancelSubscription}");
    expect(source).toContain("onClick={() => requestRefundPurchase(item)}");
    expect(source).not.toContain("onCancelSubscription={setCancelTarget}");
    expect(source).not.toContain("onClick={() => setRefundTarget(item)}");

    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    expect(source).toContain("cancelSubscriptionPending={isCancelSubscriptionSubmitting}");
    expect(source).toContain("disabled={isRefundPurchaseSubmitting}");
    expect(subscriptionsSource).toContain("cancelSubscriptionPending: boolean;");
    expect(subscriptionsSource).toContain(
      "disabled={cancelSubscriptionPending || !canCancelSubscription(item)}"
    );
    expect(subscriptionsSource).not.toContain("disabled={!canCancelSubscription(item)}");
  });

  it("keeps the economy page error state recoverable with a guarded retry action", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const controllerSource = readFileSync(economyControllerPath, "utf8");

    expect(controllerSource).toContain(
      'const canLoadEconomy = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(controllerSource).toContain(
      'ensureAdminSession(locale, router, { requiredRole: "Admin" });'
    );
    expect(controllerSource.match(/enabled: canLoadEconomy/g) ?? []).toHaveLength(8);
    expect(controllerSource).toContain("if (!canLoadEconomy) {\n      return;\n    }");
    expect(controllerSource).toContain("const refetchAll = useCallback(async () => {");
    expect(controllerSource).toContain("ledgerQuery.refetch()");
    expect(controllerSource).toContain("purchasesQuery.refetch()");
    expect(controllerSource).toContain("subscriptionsQuery.refetch()");
    expect(controllerSource).toContain("const hasResolvedData =");
    expect(controllerSource).toContain("hasBlockingError: hasError && !hasResolvedData");
    expect(controllerSource).toContain("hasPartialError: hasError && hasResolvedData");
    expect(controllerSource).toContain("economyError,");
    expect(controllerSource).toContain("isFetching,");
    expect(controllerSource).toContain("refetchAll,");
    expect(economySource).toContain("if (hasBlockingError) {");
    expect(economySource).toContain("hasPartialError ? (");
    expect(economySource).toContain("title={text.partialErrorTitle}");
    expect(economySource).toContain("description={getAdminErrorMessage(economyError, text.errorDescription)}");
    expect(economySource).toContain("disabled={!canManageEconomy || isFetching}");
    expect(economySource).toContain(
      "if (!canManageEconomy) {\n                  return;\n                }\n\n                void refetchAll().catch(() => undefined);"
    );
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
    expect(source).toContain("const isCreateProviderConfigInvalid =");
    expect(source).toContain("disabled={createProviderConfigPending || isCreateProviderConfigInvalid}");
    expect(source).toContain("const isProviderConfigMatchInvalid =");
    expect(source).toContain("disabled={testProviderConfigPending || isProviderConfigMatchInvalid}");
    expect(source).toContain("const isProviderConfigInvalid = isPaymentRouteDraftInvalid(draft);");
    expect(source).toContain("disabled={saveProviderConfigPending || isProviderConfigInvalid}");
    expect(source).toContain("provider: normalizeProviderCodeInput(event.target.value)");
    expect(source).toContain("platform: normalizeProviderCodeInput(event.target.value)");
    expect(source).toContain("region: normalizeProviderRegionInput(event.target.value)");
    expect(source).toContain("mode: normalizeProviderCodeInput(event.target.value)");
    expect(source).toContain(
      "allowedFromAppVersion: normalizeProviderVersionInput(event.target.value)"
    );
    expect(source).toContain("country: normalizeProviderRegionInput(event.target.value)");
    expect(source).toContain("appVersion: normalizeProviderVersionInput(event.target.value)");
    expect(source).toContain("displayLabel: normalizeProviderLabelInput(event.target.value)");
    expect(source).toContain("displaySubtitle: normalizeProviderLabelInput(");
    expect(source).toContain("warningTitle: normalizeProviderLabelInput(event.target.value)");
    expect(source).toContain("warningMessage: normalizeProviderMessageInput(");
    expect(source).toContain("notes: normalizeProviderMessageInput(event.target.value)");
    expect(source).toContain(
      "[config.configurationId]: normalizeProviderRegionInput("
    );
    expect(source).toContain("function normalizeProviderCodeInput(value: string)");
    expect(source).toContain("return value.toLowerCase().slice(0, ECONOMY_PROVIDER_CODE_MAX_LENGTH);");
    expect(source).toContain("function normalizeProviderRegionInput(value: string)");
    expect(source).toContain("return value.toUpperCase().slice(0, ECONOMY_PROVIDER_REGION_MAX_LENGTH);");
    expect(source).toContain("function normalizeProviderVersionInput(value: string)");
    expect(source).toContain("return value.slice(0, ECONOMY_PROVIDER_VERSION_MAX_LENGTH);");
    expect(source).toContain("function normalizeProviderLabelInput(value: string)");
    expect(source).toContain("return value.slice(0, ECONOMY_PROVIDER_LABEL_MAX_LENGTH);");
    expect(source).toContain("function normalizeProviderMessageInput(value: string)");
    expect(source).toContain("return value.slice(0, ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH);");
    expect(source).toContain("function isPaymentRouteDraftInvalid(draft: ProviderConfigDraft)");
    expect(source).toContain("bonusPercent > 100");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_CODE_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH}");
    expect(source).toContain('pattern="[0-9]*"');
    expect(source).not.toContain('type="number"');
    expect(source).not.toContain("region: event.target.value.toUpperCase()");
    expect(source).not.toContain("allowedFromAppVersion: event.target.value");
    expect(source).not.toContain("mode: event.target.value");
    expect(source).not.toContain("displayLabel: event.target.value");
    expect(source).not.toContain("warningMessage: event.target.value");
    expect(source).not.toContain("[config.configurationId]: event.target.value.toUpperCase()");
  });

  it("guards payment route actions against double submits in handlers", () => {
    const source = readFileSync(providerConfigsSectionPath, "utf8");

    expect(source).toContain("const requestCreateProviderConfig = () => {");
    expect(source).toContain(
      "if (createProviderConfigPending || isCreateProviderConfigInvalid) {\n      return;\n    }"
    );
    expect(source).toContain("const requestTestProviderConfig = () => {");
    expect(source).toContain(
      "if (testProviderConfigPending || isProviderConfigMatchInvalid) {\n      return;\n    }"
    );
    expect(source).toContain("onClick={requestCreateProviderConfig}");
    expect(source).toContain("onClick={requestTestProviderConfig}");
    expect(source).toContain(
      "if (saveProviderConfigPending || isProviderConfigInvalid) {\n                              return;\n                            }"
    );
    expect(source).toContain(
      "if (cloneProviderConfigPending || !cloneRegion) {\n                              return;\n                            }"
    );
    expect(source).toContain(
      "if (deleteProviderConfigPending) {\n                              return;\n                            }"
    );
  });

  it("sanitizes payment and subscription display strings before rendering backend values", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    const providerConfigsSource = readFileSync(providerConfigsSectionPath, "utf8");

    expect(economySource).toContain("import { sanitizeSensitiveText }");
    expect(economySource).toContain("function safeText");
    expect(economySource).toContain("return safeText(value, 32).slice(0, 8);");
    expect(economySource).toContain("safeText(pack.code.toUpperCase(), 32)");
    expect(economySource).toContain("safeText(pack.currencyCode.toUpperCase(), 12)");
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
    expect(economySource).not.toContain("label: `${pack.code.toUpperCase()} • ${pack.currencyCode}`");
    expect(economySource).not.toContain("<strong>{pack.code.toUpperCase()}</strong>");
    expect(economySource).not.toContain("<span>{pack.currencyCode}</span>");
    expect(economySource).not.toContain(
      "${text.cancelSubscriptionDescription} ${shortGuid(cancelTarget.userId)} / ${cancelTarget.planName ?? cancelTarget.planId}"
    );
  });

  it("does not double-submit refund confirmations", () => {
    const source = readFileSync(economyPagePath, "utf8");
    const matches = source.match(/refundPurchaseMutation\.mutate\(refundTarget\)/g) ?? [];

    expect(source).toContain(
      "if (refundPurchaseInFlightRef.current || refundPurchaseMutation.isPending) {\n            return;\n          }"
    );
    expect(source).toContain("refundPurchaseInFlightRef.current = true;");
    expect(source).toContain("setIsRefundPurchaseInFlight(true);");
    expect(source).toContain("refundPurchaseInFlightRef.current = false;");
    expect(source).toContain("setIsRefundPurchaseInFlight(false);");
    expect(matches).toHaveLength(1);
  });

  it("does not double-submit subscription cancel confirmations", () => {
    const source = readFileSync(economyPagePath, "utf8");
    const matches = source.match(/cancelSubscriptionMutation\.mutate\(cancelTarget\)/g) ?? [];

    expect(source).toContain(
      "if (cancelSubscriptionInFlightRef.current || cancelSubscriptionMutation.isPending) {\n            return;\n          }"
    );
    expect(source).toContain("cancelSubscriptionInFlightRef.current = true;");
    expect(source).toContain("setIsCancelSubscriptionInFlight(true);");
    expect(source).toContain("cancelSubscriptionInFlightRef.current = false;");
    expect(source).toContain("setIsCancelSubscriptionInFlight(false);");
    expect(matches).toHaveLength(1);
  });

  it("invalidates related economy and user caches after financial mutations", () => {
    const source = readFileSync(economyPagePath, "utf8");

    expect(source).toContain("onSuccess: async (_, subscription) => {");
    expect(source).toContain("adminQueryKeys.economyUserSubscriptionSummary(subscription.userId)");
    expect(source).toContain("queryKey: adminQueryKeys.economyDashboardMetrics");
    expect(source).toContain("queryKey: adminQueryKeys.usersRoot");
    expect(source).toContain("queryKey: adminQueryKeys.userDashboardMetrics");
    expect(source).toContain("adminQueryKeys.userDetail(subscription.userId)");
    expect(source).toContain("adminQueryKeys.userAnalytics(subscription.userId)");
    expect(source).toContain("onSuccess: async (_, purchase) => {");
    expect(source).toContain('queryKey: ["admin", "economy", "ledger"]');
    expect(source).toContain("adminQueryKeys.userDetail(purchase.userId)");
    expect(source).toContain("adminQueryKeys.userAnalytics(purchase.userId)");
  });

  it("disables payment and subscription pagination while stale backend requests are fetching", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const stylesSource = readFileSync(economyStylesPath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    const controllerSource = readFileSync(economyControllerPath, "utf8");

    expect(economySource).toContain("ECONOMY_QUERY_FILTER_MAX_LENGTH,");
    expect(economySource).toContain("maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}");
    expect(economySource).toContain(
      "setPurchaseSearch(event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH))"
    );
    expect(subscriptionsSource).toContain("ECONOMY_QUERY_FILTER_MAX_LENGTH,");
    expect(subscriptionsSource).toContain("maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}");
    expect(subscriptionsSource).toContain(
      "setSubscriptionSearch(\n                    event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)\n                  )"
    );
    expect(economySource).not.toContain("maxLength={100}");
    expect(economySource).not.toContain("setPurchaseSearch(event.target.value)");
    expect(subscriptionsSource).not.toContain("maxLength={100}");
    expect(subscriptionsSource).not.toContain("setSubscriptionSearch(event.target.value)");
    expect(controllerSource).toContain("purchasesIsFetching: purchasesQuery.isFetching");
    expect(controllerSource).toContain("subscriptionsIsFetching: subscriptionsQuery.isFetching");
    expect(economySource).toContain("disabled={purchasePage === 0 || purchasesIsFetching}");
    expect(economySource).toContain("aria-label={text.previousPurchasesPageLabel}");
    expect(economySource).toContain("disabled={!purchasesHasMore || purchasesIsFetching}");
    expect(economySource).toContain("aria-label={text.nextPurchasesPageLabel}");
    expect(subscriptionsSource).toContain(
      "disabled={subscriptionPage === 0 || subscriptionsIsFetching}"
    );
    expect(subscriptionsSource).toContain("aria-label={text.previousSubscriptionsPageLabel}");
    expect(subscriptionsSource).toContain(
      "disabled={!subscriptionsHasMore || subscriptionsIsFetching}"
    );
    expect(subscriptionsSource).toContain("aria-label={text.nextSubscriptionsPageLabel}");
    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain(".pager {\n    justify-content: stretch;");
    expect(stylesSource).toContain(".pagerButton {\n    flex: 1 1 8rem;");
    expect(economySource).not.toContain("aria-label={text.previousPage}");
    expect(subscriptionsSource).not.toContain("aria-label={text.previousPage}");
  });

  it("keeps economy form, flag, and pager controls theme-token based", () => {
    const stylesSource = readFileSync(economyStylesPath, "utf8");

    expect(stylesSource).toContain(".input {\n  width: 100%;\n  min-width: 7.5rem;\n  border: 1px solid var(--border-soft);");
    expect(stylesSource).toContain("background: var(--surface-2);");
    expect(stylesSource).toContain("accent-color: var(--success);");
    expect(stylesSource).toContain(".usageItem {\n  display: grid;");
    expect(stylesSource).toContain(".pagerButton,\n.dangerButton {\n  min-height: 2rem;\n  border: 1px solid var(--border-soft);");
    expect(stylesSource).toContain("border-color: color-mix(in srgb, var(--danger) 28%, var(--border-soft));");
    expect(stylesSource).toContain(".flagList span {\n  padding: 0.28rem 0.5rem;");
    expect(stylesSource).toContain(".positive {\n  color: var(--success);");
    expect(stylesSource).toContain(".negative {\n  color: var(--danger);");
    expect(stylesSource).not.toContain("background: rgba(10, 16, 28, 0.88);");
    expect(stylesSource).not.toContain("background: rgba(26, 39, 56, 0.55);");
    expect(stylesSource).not.toContain("accent-color: #10c878;");
    expect(stylesSource).not.toContain("color: #4ade80;");
    expect(stylesSource).not.toContain("color: #f87171;");
  });

  it("keeps economy status badge colors on semantic theme tokens", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");

    expect(economySource).toContain('return "var(--success)"');
    expect(economySource).toContain('return "var(--info)"');
    expect(economySource).toContain('return "var(--danger)"');
    expect(economySource).toContain('return "var(--neutral)"');
    expect(economySource).toContain('return "var(--warning)"');
    expect(economySource).toContain("color={statusColor(item.status)}");
    expect(subscriptionsSource).toContain('color="var(--warning)"');
    expect(subscriptionsSource).toContain("color={statusColor(item.status)}");
    expect(economySource).not.toContain('return "#22c55e";');
    expect(economySource).not.toContain('return "#38bdf8";');
    expect(economySource).not.toContain('return "#f87171";');
    expect(economySource).not.toContain('return "#64748b";');
    expect(economySource).not.toContain('return "#f59e0b";');
    expect(subscriptionsSource).not.toContain('color="#f59e0b"');
  });

  it("bounds economy pack and premium plan free-text state updates", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const subscriptionPlansSource = readFileSync(subscriptionPlansSectionPath, "utf8");

    expect(economySource).toContain("normalizeEconomyPackDisplayNameInput(");
    expect(subscriptionPlansSource).toContain("normalizeEconomyPlanNameInput(event.target.value)");
    expect(subscriptionPlansSource).toContain("normalizeEconomyPlanProductIdInput(");
    expect(economySource).not.toContain("displayName: event.target.value");
    expect(subscriptionPlansSource).not.toContain("name: event.target.value");
    expect(subscriptionPlansSource).not.toContain("appleProductId: event.target.value");
    expect(subscriptionPlansSource).not.toContain("googleProductId: event.target.value");
    expect(subscriptionPlansSource).not.toContain("stripePriceId: event.target.value");
  });

  it("locks economy row save actions globally while the matching mutation is pending", () => {
    const economySource = readFileSync(economyPagePath, "utf8");
    const subscriptionPlansSource = readFileSync(subscriptionPlansSectionPath, "utf8");
    const providerConfigsSource = readFileSync(providerConfigsSectionPath, "utf8");

    expect(economySource).toContain("function requestSavePack(packId: string)");
    expect(economySource).toContain("if (savePackMutation.isPending) {\n      return;\n    }");
    expect(economySource).toContain("savePackMutation.mutate(packId);");
    expect(economySource).toContain("onClick={() => requestSavePack(pack.packId)}");
    expect(economySource).toContain("disabled={savePackMutation.isPending}");
    expect(economySource).not.toContain("onClick={() => savePackMutation.mutate(pack.packId)}");
    expect(economySource).not.toContain("disabled={isSavingRow}");

    expect(economySource).toContain("function requestSavePlan(planId: string)");
    expect(economySource).toContain("if (savePlanMutation.isPending) {\n      return;\n    }");
    expect(economySource).toContain("onSavePlan={requestSavePlan}");
    expect(subscriptionPlansSource).toContain(
      "<Button onClick={() => onSavePlan(plan.planId)} disabled={savePlanPending}>"
    );
    expect(subscriptionPlansSource).not.toContain("disabled={isSavingPlan}");

    expect(economySource).toContain(
      "function requestSaveProviderConfig(configurationId: string)"
    );
    expect(economySource).toContain(
      "if (saveProviderConfigMutation.isPending) {\n      return;\n    }"
    );
    expect(economySource).toContain("onSaveProviderConfig={requestSaveProviderConfig}");
    expect(economySource).toContain("function requestCreateProviderConfig()");
    expect(economySource).toContain(
      "if (createProviderConfigMutation.isPending) {\n      return;\n    }"
    );
    expect(economySource).toContain("onCreateProviderConfig={requestCreateProviderConfig}");
    expect(economySource).not.toContain(
      "onCreateProviderConfig={() => createProviderConfigMutation.mutate()}"
    );
    expect(economySource).toContain("function requestTestProviderConfig()");
    expect(economySource).toContain(
      "if (testProviderConfigMutation.isPending) {\n      return;\n    }"
    );
    expect(economySource).toContain("onTestProviderConfig={requestTestProviderConfig}");
    expect(economySource).not.toContain(
      "onTestProviderConfig={() => testProviderConfigMutation.mutate()}"
    );
    expect(economySource).toContain(
      "function requestCloneProviderConfig(payload: { configurationId: string; region: string })"
    );
    expect(economySource).toContain(
      "if (cloneProviderConfigMutation.isPending) {\n      return;\n    }"
    );
    expect(economySource).toContain("onCloneProviderConfig={requestCloneProviderConfig}");
    expect(economySource).not.toContain(
      "onCloneProviderConfig={(payload) => cloneProviderConfigMutation.mutate(payload)}"
    );
    expect(providerConfigsSource).toContain(
      "if (saveProviderConfigPending || isProviderConfigInvalid) {\n                              return;\n                            }"
    );
    expect(providerConfigsSource).toContain(
      "disabled={saveProviderConfigPending || isProviderConfigInvalid}"
    );
    expect(providerConfigsSource).not.toContain(
      "disabled={isSavingConfig || isProviderConfigInvalid}"
    );
  });

  it("renders a visual watermark preview for image and video settings", () => {
    const source = readFileSync(economyPagePath, "utf8");
    const styles = readFileSync(economyStylesPath, "utf8");

    expect(source).toContain("function WatermarkPreviewPanel");
    expect(source).toContain("const watermarkPositionOptions");
    expect(source).toContain("const watermarkSizeOptions");
    expect(source).toContain("renderFrame(\"image\", settings.previewImageUrl)");
    expect(source).toContain("renderFrame(\"video\", settings.previewVideoFrameUrl)");
    expect(source).toContain(
      "<WatermarkPreviewPanel locale={locale} settings={effectiveWatermarkDraft} />"
    );
    expect(source).toContain("className={styles.watermarkPreviewBadge}");
    expect(source).toContain("data-position={position}");
    expect(source).toContain("data-size={size}");
    expect(source).toContain("updateWatermarkDraft({ position: event.target.value })");
    expect(source).toContain("updateWatermarkDraft({ size: event.target.value })");
    expect(source).toContain("settings.logoUrl");
    expect(styles).toContain(".watermarkPreviewGrid");
    expect(styles).toContain(".watermarkPreviewFrame[data-kind=\"video\"]");
    expect(styles).toContain("right: 4%;");
    expect(styles).toContain("bottom: 4%;");
    expect(styles).toContain(".watermarkPreviewBadge[data-position=\"top-left\"]");
    expect(styles).toContain(".watermarkPreviewBadge[data-size=\"large\"]");
    expect(styles).toContain("opacity: var(--watermark-preview-opacity, 0.55);");
  });
});
