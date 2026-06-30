"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminCurrencyPacks,
  fetchAdminEconomyDashboardMetrics,
  fetchAdminEconomyLedger,
  fetchAdminEconomyPurchases,
  fetchAdminEconomySubscriptions,
  fetchAdminPaymentProviderConfigs,
  fetchAdminSubscriptionEvents,
  fetchAdminSubscriptionPlans,
  ECONOMY_QUERY_FILTER_MAX_LENGTH,
  normalizeAdminEconomyPurchasesQuery,
  normalizeAdminEconomySubscriptionsQuery,
  useAuthSession,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type UseEconomyPageControllerParams = {
  locale: Locale;
};

const ECONOMY_PAGE_SIZE = 20;

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

export function useEconomyPageController({ locale }: UseEconomyPageControllerParams) {
  const router = useRouter();
  const session = useAuthSession();
  const canLoadEconomy = session?.user.roles.includes("Admin") ?? false;
  const [ledgerSource, setLedgerSource] = useState("");
  const [ledgerPage, setLedgerPage] = useState(0);
  const [purchaseStatus, setPurchaseStatus] = useState("");
  const [purchaseProvider, setPurchaseProvider] = useState("");
  const [purchaseSearch, setPurchaseSearch] = useState("");
  const [purchasePage, setPurchasePage] = useState(0);
  const [subscriptionStatus, setSubscriptionStatus] = useState("");
  const [subscriptionProvider, setSubscriptionProvider] = useState("");
  const [subscriptionSearch, setSubscriptionSearch] = useState("");
  const [subscriptionPage, setSubscriptionPage] = useState(0);
  const [eventStatus, setEventStatus] = useState("");
  const [eventProvider, setEventProvider] = useState("");
  const debouncedPurchaseSearch = useDebouncedValue(purchaseSearch, 350);
  const debouncedSubscriptionSearch = useDebouncedValue(subscriptionSearch, 350);

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const updateLedgerSource = useCallback((value: string) => {
    setLedgerSource(value);
    setLedgerPage(0);
  }, []);

  const updatePurchaseStatus = useCallback((value: string) => {
    setPurchaseStatus(value);
    setPurchasePage(0);
  }, []);

  const updatePurchaseProvider = useCallback((value: string) => {
    setPurchaseProvider(value);
    setPurchasePage(0);
  }, []);

  const updatePurchaseSearch = useCallback((value: string) => {
    setPurchaseSearch(value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH));
    setPurchasePage(0);
  }, []);

  const updateSubscriptionStatus = useCallback((value: string) => {
    setSubscriptionStatus(value);
    setSubscriptionPage(0);
  }, []);

  const updateSubscriptionProvider = useCallback((value: string) => {
    setSubscriptionProvider(value);
    setSubscriptionPage(0);
  }, []);

  const updateSubscriptionSearch = useCallback((value: string) => {
    setSubscriptionSearch(value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH));
    setSubscriptionPage(0);
  }, []);

  const ledgerQueryParams = useMemo(
    () => ({
      skip: ledgerPage * ECONOMY_PAGE_SIZE,
      take: ECONOMY_PAGE_SIZE,
      source: ledgerSource || undefined,
    }),
    [ledgerPage, ledgerSource]
  );

  const ledgerQuery = useQuery({
    queryKey: adminQueryKeys.economyLedger(ledgerQueryParams),
    queryFn: ({ signal }) => fetchAdminEconomyLedger(ledgerQueryParams, signal),
    enabled: canLoadEconomy,
    placeholderData: keepPreviousData,
  });

  const purchasesQueryParams = useMemo(
    () =>
      normalizeAdminEconomyPurchasesQuery({
        skip: purchasePage * ECONOMY_PAGE_SIZE,
        take: ECONOMY_PAGE_SIZE,
        status: purchaseStatus,
        provider: purchaseProvider,
        search: debouncedPurchaseSearch,
      }),
    [debouncedPurchaseSearch, purchasePage, purchaseProvider, purchaseStatus]
  );

  const purchasesQuery = useQuery({
    queryKey: adminQueryKeys.economyPurchases(purchasesQueryParams),
    queryFn: ({ signal }) => fetchAdminEconomyPurchases(purchasesQueryParams, signal),
    enabled: canLoadEconomy,
    placeholderData: keepPreviousData,
  });

  const subscriptionsQueryParams = useMemo(
    () =>
      normalizeAdminEconomySubscriptionsQuery({
        skip: subscriptionPage * ECONOMY_PAGE_SIZE,
        take: ECONOMY_PAGE_SIZE,
        status: subscriptionStatus,
        provider: subscriptionProvider,
        search: debouncedSubscriptionSearch,
      }),
    [debouncedSubscriptionSearch, subscriptionPage, subscriptionProvider, subscriptionStatus]
  );

  const subscriptionsQuery = useQuery({
    queryKey: adminQueryKeys.economySubscriptions(subscriptionsQueryParams),
    queryFn: ({ signal }) => fetchAdminEconomySubscriptions(subscriptionsQueryParams, signal),
    enabled: canLoadEconomy,
    placeholderData: keepPreviousData,
  });

  const subscriptionPlansQuery = useQuery({
    queryKey: adminQueryKeys.economySubscriptionPlans,
    queryFn: ({ signal }) => fetchAdminSubscriptionPlans(signal),
    enabled: canLoadEconomy,
  });

  const providerConfigsQuery = useQuery({
    queryKey: adminQueryKeys.economyPaymentProviderConfigs,
    queryFn: ({ signal }) => fetchAdminPaymentProviderConfigs(signal),
    enabled: canLoadEconomy,
  });

  const subscriptionEventsQuery = useQuery({
    queryKey: adminQueryKeys.economySubscriptionEvents(
      eventProvider || "all",
      eventStatus || "all"
    ),
    queryFn: ({ signal }) =>
      fetchAdminSubscriptionEvents({
        take: 20,
        provider: eventProvider || undefined,
        status: eventStatus || undefined,
      }, signal),
    enabled: canLoadEconomy,
  });

  const packsQuery = useQuery({
    queryKey: adminQueryKeys.economyPacks,
    queryFn: ({ signal }) => fetchAdminCurrencyPacks(signal),
    enabled: canLoadEconomy,
  });

  const economyDashboardMetricsQuery = useQuery({
    queryKey: adminQueryKeys.economyDashboardMetrics,
    queryFn: ({ signal }) => fetchAdminEconomyDashboardMetrics(signal),
    enabled: canLoadEconomy,
    placeholderData: keepPreviousData,
    staleTime: 60_000,
  });

  const visiblePurchasesPage = purchasesQuery.isPlaceholderData ? undefined : purchasesQuery.data;
  const visibleSubscriptionsPage = subscriptionsQuery.isPlaceholderData
    ? undefined
    : subscriptionsQuery.data;
  const visibleLedgerPage = ledgerQuery.isPlaceholderData ? undefined : ledgerQuery.data;
  const ledgerIsRefreshing = ledgerQuery.isFetching && ledgerQuery.isPlaceholderData;
  const purchasesIsRefreshing = purchasesQuery.isFetching && purchasesQuery.isPlaceholderData;
  const subscriptionsIsRefreshing =
    subscriptionsQuery.isFetching && subscriptionsQuery.isPlaceholderData;

  const ledgerItems = useMemo(() => visibleLedgerPage?.items ?? [], [visibleLedgerPage?.items]);
  const purchaseItems = useMemo(
    () => visiblePurchasesPage?.items ?? [],
    [visiblePurchasesPage?.items]
  );
  const subscriptionItems = useMemo(
    () => visibleSubscriptionsPage?.items ?? [],
    [visibleSubscriptionsPage?.items]
  );
  const subscriptionPlans = subscriptionPlansQuery.data ?? [];
  const providerConfigs = providerConfigsQuery.data ?? [];
  const subscriptionEvents = useMemo(
    () => subscriptionEventsQuery.data?.items ?? [],
    [subscriptionEventsQuery.data?.items]
  );
  const packs = useMemo(() => packsQuery.data ?? [], [packsQuery.data]);

  const refetchAll = useCallback(async () => {
    if (!canLoadEconomy) {
      return;
    }

    await Promise.allSettled([
      ledgerQuery.refetch(),
      purchasesQuery.refetch(),
      subscriptionsQuery.refetch(),
      subscriptionPlansQuery.refetch(),
      providerConfigsQuery.refetch(),
      subscriptionEventsQuery.refetch(),
      packsQuery.refetch(),
      economyDashboardMetricsQuery.refetch(),
    ]);
  }, [
    economyDashboardMetricsQuery,
    canLoadEconomy,
    ledgerQuery,
    packsQuery,
    providerConfigsQuery,
    purchasesQuery,
    subscriptionEventsQuery,
    subscriptionPlansQuery,
    subscriptionsQuery,
  ]);

  const metrics = useMemo(() => {
    const credited = economyDashboardMetricsQuery.data?.totalWalletCredits ?? 0;
    const debited = economyDashboardMetricsQuery.data?.totalWalletDebits ?? 0;
    const grossRevenue = economyDashboardMetricsQuery.data?.revenueThisWeek ?? 0;
    const revenueCurrencyCode = economyDashboardMetricsQuery.data?.currencyCode ?? "USD";
    const activePacks = packs.filter((pack) => pack.isActive).length;

    return { credited, debited, grossRevenue, revenueCurrencyCode, activePacks };
  }, [
    economyDashboardMetricsQuery.data?.currencyCode,
    economyDashboardMetricsQuery.data?.revenueThisWeek,
    economyDashboardMetricsQuery.data?.totalWalletCredits,
    economyDashboardMetricsQuery.data?.totalWalletDebits,
    packs,
  ]);

  const activeSubscriptions = economyDashboardMetricsQuery.data?.activeSubscriptions ?? 0;
  const renewalStops = economyDashboardMetricsQuery.data?.renewalStops ?? 0;
  const activePlans = subscriptionPlans.filter((item) => item.isActive).length;
  const enabledRoutes = providerConfigs.filter((item) => item.isEnabled).length;
  const premiumMetrics = { activeSubscriptions, renewalStops, activePlans, enabledRoutes };

  const isLoading =
    ledgerQuery.isLoading ||
    purchasesQuery.isLoading ||
    subscriptionsQuery.isLoading ||
    subscriptionPlansQuery.isLoading ||
    providerConfigsQuery.isLoading ||
    subscriptionEventsQuery.isLoading ||
    packsQuery.isLoading ||
    economyDashboardMetricsQuery.isLoading;

  const hasError =
    ledgerQuery.isError ||
    purchasesQuery.isError ||
    subscriptionsQuery.isError ||
    subscriptionPlansQuery.isError ||
    providerConfigsQuery.isError ||
    subscriptionEventsQuery.isError ||
    packsQuery.isError ||
    economyDashboardMetricsQuery.isError;

  const hasResolvedData =
    ledgerQuery.isSuccess ||
    purchasesQuery.isSuccess ||
    subscriptionsQuery.isSuccess ||
    subscriptionPlansQuery.isSuccess ||
    providerConfigsQuery.isSuccess ||
    subscriptionEventsQuery.isSuccess ||
    packsQuery.isSuccess ||
    economyDashboardMetricsQuery.isSuccess;

  const economyError =
    ledgerQuery.error ??
    purchasesQuery.error ??
    subscriptionsQuery.error ??
    subscriptionPlansQuery.error ??
    providerConfigsQuery.error ??
    subscriptionEventsQuery.error ??
    packsQuery.error ??
    economyDashboardMetricsQuery.error ??
    null;

  const isFetching =
    ledgerQuery.isFetching ||
    purchasesQuery.isFetching ||
    subscriptionsQuery.isFetching ||
    subscriptionPlansQuery.isFetching ||
    providerConfigsQuery.isFetching ||
    subscriptionEventsQuery.isFetching ||
    packsQuery.isFetching ||
    economyDashboardMetricsQuery.isFetching;

  return {
    eventProvider,
    eventStatus,
    hasBlockingError: hasError && !hasResolvedData,
    hasPartialError: hasError && hasResolvedData,
    economyError,
    isFetching,
    isLoading,
    ledgerHasMore: visibleLedgerPage?.hasMore ?? false,
    ledgerItems,
    ledgerIsFetching: ledgerQuery.isFetching,
    ledgerIsRefreshing,
    ledgerPage,
    ledgerSource,
    metrics,
    packs,
    providerConfigs,
    purchaseItems,
    purchasePage,
    purchaseProvider,
    purchaseSearch,
    purchaseStatus,
    purchasesIsFetching: purchasesQuery.isFetching,
    purchasesIsRefreshing,
    premiumMetrics,
    setEventProvider,
    setEventStatus,
    setLedgerPage,
    setLedgerSource: updateLedgerSource,
    setPurchasePage,
    setPurchaseProvider: updatePurchaseProvider,
    setPurchaseSearch: updatePurchaseSearch,
    setPurchaseStatus: updatePurchaseStatus,
    setSubscriptionPage,
    setSubscriptionProvider: updateSubscriptionProvider,
    setSubscriptionSearch: updateSubscriptionSearch,
    setSubscriptionStatus: updateSubscriptionStatus,
    subscriptionEvents,
    subscriptionItems,
    subscriptionPage,
    subscriptionSearch,
    subscriptionsHasMore: visibleSubscriptionsPage?.hasMore ?? false,
    subscriptionsIsFetching: subscriptionsQuery.isFetching,
    subscriptionsIsRefreshing,
    subscriptionPlans,
    subscriptionProvider,
    subscriptionStatus,
    purchasesHasMore: visiblePurchasesPage?.hasMore ?? false,
    refetchAll,
  };
}
