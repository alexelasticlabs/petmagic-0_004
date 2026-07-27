import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  eventStatusOptions,
  getEconomyText,
  incidentActionOptions,
  incidentCategoryOptions,
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
const packsSectionPath = fileURLToPath(
  new URL("./economy-page-packs-section.tsx", import.meta.url)
);
const subscriptionsSectionPath = fileURLToPath(
  new URL("./economy-page-subscriptions-section.tsx", import.meta.url)
);
const ledgerPurchasesSectionPath = fileURLToPath(
  new URL("./economy-page-ledger-purchases-section.tsx", import.meta.url)
);
const incidentsSectionPath = fileURLToPath(
  new URL("./economy-page-incidents-section.tsx", import.meta.url)
);
const subscriptionPlansSectionPath = fileURLToPath(
  new URL("./economy-page-subscription-plans-section.tsx", import.meta.url)
);
const confirmationDialogsPath = fileURLToPath(
  new URL("./economy-page-confirmation-dialogs.tsx", import.meta.url)
);
const watermarkSectionPath = fileURLToPath(
  new URL("./economy-page-watermark-section.tsx", import.meta.url)
);
const economySharedPath = fileURLToPath(new URL("./economy-page.shared.tsx", import.meta.url));
const economyControllerPath = fileURLToPath(
  new URL("./use-economy-page-controller.ts", import.meta.url)
);
const catalogMutationsPath = fileURLToPath(
  new URL("./use-economy-catalog-mutations.ts", import.meta.url)
);
const subscriptionActionsPath = fileURLToPath(
  new URL("./use-economy-subscription-purchase-actions.ts", import.meta.url)
);
const economyApiTypesPath = fileURLToPath(
  new URL("../lib/api-client.types.economy.ts", import.meta.url)
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
    expect(ruText.providerRegionPlaceholder).toBe("US или *");
    expect(enText.providerRegionPlaceholder).toBe("US or *");
    expect(ruText.watermarkSaved).toBe("Настройки водяного знака сохранены");
    expect(enText.watermarkSaved).toBe("Watermark settings saved");
    expect(ruText.intlLocale).toBe("ru-RU");
    expect(enText.intlLocale).toBe("en-US");
    expect(ruText.previousLedgerPageLabel).toBe("Предыдущая страница журнала");
    expect(enText.nextLedgerPageLabel).toBe("Next ledger page");
    expect(ruText.resolveIncidentConfirmTitle).toBe("Закрыть инцидент?");
    expect(enText.providerConfigCloneConfirmTitle).toBe("Clone payment route?");
    expect(ruText.providerModeLiveLabel).toBe("Боевой");
    expect(ruText.quickActionsTitle).toBe("Быстрые действия");
    expect(enText.reconciliationConfirmTitle).toBe("Run economy reconciliation?");
    expect(ruText.allLedgerAction).toBe("Все операции");
    expect(enText.collapseDetailsAction).toBe("Collapse details");
  });

  it("keeps Russian economy copy localized and text keys unique", () => {
    const ruText = getEconomyText("ru");
    const enText = getEconomyText("en");
    const source = readFileSync(economyContentPath, "utf8");

    expect(ruText.subscriptionPlansDescription).toContain("экран оплаты");
    expect(ruText.subscriptionsDescription).toContain("подписок Premium");
    expect(ruText.subscriptionEventsDescription).toContain("магазинов приложений");
    expect(ruText.incidentsDescription).toContain("вебхук-событий");
    expect(ruText.incidentWebhookTitle).toBe("Снимок вебхука");
    expect(ruText.incidentSafePayloadLabel).toBe("Безопасный снимок полезной нагрузки");
    expect(ruText.purchaseSearchPlaceholder).toBe("ID заказа, ID пользователя или пакет");
    expect(ruText.subscriptionSearchPlaceholder).toBe("ID подписки, ID пользователя или план");
    expect(ruText.cancelSubscriptionDescription).toContain("журнал аудита");
    expect(ruText.refundPurchaseDescription).toContain("статус заказа сменится на возврат");
    expect(ruText.externalCheckoutFlag).toBe("Внешняя оплата");
    expect(ruText.storeDisclosureFlag).toBe("Раскрытие условий магазина");
    expect(ruText.incidentsTitle).toBe("Платежные инциденты");
    expect(ruText.incidentStatusFilterLabel).toBe("Статус инцидента");
    expect(ruText.warningTitleLabel).toBe("Заголовок предупреждения");
    expect(ruText.warningMessageLabel).toBe("Текст предупреждения");
    expect(ruText.watermarkTitle).toBe("Водяной знак");
    expect(ruText.watermarkDescription).toContain("бесплатных результатов");
    expect(ruText.watermarkDescription).not.toContain("clean unlock");
    expect(ruText.watermarkImagesLabel).toBe("Изображения");
    expect(ruText.watermarkCostCreditsLabel).toBe("Стоимость в кредитах");
    expect(ruText.watermarkPositionBottomRight).toBe("Снизу справа");
    expect(ruText.watermarkSizeMedium).toBe("Средний");
    expect(ruText.watermarkPreviewTestVideoFrame).toBe("Тестовый кадр видео");
    expect(ruText.tokenKindLegacyLabel).toBe("Начальный баланс");
    expect(enText.tokenKindLegacyLabel).toBe("Opening balance");
    expect(ruText.incidentChargedLabel).toBe("Списано");
    expect(ruText.incidentRefundedLabel).toBe("Возвращено");
    expect(ruText.incidentAutoResolveReason).toBe("Инцидент закрыт со страницы экономики.");
    expect(enText.incidentAutoResolveReason).toBe("Incident resolved from the economy page.");

    const ruValues = Object.values(ruText).join("\n");
    expect(ruValues).not.toMatch(
      /\b(checkout|store\/Stripe|Store disclosure|warning|audit log|refunded|legacy|incidents?|watermark|clean unlock|preview image|cost in credits|payload|order id|user id|subscription id|webhook)\b/i
    );
    expect(source.match(/cancelSubscriptionError:/g) ?? []).toHaveLength(2);
    expect(readFileSync(economyPagePath, "utf8")).toContain("text.incidentAutoResolveReason");
    expect(readFileSync(economyPagePath, "utf8")).not.toContain("Resolved from admin economy page");
  });

  it("provides expected select options for filters", () => {
    expect(ledgerSourceOptions.ru[0]).toEqual({ value: "", label: "Все источники" });
    expect(ledgerSourceOptions.en[0]).toEqual({ value: "", label: "All sources" });

    expect(purchaseStatusOptions.ru.map((item) => item.value)).toEqual([
      "",
      "pending",
      "succeeded",
      "failed",
      "refund_pending",
      "refund_review",
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
      "grace_period",
      "past_due",
      "canceled",
      "expired",
      "refunded",
      "revoked",
      "pending",
    ]);
    expect(eventStatusOptions.ru.map((item) => item.value)).toEqual([
      "",
      "active",
      "trialing",
      "grace_period",
      "past_due",
      "canceled",
      "expired",
      "processed",
      "failed",
      "pending",
    ]);
    expect(incidentActionOptions.ru.find((item) => item.value === "manual_revoke")?.label).toBe(
      "Отозвать вручную"
    );
    expect(incidentActionOptions.ru.find((item) => item.value === "retry_settlement")?.label).toBe(
      "Повторить закрытие платежа"
    );
    expect(
      incidentActionOptions.ru.find((item) => item.value === "retry_webhook_processing")?.label
    ).toBe("Повторить обработку вебхука");
    expect(incidentActionOptions.ru.find((item) => item.value === "resolve_incident")?.label).toBe(
      "Закрыть инцидент"
    );
    expect(incidentActionOptions.en.find((item) => item.value === "manual_revoke")?.label).toBe(
      "Manual revoke"
    );
    expect(incidentCategoryOptions.ru.map((item) => item.label)).toEqual([
      "Все категории",
      "Ожидает",
      "Ошибка",
      "Спор",
      "Ожидает возврата",
      "Ошибка закрытия платежа",
      "Ошибка вебхука",
      "Нужна сверка",
      "Ручная проверка",
      "Закрыт",
    ]);
    expect(incidentCategoryOptions.ru.map((item) => item.label).join("\n")).not.toMatch(
      /\b(Pending|Failed|Disputed|Refund pending|Settlement failed|Webhook failed|Resolved|reconciliation)\b/
    );
  });

  it("surfaces sanitized backend errors for economy mutations", () => {
    const catalogSource = readFileSync(catalogMutationsPath, "utf8");
    const subscriptionActionsSource = readFileSync(subscriptionActionsPath, "utf8");

    expect(catalogSource).toContain("message: getAdminErrorMessage(error, text.packSaveError)");
    expect(catalogSource).toContain("message: getAdminErrorMessage(error, text.planSaveError)");
    expect(catalogSource).toContain(
      "message: getAdminErrorMessage(error, text.providerConfigSaveError)"
    );
    expect(catalogSource).toContain(
      "message: getAdminErrorMessage(error, text.providerConfigCreateError)"
    );
    expect(catalogSource).toContain(
      "message: getAdminErrorMessage(error, text.providerConfigCloneError)"
    );
    expect(catalogSource).toContain(
      "message: getAdminErrorMessage(error, text.providerConfigDeleteError)"
    );
    expect(catalogSource).toContain(
      "message: getAdminErrorMessage(error, text.providerConfigTestError)"
    );
    expect(subscriptionActionsSource).toContain(
      "const message = getAdminErrorMessage(error, text.cancelSubscriptionError);"
    );
    expect(subscriptionActionsSource).toContain("setCancelError(message);");
    expect(subscriptionActionsSource).toContain(
      "message: getAdminErrorMessage(error, text.refundPurchaseError)"
    );
    expect(catalogSource).toContain("throw new Error(text.packMissingDraft)");
    expect(catalogSource).not.toContain('throw new Error("Missing draft")');
    expect(catalogSource).not.toContain(
      'onError: () => {\n      setFeedback({ tone: "danger", message: text.packSaveError });'
    );
  });

  it("keeps Premium cancellation failures visible inside the open confirmation dialog", () => {
    const pageSource = readFileSync(economyPagePath, "utf8");
    const subscriptionActionsSource = readFileSync(subscriptionActionsPath, "utf8");
    const confirmationSource = readFileSync(confirmationDialogsPath, "utf8");

    expect(subscriptionActionsSource).toContain(
      "const [cancelError, setCancelError] = useState<string | null>(null);"
    );
    expect(subscriptionActionsSource).toContain("setCancelError(message);");
    expect(subscriptionActionsSource).toContain("cancelError,");
    expect(pageSource).toContain("cancelError={subscriptionPurchaseActions.cancelError}");
    expect(confirmationSource).toContain('className={styles.confirmationError} role="alert"');
    expect(confirmationSource).toContain("{cancelError}");
  });

  it("keeps high-risk economy action diagnostics sanitized", () => {
    const source = readFileSync(subscriptionActionsPath, "utf8");
    const sharedSource = readFileSync(economySharedPath, "utf8");

    expect(source).toContain('import { clientLogger } from "@/lib/client-logger";');
    expect(sharedSource).toContain("export function getEconomyActionErrorDetails(error: unknown)");
    expect(sharedSource).toContain(
      'errorName: error instanceof Error ? error.name : "UnknownError"'
    );
    expect(sharedSource).toContain('"digest" in error');
    expect(sharedSource).toContain(
      'sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)'
    );
    expect(source).toContain('clientLogger.error("economy.cancel_subscription_failed"');
    expect(source).toContain('clientLogger.error("economy.refund_purchase_failed"');
    expect(source).toContain("subscriptionId: formatEconomyLogText(subscription?.subscriptionId)");
    expect(source).toContain("orderId: formatEconomyLogText(purchase?.orderId)");
    expect(sharedSource).not.toContain("sanitizeSensitiveText(error.message, 160)");
    expect(source).not.toContain("error,\n      });");
  });

  it("keeps previous economy rows visible and filters usable while data refreshes", () => {
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    const purchasesSource = readFileSync(ledgerPurchasesSectionPath, "utf8");

    expect(purchasesSource).toContain(
      "disabled={purchasesIsFetching && purchaseItems.length === 0}"
    );
    expect(subscriptionsSource).toContain(
      "disabled={subscriptionsIsFetching && subscriptionItems.length === 0}"
    );
    expect(purchasesSource).not.toContain("purchasesIsRefreshing ? (");
    expect(subscriptionsSource).not.toContain("subscriptionsIsRefreshing ? (");
  });

  it("keeps economy financial mutations guarded by an Admin session in the component layer", () => {
    const source = readFileSync(economyPagePath, "utf8");
    const catalogSource = readFileSync(catalogMutationsPath, "utf8");
    const subscriptionActionsSource = readFileSync(subscriptionActionsPath, "utf8");
    const ledgerSource = readFileSync(ledgerPurchasesSectionPath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    const ruText = getEconomyText("ru");
    const enText = getEconomyText("en");

    expect(ruText.financialActionsAdminOnly).toBe(
      "Финансовые действия доступны только администратору."
    );
    expect(enText.financialActionsAdminOnly).toBe("Financial actions are available to Admin only.");
    expect(source).toContain("useAuthSession");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain(
      'const canManageEconomy = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(catalogSource).toContain(
      "function assertCanManage(canManageEconomy: boolean, message: string)"
    );
    expect(subscriptionActionsSource).toContain(
      "function assertCanManage(canManageEconomy: boolean, message: string)"
    );
    expect(catalogSource).toContain("throw new Error(message);");
    const assertCallCount =
      (
        catalogSource.match(
          /assertCanManage\(canManageEconomy, text\.financialActionsAdminOnly\);/g
        ) ?? []
      ).length +
      (
        subscriptionActionsSource.match(
          /assertCanManage\(canManageEconomy, text\.financialActionsAdminOnly\);/g
        ) ?? []
      ).length;
    expect(assertCallCount).toBe(12);
    expect(subscriptionActionsSource).toContain(
      "function requestCancelSubscription(subscription: AdminEconomySubscription)"
    );
    expect(subscriptionActionsSource).toContain(
      "function requestRefundPurchase(purchase: AdminEconomyPurchase)"
    );
    expect(subscriptionActionsSource).toContain("reportEconomyAccessDenied(error);");
    expect(subscriptionActionsSource).toContain("useRef,");
    expect(subscriptionActionsSource).toContain(
      "const cancelSubscriptionInFlightRef = useRef(false);"
    );
    expect(subscriptionActionsSource).toContain("const refundPurchaseInFlightRef = useRef(false);");
    expect(subscriptionActionsSource).toContain("const isCancelSubscriptionSubmitting =");
    expect(subscriptionActionsSource).toContain("const isRefundPurchaseSubmitting =");
    expect(source).toContain("if (!canManageEconomy || isLoading) {");
    expect(source).toContain("title={text.loadingTitle}");
    expect(subscriptionActionsSource).toContain(
      "cancelSubscriptionInFlightRef.current ||\n      cancelSubscriptionMutation.isPending ||\n      !canCancelSubscription(subscription)"
    );
    expect(subscriptionActionsSource).toContain(
      "refundPurchaseInFlightRef.current ||\n      refundPurchaseMutation.isPending ||\n      !canRefundPurchase(purchase)"
    );
    expect(source).toContain(
      "onCancelSubscription={subscriptionPurchaseActions.requestCancelSubscription}"
    );
    expect(source).toContain(
      "onRefundPurchase={subscriptionPurchaseActions.requestRefundPurchase}"
    );
    expect(ledgerSource).toContain("onClick={() => onRefundPurchase(item)}");
    expect(source).not.toContain("onCancelSubscription={setCancelTarget}");
    expect(ledgerSource).not.toContain("onClick={() => setRefundTarget(item)}");

    expect(source).toContain(
      "cancelSubscriptionPending={subscriptionPurchaseActions.isCancelSubscriptionSubmitting}"
    );
    expect(ledgerSource).toContain("disabled={isRefundPurchaseSubmitting}");
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
    expect(controllerSource.match(/enabled: canLoadEconomy && shouldLoad/g) ?? []).toHaveLength(9);
    expect(controllerSource).toContain('const shouldLoadOverview = workspace === "overview";');
    expect(controllerSource).toContain('const shouldLoadCatalog = workspace === "catalog";');
    expect(controllerSource).toContain(
      'const shouldLoadSubscriptions = workspace === "subscriptions";'
    );
    expect(controllerSource).toContain('const shouldLoadPayments = workspace === "payments";');
    expect(controllerSource).toContain("if (!canLoadEconomy) {\n      return;\n    }");
    expect(controllerSource).toContain("const refetchAll = useCallback(async () => {");
    expect(controllerSource).toContain("const refreshes = [");
    expect(controllerSource).toContain("await Promise.allSettled(refreshes);");
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
    expect(economySource).toContain(
      "description={getAdminErrorMessage(economyError, text.errorDescription)}"
    );
    expect(economySource).toContain("disabled={!canManageEconomy || isFetching}");
    expect(economySource).toContain("function requestEconomyRetry()");
    expect(economySource).toContain("if (!canManageEconomy || isFetching) {\n      return;\n    }");
    expect(economySource).toContain("onClick={requestEconomyRetry}");
    expect(economySource).not.toContain("onClick={() => {\n                if (!canManageEconomy)");
    expect(economySource).toContain("{text.retry}");
    expect(economySource).not.toContain('{locale === "ru" ? "Повторить" : "Retry"}');
    expect(controllerSource).not.toContain("await Promise.all([\n      ledgerQuery.refetch()");
  });

  it("keeps payment route delete confirmations open until the backend action succeeds", () => {
    const source = readFileSync(providerConfigsSectionPath, "utf8");

    expect(source).toContain("const providerConfigIds = useMemo(");
    expect(source).toContain("new Set(providerConfigs.map((config) => config.configurationId))");
    expect(source).toContain(
      "!configurationPendingDeleteId ||\n      providerConfigIds.has(configurationPendingDeleteId) ||\n      deleteProviderConfigPending"
    );
    expect(source).toContain("let isActive = true;");
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("if (isActive) {\n        setConfigurationPendingDeleteId(null);");
    expect(source).toContain("return () => {\n      isActive = false;\n    };");
    expect(source).toContain(
      "if (deleteProviderConfigPending) {\n            return;\n          }"
    );
    expect(source).toContain("onDeleteProviderConfig(configurationPendingDeleteId).then");
    expect(source).toContain("if (succeeded) {");
    expect(source).not.toContain(
      "onDeleteProviderConfig(configurationPendingDeleteId);\n          setConfigurationPendingDeleteId(null);"
    );
  });

  it("keeps payment route form inputs bounded and avoids exponent number fields", () => {
    const source = readFileSync(providerConfigsSectionPath, "utf8");

    expect(source).toContain("normalizeEconomyPercentInput(event.target.value)");
    expect(source).toContain("isProviderConfigCreateDraftInvalid(");
    expect(source).toContain(
      "disabled={createProviderConfigPending || isCreateProviderConfigInvalid}"
    );
    expect(source).toContain("isProviderConfigMatchDraftInvalid(matchDraft)");
    expect(source).toContain(
      "disabled={testProviderConfigPending || isProviderConfigMatchInvalid}"
    );
    expect(source).toContain(
      "const isProviderConfigRegionValid = isValidPaymentRouteRegion(draft.region);"
    );
    expect(source).toContain(
      "const isProviderConfigInvalid =\n    !isProviderConfigRegionValid || isProviderConfigDraftInvalid(draft);"
    );
    expect(source).toContain("const isProviderConfigDraftLocked =");
    expect(source).toContain("disabled={isSaveProviderConfigDisabled}");
    expect(source).toContain(
      'import { EconomySelectField } from "@/components/economy-page-select-field";'
    );
    expect(source).toContain("options={providerOptions}");
    expect(source).toContain("options={platformOptions}");
    expect(source).toContain("options={modeOptions}");
    expect(source).toContain("region: normalizeProviderRegionInput(event.target.value)");
    expect(source).toContain(
      "allowedFromAppVersion: normalizeProviderVersionInput(event.target.value)"
    );
    expect(source).toContain("country: normalizeProviderRegionInput(event.target.value)");
    expect(source).toContain("appVersion: normalizeProviderVersionInput(event.target.value)");
    expect(source).toContain("displayLabel: normalizeProviderTextInput(");
    expect(source).toContain("displaySubtitle: normalizeProviderTextInput(");
    expect(source).toContain("warningTitle: normalizeProviderTextInput(");
    expect(source).toContain("warningMessage: normalizeProviderTextInput(");
    expect(source).toContain("notes: normalizeProviderTextInput(");
    expect(source).toContain("[config.configurationId]: normalizeProviderRegionInput(");
    expect(source).toContain("function normalizeProviderRegionInput(value: string)");
    expect(source).toContain(
      "return value.toUpperCase().slice(0, ECONOMY_PROVIDER_REGION_MAX_LENGTH);"
    );
    expect(source).toContain("function normalizeProviderVersionInput(value: string)");
    expect(source).toContain("return value.slice(0, ECONOMY_PROVIDER_VERSION_MAX_LENGTH);");
    expect(source).toContain(
      "function normalizeProviderTextInput(value: string, maxLength: number)"
    );
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH}");
    expect(source).toContain("maxLength={ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH}");
    expect(source).toContain("placeholder={text.providerRegionPlaceholder}");
    expect(source).toContain("placeholder={text.providerAppVersionPlaceholder}");
    expect(source).toContain("placeholder={text.providerBonusPlaceholder}");
    expect(source).toContain('pattern="[0-9]*"');
    expect(source).not.toContain('type="number"');
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
    expect(source).toContain("if (!isSaveProviderConfigDisabled) {");
    expect(source).toContain("if (isCloneProviderConfigDisabled) {");
    expect(source).toContain("if (deleteProviderConfigPending || isProviderConfigDraftLocked) {");
  });

  it("bounds watermark settings inputs before saving", () => {
    const sharedSource = readFileSync(economySharedPath, "utf8");
    const watermarkSource = readFileSync(watermarkSectionPath, "utf8");

    expect(sharedSource).toContain("export const WATERMARK_TEXT_MAX_LENGTH = 80;");
    expect(sharedSource).toContain("export const WATERMARK_COST_MAX_LENGTH = 6;");
    expect(sharedSource).toContain("export const WATERMARK_OPACITY_MAX_LENGTH = 4;");
    expect(sharedSource).toContain("export const WATERMARK_LOGO_URL_MAX_LENGTH = 2_048;");
    expect(watermarkSource).toContain("maxLength={WATERMARK_TEXT_MAX_LENGTH}");
    expect(watermarkSource).toContain("maxLength={WATERMARK_COST_MAX_LENGTH}");
    expect(watermarkSource).toContain('pattern="[0-9]*"');
    expect(watermarkSource).toContain("maxLength={WATERMARK_OPACITY_MAX_LENGTH}");
    expect(watermarkSource).toContain("maxLength={WATERMARK_LOGO_URL_MAX_LENGTH}");
    expect(watermarkSource).toContain('replace(/\\D+/g, "")');
    expect(watermarkSource).toContain(".slice(0, WATERMARK_COST_MAX_LENGTH)");
    expect(watermarkSource).toContain('replace(/[^\\d.]+/g, "")');
    expect(watermarkSource).toContain(
      "logoUrl: event.target.value.slice(0, WATERMARK_LOGO_URL_MAX_LENGTH)"
    );
  });

  it("sanitizes payment and subscription display strings before rendering backend values", () => {
    const sharedSource = readFileSync(economySharedPath, "utf8");
    const packsSource = readFileSync(packsSectionPath, "utf8");
    const ledgerSource = readFileSync(ledgerPurchasesSectionPath, "utf8");
    const incidentsSource = readFileSync(incidentsSectionPath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    const providerConfigsSource = readFileSync(providerConfigsSectionPath, "utf8");
    const confirmationSource = readFileSync(confirmationDialogsPath, "utf8");
    const economyApiTypesSource = readFileSync(economyApiTypesPath, "utf8");

    expect(sharedSource).toContain("import { sanitizeSensitiveText }");
    expect(sharedSource).toContain("export function safeText");
    expect(sharedSource).toContain("return safeText(value, 32).slice(0, 8);");
    expect(sharedSource).toContain("const { intlLocale, tokensShort } = getEconomyText(locale);");
    expect(sharedSource).toContain(
      "return `${new Intl.NumberFormat(intlLocale).format(value)} ${tokensShort}`;"
    );
    expect(sharedSource).not.toContain("format(value)} spark`");
    expect(packsSource).toContain("safeText(pack.code.toUpperCase(), 32)");
    expect(packsSource).toContain("safeText(pack.currencyCode.toUpperCase(), 12)");
    expect(ledgerSource).toContain("safeText(item.reason)");
    expect(ledgerSource).toContain(
      "humanizeTokenKind(item.tokenKind, locale, text.tokenKindLegacyLabel)"
    );
    expect(incidentsSource).toContain(
      "humanizeTokenKind(item.tokenKind, locale, text.tokenKindLegacyLabel)"
    );
    expect(incidentsSource).toContain("incidentActionOptions[locale]");
    expect(incidentsSource).toContain("text.incidentChargedLabel");
    expect(incidentsSource).toContain("text.incidentRefundedLabel");
    expect(incidentsSource).not.toContain('item.tokenKind ?? "legacy"');
    expect(incidentsSource).not.toContain("Retry webhook processing");
    expect(incidentsSource).not.toContain("· Charged:");
    expect(incidentsSource).not.toContain("· Refunded:");
    expect(ledgerSource).not.toContain('item.tokenKind ?? "legacy"');
    expect(ledgerSource).toContain("safeText(item.packDisplayName)");
    expect(sharedSource).toContain(
      "const safeCurrencyCode = safeText(currencyCode.toUpperCase(), 12)"
    );
    expect(sharedSource).toContain("export function humanizeTokenKind");
    expect(sharedSource).toContain(
      'subscription_allowance: { ru: "Premium-лимит", en: "Premium allowance" }'
    );
    expect(sharedSource).not.toContain('subscription_allowance: { ru: "Premium allowance"');
    expect(sharedSource).toContain("return labels[value]?.[locale] ?? safeText(value, 48);");
    expect(sharedSource).toContain("currency: safeCurrencyCode");
    expect(sharedSource).toContain("Fall through to a non-throwing display");
    expect(subscriptionsSource).toContain("import { sanitizeSensitiveText }");
    expect(readFileSync(subscriptionPlansSectionPath, "utf8")).toContain(
      "import { safeText, TableOrEmpty }"
    );
    expect(readFileSync(subscriptionPlansSectionPath, "utf8")).toContain(
      "label: `${safeText(plan.name, 80)} • ${humanizeBillingPeriod(plan.billingPeriod, locale)}`"
    );
    expect(readFileSync(subscriptionPlansSectionPath, "utf8")).toContain(
      "safeText(plan.planId, 48)"
    );
    expect(subscriptionsSource).toContain("function formatExternalEventId");
    expect(subscriptionsSource).toContain("safeText(item.planName || item.planId)");
    expect(subscriptionsSource).toContain("formatExternalEventId(");
    expect(subscriptionsSource).toContain(
      "formatExternalEventId(item.externalEventId, text.noDescription)"
    );
    expect(subscriptionsSource).not.toContain("externalSubscriptionId");
    expect(economyApiTypesSource).not.toContain("externalSubscriptionId");
    expect(providerConfigsSource).toContain("import { sanitizeSensitiveText }");
    expect(providerConfigsSource).toContain("safeText(matchResult.decisionMessage");
    expect(providerConfigsSource).toContain("safeText(matchResult.matchedConfiguration.region");
    expect(confirmationSource).toContain(
      "safeText(\n                cancelTarget.planName ?? cancelTarget.planId"
    );
    expect(packsSource).not.toContain("label: `${pack.code.toUpperCase()} • ${pack.currencyCode}`");
    expect(packsSource).not.toContain("<strong>{pack.code.toUpperCase()}</strong>");
    expect(packsSource).not.toContain("<span>{pack.currencyCode}</span>");
    expect(confirmationSource).not.toContain(
      "${text.cancelSubscriptionDescription} ${shortGuid(cancelTarget.userId)} / ${cancelTarget.planName ?? cancelTarget.planId}"
    );
  });

  it("does not double-submit refund confirmations", () => {
    const source = readFileSync(subscriptionActionsPath, "utf8");
    const matches = source.match(/refundPurchaseMutation\.mutate\(refundTarget\)/g) ?? [];

    expect(source).toContain(
      "if (refundPurchaseInFlightRef.current || refundPurchaseMutation.isPending) {\n      return;\n    }"
    );
    expect(source).toContain("refundPurchaseInFlightRef.current = true;");
    expect(source).toContain("setIsRefundPurchaseInFlight(true);");
    expect(source).toContain("refundPurchaseInFlightRef.current = false;");
    expect(source).toContain("setIsRefundPurchaseInFlight(false);");
    expect(matches).toHaveLength(1);
  });

  it("does not double-submit subscription cancel confirmations", () => {
    const source = readFileSync(subscriptionActionsPath, "utf8");
    const matches = source.match(/cancelSubscriptionMutation\.mutate\(cancelTarget\)/g) ?? [];

    expect(source).toContain(
      "if (cancelSubscriptionInFlightRef.current || cancelSubscriptionMutation.isPending) {\n      return;\n    }"
    );
    expect(source).toContain("cancelSubscriptionInFlightRef.current = true;");
    expect(source).toContain("setIsCancelSubscriptionInFlight(true);");
    expect(source).toContain("cancelSubscriptionInFlightRef.current = false;");
    expect(source).toContain("setIsCancelSubscriptionInFlight(false);");
    expect(matches).toHaveLength(1);
  });

  it("clears stale purchase and subscription confirmation targets after list refreshes", () => {
    const source = readFileSync(subscriptionActionsPath, "utf8");

    expect(source).toContain("useMemo,");
    expect(source).toContain(
      "const visiblePurchaseIds = useMemo(\n    () => new Set(purchaseItems.map((purchase) => purchase.orderId))"
    );
    expect(source).toContain(
      "const visibleSubscriptionIds = useMemo(\n    () => new Set(subscriptionItems.map((subscription) => subscription.subscriptionId))"
    );
    expect(source).toContain(
      "!refundTarget ||\n      isRefundPurchaseSubmitting ||\n      visiblePurchaseIds.has(refundTarget.orderId)"
    );
    expect(source).toContain("let isActive = true;");
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("if (isActive) {\n        setRefundTarget(null);");
    expect(source).toContain(
      "!cancelTarget ||\n      isCancelSubscriptionSubmitting ||\n      visibleSubscriptionIds.has(cancelTarget.subscriptionId)"
    );
    expect(source).toContain("if (isActive) {\n        setCancelTarget(null);");
    expect(source).toContain("return () => {\n      isActive = false;\n    };");
  });

  it("invalidates related economy and user caches after financial mutations", () => {
    const source = readFileSync(subscriptionActionsPath, "utf8");

    expect(source).toContain("onSuccess: async (_, subscription) => {");
    expect(source).toContain(
      'await Promise.allSettled([\n        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "subscriptions"] })'
    );
    expect(source).toContain("adminQueryKeys.economyUserSubscriptionSummary(subscription.userId)");
    expect(source).toContain("queryKey: adminQueryKeys.economyDashboardMetrics");
    expect(source).toContain("queryKey: adminQueryKeys.usersRoot");
    expect(source).toContain("queryKey: adminQueryKeys.userDashboardMetrics");
    expect(source).toContain("adminQueryKeys.userDetail(subscription.userId)");
    expect(source).toContain("adminQueryKeys.userAnalytics(subscription.userId)");
    expect(source).toContain("onSuccess: async (_, purchase) => {");
    expect(source).toContain(
      'await Promise.allSettled([\n        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "purchases"] })'
    );
    expect(source).toContain('queryKey: ["admin", "economy", "ledger"]');
    expect(source).toContain("adminQueryKeys.userDetail(purchase.userId)");
    expect(source).toContain("adminQueryKeys.userAnalytics(purchase.userId)");
    expect(source).not.toContain(
      'await Promise.all([\n        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "subscriptions"] })'
    );
    expect(source).not.toContain(
      'await Promise.all([\n        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "purchases"] })'
    );
  });

  it("keeps economy configuration refreshes non-blocking after successful mutations", () => {
    const source = readFileSync(catalogMutationsPath, "utf8");

    expect(source).toContain(
      "await Promise.allSettled([\n        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyPacks }),"
    );
    expect(source).toContain(
      "await Promise.allSettled([\n        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateWatermarkSettings }),"
    );
    expect(source).toContain(
      "await Promise.allSettled([\n        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economySubscriptionPlans }),"
    );
    expect(source).toContain(
      "queryKey: adminQueryKeys.economyPaymentProviderConfigs,\n        }),\n      ]);"
    );
    expect(source).not.toContain(
      "await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyPacks })"
    );
    expect(source).not.toContain(
      "await queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateWatermarkSettings })"
    );
    expect(source).not.toContain(
      "await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economySubscriptionPlans })"
    );
    expect(source).not.toContain(
      "await queryClient.invalidateQueries({\n        queryKey: adminQueryKeys.economyPaymentProviderConfigs"
    );
  });

  it("disables payment and subscription pagination while stale backend requests are fetching", () => {
    const pageSource = readFileSync(economyPagePath, "utf8");
    const purchasesSource = readFileSync(ledgerPurchasesSectionPath, "utf8");
    const stylesSource = readFileSync(economyStylesPath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");
    const controllerSource = readFileSync(economyControllerPath, "utf8");

    expect(purchasesSource).toContain("ECONOMY_QUERY_FILTER_MAX_LENGTH,");
    expect(purchasesSource).toContain("maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}");
    expect(purchasesSource).toContain(
      "setPurchaseSearch(event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH))"
    );
    expect(subscriptionsSource).toContain("ECONOMY_QUERY_FILTER_MAX_LENGTH,");
    expect(subscriptionsSource).toContain("maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}");
    expect(subscriptionsSource).toContain(
      "setSubscriptionSearch(event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH))"
    );
    expect(purchasesSource).not.toContain("maxLength={100}");
    expect(purchasesSource).not.toContain("setPurchaseSearch(event.target.value)");
    expect(subscriptionsSource).not.toContain("maxLength={100}");
    expect(subscriptionsSource).not.toContain("setSubscriptionSearch(event.target.value)");
    expect(controllerSource).toContain("purchasesIsFetching: purchasesQuery.isFetching");
    expect(controllerSource).toContain("purchasesIsRefreshing,");
    expect(controllerSource).toContain("subscriptionsIsFetching: subscriptionsQuery.isFetching");
    expect(controllerSource).toContain("subscriptionsIsRefreshing,");
    expect(controllerSource).toContain("const visiblePurchasesPage = purchasesQuery.data;");
    expect(controllerSource).toContain("const visibleSubscriptionsPage = subscriptionsQuery.data;");
    expect(controllerSource).toContain(
      "const purchasesIsRefreshing = purchasesQuery.isFetching && purchasesQuery.isPlaceholderData"
    );
    expect(controllerSource).toContain(
      "subscriptionsQuery.isFetching && subscriptionsQuery.isPlaceholderData"
    );
    expect(controllerSource).toContain("() => visiblePurchasesPage?.items ?? []");
    expect(controllerSource).toContain("() => visibleSubscriptionsPage?.items ?? []");
    expect(controllerSource).toContain("purchasesHasMore: visiblePurchasesPage?.hasMore ?? false");
    expect(controllerSource).toContain(
      "subscriptionsHasMore: visibleSubscriptionsPage?.hasMore ?? false"
    );
    expect(controllerSource).not.toContain(
      "const visiblePurchasesPage = purchasesQuery.isPlaceholderData ? undefined : purchasesQuery.data"
    );
    expect(controllerSource).not.toContain(
      "const visibleSubscriptionsPage = subscriptionsQuery.isPlaceholderData"
    );
    expect(purchasesSource).toContain("disabled={purchasePage === 0 || purchasesIsFetching}");
    expect(purchasesSource).toContain("purchasesIsFetching && purchaseItems.length === 0 ? (");
    expect(purchasesSource).toContain('<AdminStateCard tone="info" title={text.loadingTitle} />');
    expect(purchasesSource).toContain("aria-label={text.previousPurchasesPageLabel}");
    expect(purchasesSource).toContain("disabled={!purchasesHasMore || purchasesIsFetching}");
    expect(purchasesSource).toContain("aria-label={text.nextPurchasesPageLabel}");
    expect(subscriptionsSource).toContain(
      "disabled={subscriptionPage === 0 || subscriptionsIsFetching}"
    );
    expect(subscriptionsSource).toContain(
      "subscriptionsIsFetching && subscriptionItems.length === 0"
    );
    expect(subscriptionsSource).toContain(
      '<AdminStateCard tone="info" title={text.loadingTitle} />'
    );
    expect(subscriptionsSource).toContain("aria-label={text.previousSubscriptionsPageLabel}");
    expect(subscriptionsSource).toContain(
      "disabled={!subscriptionsHasMore || subscriptionsIsFetching}"
    );
    expect(subscriptionsSource).toContain("aria-label={text.nextSubscriptionsPageLabel}");
    expect(pageSource).not.toContain("purchasesIsRefreshing={purchasesIsRefreshing}");
    expect(pageSource).not.toContain("subscriptionsIsRefreshing={subscriptionsIsRefreshing}");
    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain(".pager {\n    justify-content: stretch;");
    expect(stylesSource).toContain(".pagerButton {\n    flex: 1 1 8rem;");
    expect(purchasesSource).not.toContain("aria-label={text.previousPage}");
    expect(subscriptionsSource).not.toContain("aria-label={text.previousPage}");
  });

  it("keeps economy form, flag, and pager controls theme-token based", () => {
    const stylesSource = readFileSync(economyStylesPath, "utf8");

    expect(stylesSource).toContain(".input {");
    expect(stylesSource).toContain("max-width: 100%;");
    expect(stylesSource).toContain("min-height: 2.5rem;");
    expect(stylesSource).toContain("min-width: 7.5rem;");
    expect(stylesSource).toContain("border: 1px solid var(--border-soft);");
    expect(stylesSource).toContain(
      ".input:focus-visible,\n.checkboxField input:focus-visible,\n.pagerButton:focus-visible,\n.dangerButton:focus-visible"
    );
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain(".input:disabled {\n  opacity: 0.62;\n  cursor: not-allowed;");
    expect(stylesSource).toContain("background: var(--surface-2);");
    expect(stylesSource).toContain("accent-color: var(--success);");
    expect(stylesSource).toContain(".usageItem {");
    expect(stylesSource).toContain("display: grid;");
    expect(stylesSource).toContain(".pagerButton,\n.dangerButton {");
    expect(stylesSource).toContain("display: inline-flex;");
    expect(stylesSource).toContain("justify-content: center;");
    expect(stylesSource).toContain("min-height: 2rem;");
    expect(stylesSource).toContain(
      "border-color: color-mix(in srgb, var(--danger) 28%, var(--border-soft));"
    );
    expect(stylesSource).toContain(".flagList span {");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(stylesSource).toContain("padding: 0.28rem 0.5rem;");
    expect(stylesSource).toContain(
      ".positive {\n  color: color-mix(in srgb, var(--success) 82%, var(--text-strong));"
    );
    expect(stylesSource).toContain(
      ".negative {\n  color: color-mix(in srgb, var(--danger) 86%, var(--text-strong));"
    );
    expect(stylesSource).not.toContain("background: rgba(10, 16, 28, 0.88);");
    expect(stylesSource).not.toContain("background: rgba(26, 39, 56, 0.55);");
    expect(stylesSource).not.toContain("accent-color: #10c878;");
    expect(stylesSource).not.toContain("color: #4ade80;");
    expect(stylesSource).not.toContain("color: #f87171;");
  });

  it("keeps economy form fields and watermark previews usable on phone screens", () => {
    const stylesSource = readFileSync(economyStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain(".watermarkPreviewGrid {\n    grid-template-columns: 1fr;");
    expect(stylesSource).toContain(".windowFields,\n  .tableActions");
    expect(stylesSource).toContain("min-width: 0;");
    expect(stylesSource).toContain(".input,\n  .compactSelect");
    expect(stylesSource).toContain(".redeemGrid,\n  .formRow,\n  .filterRow");
    expect(stylesSource).toContain("grid-template-columns: 1fr;");
    expect(stylesSource).toContain("font-size: clamp(1.08rem, 1rem + 0.32vw, 1.28rem);");
  });

  it("keeps economy status badge colors on semantic theme tokens", () => {
    const sharedSource = readFileSync(economySharedPath, "utf8");
    const economySource = readFileSync(ledgerPurchasesSectionPath, "utf8");
    const subscriptionsSource = readFileSync(subscriptionsSectionPath, "utf8");

    expect(sharedSource).toContain('return "var(--success)"');
    expect(sharedSource).toContain('return "var(--info)"');
    expect(sharedSource).toContain('return "var(--danger)"');
    expect(sharedSource).toContain('return "var(--neutral)"');
    expect(sharedSource).toContain('return "var(--warning)"');
    expect(economySource).toContain("color={statusColor(item.status)}");
    expect(subscriptionsSource).toContain('color="var(--warning)"');
    expect(subscriptionsSource).toContain("color={statusColor(item.status)}");
    expect(sharedSource).not.toContain('return "#22c55e";');
    expect(sharedSource).not.toContain('return "#38bdf8";');
    expect(sharedSource).not.toContain('return "#f87171";');
    expect(sharedSource).not.toContain('return "#64748b";');
    expect(sharedSource).not.toContain('return "#f59e0b";');
    expect(subscriptionsSource).not.toContain('color="#f59e0b"');
  });

  it("bounds economy pack and premium plan free-text state updates", () => {
    const economySource = readFileSync(packsSectionPath, "utf8");
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

  it("guards economy row saves while preserving unrelated drafts", () => {
    const pageSource = readFileSync(economyPagePath, "utf8");
    const catalogSource = readFileSync(catalogMutationsPath, "utf8");
    const economySource = readFileSync(packsSectionPath, "utf8");
    const subscriptionPlansSource = readFileSync(subscriptionPlansSectionPath, "utf8");
    const providerConfigsSource = readFileSync(providerConfigsSectionPath, "utf8");

    expect(catalogSource).toContain("function requestSavePack(packId: string)");
    expect(catalogSource).toContain("if (savePackMutation.isPending) {\n      return;\n    }");
    expect(catalogSource).toContain("isPackDraftDirty,");
    expect(catalogSource).toContain("if (!pack || !draft || !isPackDraftDirty(pack, draft))");
    expect(economySource).toContain("isPackDraftInvalid,");
    expect(economySource).toContain("const isPackDraftInvalidState = isPackDraftInvalid(draft);");
    expect(economySource).toContain(
      "savePackPending || !isPackDraftDirtyState || isPackDraftInvalidState"
    );
    expect(catalogSource).toContain("savePackMutation.mutate(packId);");
    expect(economySource).toContain("onClick={() => onSavePack(pack.packId)}");
    expect(economySource).toContain("const isPackDraftLocked = isSavingRow;");
    expect(economySource).toContain("disabled={isPackDraftLocked}");
    expect(economySource).toContain("disabled={isSavePackDisabled}");
    expect(economySource.match(/disabled=\{isPackDraftLocked\}/g) ?? []).toHaveLength(6);
    expect(pageSource).not.toContain("onClick={() => savePackMutation.mutate(pack.packId)}");
    expect(economySource).not.toContain("disabled={isSavingRow}");

    expect(catalogSource).toContain("function requestSavePlan(planId: string)");
    expect(catalogSource).toContain("if (savePlanMutation.isPending) {\n      return;\n    }");
    expect(catalogSource).toContain("isSubscriptionPlanDraftDirty,");
    expect(catalogSource).toContain(
      "if (!plan || !draft || !isSubscriptionPlanDraftDirty(plan, draft))"
    );
    expect(pageSource).toContain("onSavePlan={catalog.requestSavePlan}");
    expect(subscriptionPlansSource).toContain("const isPlanDraftLocked = savePlanPending;");
    expect(subscriptionPlansSource).toContain("isSubscriptionPlanDraftDirty,");
    expect(subscriptionPlansSource).toContain("isSubscriptionPlanDraftInvalid,");
    expect(subscriptionPlansSource).toContain(
      "const isPlanDraftInvalid = isSubscriptionPlanDraftInvalid(draft);"
    );
    expect(subscriptionPlansSource).toContain(
      "isPlanDraftLocked || !isPlanDraftDirty || isPlanDraftInvalid"
    );
    expect(subscriptionPlansSource).toContain(
      '<Button type="submit" disabled={isSavePlanDisabled}>'
    );
    expect(subscriptionPlansSource).toContain("onSubmit={(event) => {");
    expect(subscriptionPlansSource).toContain("if (!isSavePlanDisabled) {");
    expect(subscriptionPlansSource).toContain("onSavePlan(plan.planId);");
    expect(subscriptionPlansSource.match(/disabled=\{isPlanDraftLocked\}/g) ?? []).toHaveLength(12);
    expect(subscriptionPlansSource).toContain("disabled={isSavePlanDisabled}");
    expect(subscriptionPlansSource).not.toContain("disabled={isSavingPlan}");
    expect(subscriptionPlansSource).toContain(
      "const [editingPlanId, setEditingPlanId] = useState<string | null>(null);"
    );
    expect(subscriptionPlansSource).toContain("className={styles.planSummaryList}");
    expect(subscriptionPlansSource).toContain("aria-controls={editorId}");
    expect(subscriptionPlansSource).toContain("aria-expanded={isPlanEditorOpen}");
    expect(subscriptionPlansSource).toContain("className={styles.planEditor}");
    expect(subscriptionPlansSource).not.toContain("<table");

    expect(catalogSource).toContain("function requestSaveProviderConfig(configurationId: string)");
    expect(catalogSource).toContain(
      "if (saveProviderConfigMutation.isPending) {\n      return;\n    }"
    );
    expect(catalogSource).toContain("isProviderConfigDraftDirty,");
    expect(catalogSource).toContain(
      "if (!config || !draft || !isProviderConfigDraftDirty(config, draft))"
    );
    expect(pageSource).toContain("onSaveProviderConfig={catalog.requestSaveProviderConfig}");
    expect(catalogSource).toContain("function requestCreateProviderConfig()");
    expect(catalogSource).toContain(
      "if (createProviderConfigMutation.isPending) {\n      return;\n    }"
    );
    expect(pageSource).toContain("onCreateProviderConfig={catalog.requestCreateProviderConfig}");
    expect(pageSource).not.toContain(
      "onCreateProviderConfig={() => createProviderConfigMutation.mutate()}"
    );
    expect(catalogSource).toContain("function requestTestProviderConfig()");
    expect(catalogSource).toContain(
      "if (testProviderConfigMutation.isPending) {\n      return;\n    }"
    );
    expect(pageSource).toContain("onTestProviderConfig={catalog.requestTestProviderConfig}");
    expect(pageSource).not.toContain(
      "onTestProviderConfig={() => testProviderConfigMutation.mutate()}"
    );
    expect(catalogSource).toContain(
      "function requestCloneProviderConfig(payload: { configurationId: string; region: string })"
    );
    expect(catalogSource).toContain(
      "if (cloneProviderConfigMutation.isPending) {\n      return;\n    }"
    );
    expect(pageSource).toContain("onCloneProviderConfig={catalog.requestCloneProviderConfig}");
    expect(pageSource).not.toContain(
      "onCloneProviderConfig={(payload) => cloneProviderConfigMutation.mutate(payload)}"
    );
    expect(providerConfigsSource).toContain("const isProviderConfigDraftLocked =");
    expect(providerConfigsSource).toContain("isSavingConfig ||");
    expect(providerConfigsSource).toContain("const isSaveProviderConfigDisabled =");
    expect(providerConfigsSource).toContain("isProviderConfigDraftDirty,");
    expect(providerConfigsSource).toContain("!isProviderConfigDraftDirty(config, draft)");
    expect(providerConfigsSource).toContain("const isCloneProviderConfigDisabled =");
    expect(providerConfigsSource).toContain("if (!isSaveProviderConfigDisabled) {");
    expect(providerConfigsSource).toContain("disabled={isSaveProviderConfigDisabled}");
    expect(providerConfigsSource).toContain("disabled={isCloneProviderConfigDisabled}");
    expect(
      providerConfigsSource.match(/disabled=\{isProviderConfigDraftLocked\}/g) ?? []
    ).toHaveLength(18);
    expect(providerConfigsSource).not.toContain(
      "disabled={saveProviderConfigPending || isProviderConfigInvalid}"
    );
    expect(providerConfigsSource).not.toContain(
      "disabled={isSavingConfig || isProviderConfigInvalid}"
    );
    expect(providerConfigsSource).toContain(
      "const [editingConfigurationId, setEditingConfigurationId] = useState<string | null>(null);"
    );
    expect(providerConfigsSource).toContain("className={styles.providerConfigSummaryList}");
    expect(providerConfigsSource).toContain("aria-controls={editorId}");
    expect(providerConfigsSource).toContain("aria-expanded={isProviderConfigEditorOpen}");
    expect(providerConfigsSource).toContain("className={styles.providerConfigEditor}");
    expect(providerConfigsSource).not.toContain("<table");
  });

  it("renders a visual watermark preview for image and video settings", () => {
    const source = readFileSync(economySharedPath, "utf8");
    const watermarkSource = readFileSync(watermarkSectionPath, "utf8");
    const pageSource = readFileSync(catalogMutationsPath, "utf8");
    const contentSource = readFileSync(economyContentPath, "utf8");
    const styles = readFileSync(economyStylesPath, "utf8");

    expect(source).toContain("export function WatermarkPreviewPanel");
    expect(source).toContain("const watermarkPositionOptions");
    expect(source).toContain("const watermarkSizeOptions");
    expect(source).toContain('renderFrame("image", settings.previewImageUrl)');
    expect(source).toContain('renderFrame("video", settings.previewVideoFrameUrl)');
    expect(watermarkSource).toContain(
      "<WatermarkPreviewPanel text={text} settings={effectiveWatermarkDraft} />"
    );
    expect(source).toContain(
      'import { TemplateSecureMedia } from "@/components/templates/template-secure-media";'
    );
    expect(source).toContain("<TemplateSecureMedia");
    expect(source).toContain("surface: `economy-watermark-${kind}`");
    expect(source).toContain('surface: "economy-watermark-logo"');
    expect(source).not.toContain("<img src={sourceUrl}");
    expect(source).not.toContain("<img src={settings.logoUrl}");
    expect(source).toContain("className={styles.watermarkPreviewBadge}");
    expect(source).toContain("data-position={position}");
    expect(source).toContain("data-size={size}");
    expect(watermarkSource).toContain(
      'import { EconomySelectField } from "@/components/economy-page-select-field";'
    );
    expect(watermarkSource).toContain("onChange={(position) => onUpdateDraft({ position })}");
    expect(watermarkSource).toContain("onChange={(size) => onUpdateDraft({ size })}");
    expect(watermarkSource).toContain("options={positionOptions}");
    expect(watermarkSource).toContain("options={sizeOptions}");
    expect(watermarkSource).not.toContain("<select");
    expect(watermarkSource).not.toContain("<option");
    expect(source).toContain("settings.logoUrl");
    expect(pageSource).toContain("const isSaveWatermarkDisabled =");
    expect(pageSource).toContain("function requestSaveWatermark()");
    expect(source).toContain('export const WATERMARK_FORM_ID = "economy-watermark-settings-form";');
    expect(watermarkSource).toContain("event.preventDefault();");
    expect(watermarkSource).toContain("onSubmit();");
    expect(watermarkSource).toContain(
      'type="submit" form={WATERMARK_FORM_ID} disabled={isFormSaveDisabled}'
    );
    expect(watermarkSource).toContain("id={WATERMARK_FORM_ID}");
    expect(pageSource).toContain("if (isSaveWatermarkDisabled) {\n      return;\n    }");
    expect(watermarkSource).toContain("disabled={isSavePending}");
    expect(watermarkSource).toContain("const hasInvalidNumbers =");
    expect(source).toContain("text.watermarkPreviewImageTitle");
    expect(source).toContain("text.watermarkPreviewVideoFrameTitle");
    expect(watermarkSource).toContain("text.watermarkLoadingTitle");
    expect(watermarkSource).toContain("text.saveWatermarkAction");
    expect(contentSource).toContain('watermarkTitle: "Водяной знак"');
    expect(contentSource).toContain('watermarkLoadingTitle: "Загружаем водяной знак"');
    expect(contentSource).not.toContain('watermarkLoadingTitle: "Загружаем watermark"');
    expect(contentSource).toContain('watermarkLoadingTitle: "Loading watermark settings"');
    expect(watermarkSource).not.toContain("onClick={requestSaveWatermark}");
    expect(pageSource).not.toContain("onClick={() => saveWatermarkMutation.mutate()}");
    expect(styles).toContain(".watermarkPreviewGrid");
    expect(styles).toContain('.watermarkPreviewFrame[data-kind="video"]');
    expect(styles).toContain("color-mix(in srgb, var(--info) 22%, transparent)");
    expect(styles).toContain("color-mix(in srgb, var(--success) 18%, transparent)");
    expect(styles).toContain("right: 4%;");
    expect(styles).toContain("bottom: 4%;");
    expect(styles).toContain('.watermarkPreviewBadge[data-position="top-left"]');
    expect(styles).toContain('.watermarkPreviewBadge[data-size="large"]');
    expect(styles).toContain("opacity: var(--watermark-preview-opacity, 0.55);");
    expect(styles).toContain("background: color-mix(in srgb, var(--surface-0) 68%, transparent);");
    expect(styles).toContain("color: var(--text-strong);");
    expect(styles).not.toContain("rgba(8, 13, 23, 0.42)");
    expect(styles).not.toContain("rgba(255, 255, 255, 0.96)");
  });
});
