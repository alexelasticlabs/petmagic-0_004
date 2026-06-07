"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminCurrencyPacks,
  fetchAdminEconomyLedger,
  fetchAdminEconomyPurchases,
  fetchAdminEconomySubscriptions,
  fetchAdminPaymentProviderConfigs,
  fetchAdminSubscriptionEvents,
  fetchAdminSubscriptionPlans,
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
  const [ledgerSource, setLedgerSource] = useState("");
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
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  const updatePurchaseStatus = useCallback((value: string) => {
    setPurchaseStatus(value);
    setPurchasePage(0);
  }, []);

  const updatePurchaseProvider = useCallback((value: string) => {
    setPurchaseProvider(value);
    setPurchasePage(0);
  }, []);

  const updatePurchaseSearch = useCallback((value: string) => {
    setPurchaseSearch(value);
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
    setSubscriptionSearch(value);
    setSubscriptionPage(0);
  }, []);

  const ledgerQuery = useQuery({
    queryKey: adminQueryKeys.economyLedger(ledgerSource || "all", "all"),
    queryFn: ({ signal }) =>
      fetchAdminEconomyLedger({ take: 20, source: ledgerSource || undefined }, signal),
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
    placeholderData: keepPreviousData,
  });

  const subscriptionPlansQuery = useQuery({
    queryKey: adminQueryKeys.economySubscriptionPlans,
    queryFn: ({ signal }) => fetchAdminSubscriptionPlans(signal),
  });

  const providerConfigsQuery = useQuery({
    queryKey: adminQueryKeys.economyPaymentProviderConfigs,
    queryFn: ({ signal }) => fetchAdminPaymentProviderConfigs(signal),
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
  });

  const packsQuery = useQuery({
    queryKey: adminQueryKeys.economyPacks,
    queryFn: ({ signal }) => fetchAdminCurrencyPacks(signal),
  });

  const ledgerItems = useMemo(() => ledgerQuery.data?.items ?? [], [ledgerQuery.data?.items]);
  const purchaseItems = useMemo(
    () => purchasesQuery.data?.items ?? [],
    [purchasesQuery.data?.items]
  );
  const subscriptionItems = useMemo(
    () => subscriptionsQuery.data?.items ?? [],
    [subscriptionsQuery.data?.items]
  );
  const subscriptionPlans = subscriptionPlansQuery.data ?? [];
  const providerConfigs = providerConfigsQuery.data ?? [];
  const subscriptionEvents = useMemo(
    () => subscriptionEventsQuery.data?.items ?? [],
    [subscriptionEventsQuery.data?.items]
  );
  const packs = useMemo(() => packsQuery.data ?? [], [packsQuery.data]);

  const refetchAll = useCallback(async () => {
    await Promise.all([
      ledgerQuery.refetch(),
      purchasesQuery.refetch(),
      subscriptionsQuery.refetch(),
      subscriptionPlansQuery.refetch(),
      providerConfigsQuery.refetch(),
      subscriptionEventsQuery.refetch(),
      packsQuery.refetch(),
    ]);
  }, [
    ledgerQuery,
    packsQuery,
    providerConfigsQuery,
    purchasesQuery,
    subscriptionEventsQuery,
    subscriptionPlansQuery,
    subscriptionsQuery,
  ]);

  const metrics = useMemo(() => {
    const credited = ledgerItems
      .filter((item) => item.delta > 0)
      .reduce((sum, item) => sum + item.delta, 0);
    const debited = ledgerItems
      .filter((item) => item.delta < 0)
      .reduce((sum, item) => sum + Math.abs(item.delta), 0);
    const grossRevenue = purchaseItems.reduce((sum, item) => sum + item.priceAmount, 0);
    const activePacks = packs.filter((pack) => pack.isActive).length;

    return { credited, debited, grossRevenue, activePacks };
  }, [ledgerItems, packs, purchaseItems]);

  const activeSubscriptions = subscriptionItems.filter((item) => item.status === "active").length;
  const renewalStops = subscriptionItems.filter((item) => item.cancelAtPeriodEnd).length;
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
    packsQuery.isLoading;

  const hasError =
    ledgerQuery.isError ||
    purchasesQuery.isError ||
    subscriptionsQuery.isError ||
    subscriptionPlansQuery.isError ||
    providerConfigsQuery.isError ||
    subscriptionEventsQuery.isError ||
    packsQuery.isError;

  const isFetching =
    ledgerQuery.isFetching ||
    purchasesQuery.isFetching ||
    subscriptionsQuery.isFetching ||
    subscriptionPlansQuery.isFetching ||
    providerConfigsQuery.isFetching ||
    subscriptionEventsQuery.isFetching ||
    packsQuery.isFetching;

  return {
    eventProvider,
    eventStatus,
    hasError,
    isFetching,
    isLoading,
    ledgerItems,
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
    premiumMetrics,
    setEventProvider,
    setEventStatus,
    setLedgerSource,
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
    subscriptionsHasMore: subscriptionsQuery.data?.hasMore ?? false,
    subscriptionsIsFetching: subscriptionsQuery.isFetching,
    subscriptionPlans,
    subscriptionProvider,
    subscriptionStatus,
    purchasesHasMore: purchasesQuery.data?.hasMore ?? false,
    refetchAll,
  };
}
