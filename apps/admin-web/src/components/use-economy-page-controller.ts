"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { type EconomyWorkspace } from "@/components/economy-page-workspace";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminCurrencyPacks,
  fetchAdminEconomyDashboardMetrics,
  fetchAdminEconomyIncidents,
  fetchAdminEconomyLedger,
  fetchAdminEconomyPurchases,
  fetchAdminEconomySubscriptions,
  fetchAdminPaymentProviderConfigs,
  fetchAdminSubscriptionEvents,
  fetchAdminSubscriptionPlans,
  ECONOMY_QUERY_FILTER_MAX_LENGTH,
  normalizeAdminEconomyPurchasesQuery,
  normalizeAdminEconomySubscriptionsQuery,
  normalizeAdminEconomyIncidentsQuery,
  useAuthSession,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type UseEconomyPageControllerParams = {
  locale: Locale;
  workspace: EconomyWorkspace;
};

const ECONOMY_PAGE_SIZE = 20;

function readEconomyPageIndex(value: string | null): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed - 1 : 0;
}

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

export function useEconomyPageController({ locale, workspace }: UseEconomyPageControllerParams) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const session = useAuthSession();
  const canLoadEconomy = session?.user.roles.includes("Admin") ?? false;
  const shouldLoadOverview = workspace === "overview";
  const shouldLoadCatalog = workspace === "catalog";
  const shouldLoadSubscriptions = workspace === "subscriptions";
  const shouldLoadPayments = workspace === "payments";
  const [ledgerSource, setLedgerSource] = useState("");
  const [ledgerPage, setLedgerPage] = useState(0);
  const [purchaseStatus, setPurchaseStatus] = useState(() =>
    (searchParams.get("purchaseStatus") ?? "").trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
  );
  const [purchaseProvider, setPurchaseProvider] = useState(() =>
    (searchParams.get("purchaseProvider") ?? "").trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
  );
  const [purchaseSearch, setPurchaseSearch] = useState(() =>
    (searchParams.get("purchaseSearch") ?? "").trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
  );
  const [purchasePage, setPurchasePage] = useState(() =>
    readEconomyPageIndex(searchParams.get("purchasePage"))
  );
  const [subscriptionStatus, setSubscriptionStatus] = useState("");
  const [subscriptionProvider, setSubscriptionProvider] = useState("");
  const [subscriptionSearch, setSubscriptionSearch] = useState("");
  const [subscriptionPage, setSubscriptionPage] = useState(0);
  const [eventStatus, setEventStatus] = useState("");
  const [eventProvider, setEventProvider] = useState("");
  const [eventPage, setEventPage] = useState(0);
  const [incidentStatus, setIncidentStatus] = useState(
    () =>
      (searchParams.get("incidentStatus") ?? "open")
        .trim()
        .slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH) || "open"
  );
  const [incidentCategory, setIncidentCategory] = useState(() =>
    (searchParams.get("incidentCategory") ?? "").trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
  );
  const [incidentType, setIncidentType] = useState(() =>
    (searchParams.get("incidentType") ?? "").trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
  );
  const [incidentPage, setIncidentPage] = useState(() =>
    readEconomyPageIndex(searchParams.get("incidentPage"))
  );
  const debouncedPurchaseSearch = useDebouncedValue(purchaseSearch, 350);
  const debouncedSubscriptionSearch = useDebouncedValue(subscriptionSearch, 350);
  const debouncedIncidentType = useDebouncedValue(incidentType, 350);

  const applyUrlState = useCallback((nextSearchParams: URLSearchParams) => {
    setPurchaseStatus(
      (nextSearchParams.get("purchaseStatus") ?? "")
        .trim()
        .slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
    );
    setPurchaseProvider(
      (nextSearchParams.get("purchaseProvider") ?? "")
        .trim()
        .slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
    );
    setPurchaseSearch(
      (nextSearchParams.get("purchaseSearch") ?? "")
        .trim()
        .slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
    );
    setPurchasePage(readEconomyPageIndex(nextSearchParams.get("purchasePage")));
    setIncidentStatus(
      (nextSearchParams.get("incidentStatus") ?? "open")
        .trim()
        .slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH) || "open"
    );
    setIncidentCategory(
      (nextSearchParams.get("incidentCategory") ?? "")
        .trim()
        .slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
    );
    setIncidentType(
      (nextSearchParams.get("incidentType") ?? "").trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH)
    );
    setIncidentPage(readEconomyPageIndex(nextSearchParams.get("incidentPage")));
  }, []);

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const updateLedgerSource = useCallback((value: string) => {
    setLedgerSource(value.trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH));
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

  const updateEventStatus = useCallback((value: string) => {
    setEventStatus(value);
    setEventPage(0);
  }, []);

  const updateEventProvider = useCallback((value: string) => {
    setEventProvider(value);
    setEventPage(0);
  }, []);

  const updateIncidentStatus = useCallback((value: string) => {
    setIncidentStatus(value);
    setIncidentPage(0);
  }, []);

  const updateIncidentCategory = useCallback((value: string) => {
    setIncidentCategory(value);
    setIncidentPage(0);
  }, []);

  const updateIncidentType = useCallback((value: string) => {
    setIncidentType(value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH));
    setIncidentPage(0);
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
    enabled: canLoadEconomy && shouldLoadOverview,
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
    enabled: canLoadEconomy && shouldLoadOverview,
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
    enabled: canLoadEconomy && shouldLoadSubscriptions,
    placeholderData: keepPreviousData,
  });

  const subscriptionPlansQuery = useQuery({
    queryKey: adminQueryKeys.economySubscriptionPlans,
    queryFn: ({ signal }) => fetchAdminSubscriptionPlans(signal),
    enabled: canLoadEconomy && shouldLoadSubscriptions,
  });

  const providerConfigsQuery = useQuery({
    queryKey: adminQueryKeys.economyPaymentProviderConfigs,
    queryFn: ({ signal }) => fetchAdminPaymentProviderConfigs(signal),
    enabled: canLoadEconomy && shouldLoadPayments,
  });

  const subscriptionEventsQuery = useQuery({
    queryKey: adminQueryKeys.economySubscriptionEvents(
      eventProvider || "all",
      eventStatus || "all",
      eventPage
    ),
    queryFn: ({ signal }) =>
      fetchAdminSubscriptionEvents(
        {
          skip: eventPage * ECONOMY_PAGE_SIZE,
          take: ECONOMY_PAGE_SIZE,
          provider: eventProvider || undefined,
          status: eventStatus || undefined,
        },
        signal
      ),
    enabled: canLoadEconomy && shouldLoadSubscriptions,
    placeholderData: keepPreviousData,
  });

  const incidentsQueryParams = useMemo(
    () =>
      normalizeAdminEconomyIncidentsQuery({
        skip: incidentPage * ECONOMY_PAGE_SIZE,
        take: ECONOMY_PAGE_SIZE,
        status: incidentStatus,
        category: incidentCategory,
        type: debouncedIncidentType,
      }),
    [debouncedIncidentType, incidentCategory, incidentPage, incidentStatus]
  );

  const incidentsQuery = useQuery({
    queryKey: adminQueryKeys.economyIncidents(incidentsQueryParams),
    queryFn: ({ signal }) => fetchAdminEconomyIncidents(incidentsQueryParams, signal),
    enabled: canLoadEconomy && shouldLoadPayments,
    placeholderData: keepPreviousData,
  });

  const packsQuery = useQuery({
    queryKey: adminQueryKeys.economyPacks,
    queryFn: ({ signal }) => fetchAdminCurrencyPacks(signal),
    enabled: canLoadEconomy && shouldLoadCatalog,
  });

  const economyDashboardMetricsQuery = useQuery({
    queryKey: adminQueryKeys.economyDashboardMetricsPeriod(),
    queryFn: ({ signal }) => fetchAdminEconomyDashboardMetrics({ signal }),
    enabled: canLoadEconomy && shouldLoadOverview,
    placeholderData: keepPreviousData,
    staleTime: 60_000,
  });

  const visiblePurchasesPage = purchasesQuery.data;
  const visibleSubscriptionsPage = subscriptionsQuery.data;
  const visibleLedgerPage = ledgerQuery.data;
  const visibleSubscriptionEventsPage = subscriptionEventsQuery.data;
  const ledgerIsRefreshing = ledgerQuery.isFetching && ledgerQuery.isPlaceholderData;
  const purchasesIsRefreshing = purchasesQuery.isFetching && purchasesQuery.isPlaceholderData;
  const subscriptionsIsRefreshing =
    subscriptionsQuery.isFetching && subscriptionsQuery.isPlaceholderData;
  const subscriptionEventsIsRefreshing =
    subscriptionEventsQuery.isFetching && subscriptionEventsQuery.isPlaceholderData;
  const incidentsIsRefreshing = incidentsQuery.isFetching && incidentsQuery.isPlaceholderData;

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
    () => visibleSubscriptionEventsPage?.items ?? [],
    [visibleSubscriptionEventsPage?.items]
  );
  const visibleIncidentsPage = incidentsQuery.data;
  const incidentItems = useMemo(
    () => visibleIncidentsPage?.items ?? [],
    [visibleIncidentsPage?.items]
  );
  const packs = useMemo(() => packsQuery.data ?? [], [packsQuery.data]);

  const refetchAll = useCallback(async () => {
    if (!canLoadEconomy) {
      return;
    }

    const refreshes = [
      shouldLoadOverview ? ledgerQuery.refetch() : null,
      shouldLoadOverview ? purchasesQuery.refetch() : null,
      shouldLoadSubscriptions ? subscriptionsQuery.refetch() : null,
      shouldLoadSubscriptions ? subscriptionPlansQuery.refetch() : null,
      shouldLoadPayments ? providerConfigsQuery.refetch() : null,
      shouldLoadSubscriptions ? subscriptionEventsQuery.refetch() : null,
      shouldLoadPayments ? incidentsQuery.refetch() : null,
      shouldLoadCatalog ? packsQuery.refetch() : null,
      shouldLoadOverview ? economyDashboardMetricsQuery.refetch() : null,
    ].filter((refresh) => refresh !== null);

    await Promise.allSettled(refreshes);
  }, [
    economyDashboardMetricsQuery,
    canLoadEconomy,
    ledgerQuery,
    incidentsQuery,
    packsQuery,
    providerConfigsQuery,
    purchasesQuery,
    subscriptionEventsQuery,
    subscriptionPlansQuery,
    subscriptionsQuery,
    shouldLoadCatalog,
    shouldLoadOverview,
    shouldLoadPayments,
    shouldLoadSubscriptions,
  ]);

  const metrics = useMemo(() => {
    const credited = economyDashboardMetricsQuery.data?.totalWalletCredits ?? 0;
    const debited = economyDashboardMetricsQuery.data?.totalWalletDebits ?? 0;
    const grossRevenue = economyDashboardMetricsQuery.data?.revenueThisWeek ?? 0;
    const revenuePreviousWeek = economyDashboardMetricsQuery.data?.revenuePreviousWeek ?? 0;
    const revenueCurrencyCode = economyDashboardMetricsQuery.data?.currencyCode ?? "USD";
    const purchasesThisWeek = economyDashboardMetricsQuery.data?.purchasesThisWeek ?? 0;
    const purchasesPreviousWeek = economyDashboardMetricsQuery.data?.purchasesPreviousWeek ?? 0;
    const successfulPaymentsThisWeek =
      economyDashboardMetricsQuery.data?.successfulPaymentsThisWeek ?? 0;
    const successfulPaymentsPreviousWeek =
      economyDashboardMetricsQuery.data?.successfulPaymentsPreviousWeek ?? 0;
    const failedPaymentsThisWeek = economyDashboardMetricsQuery.data?.failedPaymentsThisWeek ?? 0;
    const failedPaymentsPreviousWeek =
      economyDashboardMetricsQuery.data?.failedPaymentsPreviousWeek ?? 0;
    const activePacks = packs.filter((pack) => pack.isActive).length;

    return {
      credited,
      debited,
      grossRevenue,
      revenuePreviousWeek,
      revenueCurrencyCode,
      purchasesThisWeek,
      purchasesPreviousWeek,
      successfulPaymentsThisWeek,
      successfulPaymentsPreviousWeek,
      failedPaymentsThisWeek,
      failedPaymentsPreviousWeek,
      activePacks,
    };
  }, [
    economyDashboardMetricsQuery.data?.currencyCode,
    economyDashboardMetricsQuery.data?.failedPaymentsPreviousWeek,
    economyDashboardMetricsQuery.data?.failedPaymentsThisWeek,
    economyDashboardMetricsQuery.data?.revenueThisWeek,
    economyDashboardMetricsQuery.data?.revenuePreviousWeek,
    economyDashboardMetricsQuery.data?.purchasesPreviousWeek,
    economyDashboardMetricsQuery.data?.purchasesThisWeek,
    economyDashboardMetricsQuery.data?.successfulPaymentsPreviousWeek,
    economyDashboardMetricsQuery.data?.successfulPaymentsThisWeek,
    economyDashboardMetricsQuery.data?.totalWalletCredits,
    economyDashboardMetricsQuery.data?.totalWalletDebits,
    packs,
  ]);

  const activeSubscriptions = economyDashboardMetricsQuery.data?.activeSubscriptions ?? 0;
  const renewalStops = economyDashboardMetricsQuery.data?.renewalStops ?? 0;
  const activePlans = subscriptionPlans.filter((item) => item.isActive).length;
  const enabledRoutes = providerConfigs.filter((item) => item.isEnabled).length;
  const premiumMetrics = { activeSubscriptions, renewalStops, activePlans, enabledRoutes };

  const activeQueryIsLoading =
    (shouldLoadOverview && ledgerQuery.isLoading) ||
    (shouldLoadOverview && purchasesQuery.isLoading) ||
    (shouldLoadSubscriptions && subscriptionsQuery.isLoading) ||
    (shouldLoadSubscriptions && subscriptionPlansQuery.isLoading) ||
    (shouldLoadPayments && providerConfigsQuery.isLoading) ||
    (shouldLoadSubscriptions && subscriptionEventsQuery.isLoading) ||
    (shouldLoadPayments && incidentsQuery.isLoading) ||
    (shouldLoadCatalog && packsQuery.isLoading) ||
    (shouldLoadOverview && economyDashboardMetricsQuery.isLoading);

  const hasError =
    (shouldLoadOverview && ledgerQuery.isError) ||
    (shouldLoadOverview && purchasesQuery.isError) ||
    (shouldLoadSubscriptions && subscriptionsQuery.isError) ||
    (shouldLoadSubscriptions && subscriptionPlansQuery.isError) ||
    (shouldLoadPayments && providerConfigsQuery.isError) ||
    (shouldLoadSubscriptions && subscriptionEventsQuery.isError) ||
    (shouldLoadPayments && incidentsQuery.isError) ||
    (shouldLoadCatalog && packsQuery.isError) ||
    (shouldLoadOverview && economyDashboardMetricsQuery.isError);

  const hasResolvedData =
    (shouldLoadOverview && ledgerQuery.isSuccess) ||
    (shouldLoadOverview && purchasesQuery.isSuccess) ||
    (shouldLoadSubscriptions && subscriptionsQuery.isSuccess) ||
    (shouldLoadSubscriptions && subscriptionPlansQuery.isSuccess) ||
    (shouldLoadPayments && providerConfigsQuery.isSuccess) ||
    (shouldLoadSubscriptions && subscriptionEventsQuery.isSuccess) ||
    (shouldLoadPayments && incidentsQuery.isSuccess) ||
    (shouldLoadCatalog && packsQuery.isSuccess) ||
    (shouldLoadOverview && economyDashboardMetricsQuery.isSuccess);

  const isLoading = activeQueryIsLoading && !hasResolvedData;

  const economyError =
    (shouldLoadOverview ? ledgerQuery.error : null) ??
    (shouldLoadOverview ? purchasesQuery.error : null) ??
    (shouldLoadSubscriptions ? subscriptionsQuery.error : null) ??
    (shouldLoadSubscriptions ? subscriptionPlansQuery.error : null) ??
    (shouldLoadPayments ? providerConfigsQuery.error : null) ??
    (shouldLoadSubscriptions ? subscriptionEventsQuery.error : null) ??
    (shouldLoadPayments ? incidentsQuery.error : null) ??
    (shouldLoadCatalog ? packsQuery.error : null) ??
    (shouldLoadOverview ? economyDashboardMetricsQuery.error : null) ??
    null;

  const isFetching =
    (shouldLoadOverview && ledgerQuery.isFetching) ||
    (shouldLoadOverview && purchasesQuery.isFetching) ||
    (shouldLoadSubscriptions && subscriptionsQuery.isFetching) ||
    (shouldLoadSubscriptions && subscriptionPlansQuery.isFetching) ||
    (shouldLoadPayments && providerConfigsQuery.isFetching) ||
    (shouldLoadSubscriptions && subscriptionEventsQuery.isFetching) ||
    (shouldLoadPayments && incidentsQuery.isFetching) ||
    (shouldLoadCatalog && packsQuery.isFetching) ||
    (shouldLoadOverview && economyDashboardMetricsQuery.isFetching);

  return {
    applyUrlState,
    eventPage,
    eventProvider,
    eventStatus,
    hasBlockingError: hasError && !hasResolvedData,
    hasPartialError: hasError && hasResolvedData,
    economyError,
    isFetching,
    incidentItems,
    incidentCategory,
    incidentPage,
    incidentStatus,
    incidentType,
    incidentsHasMore: visibleIncidentsPage?.hasMore ?? false,
    incidentsIsFetching: incidentsQuery.isFetching,
    incidentsIsRefreshing,
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
    setEventPage,
    setEventProvider: updateEventProvider,
    setEventStatus: updateEventStatus,
    setIncidentPage,
    setIncidentCategory: updateIncidentCategory,
    setIncidentStatus: updateIncidentStatus,
    setIncidentType: updateIncidentType,
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
    subscriptionEventsHasMore: visibleSubscriptionEventsPage?.hasMore ?? false,
    subscriptionEventsIsFetching: subscriptionEventsQuery.isFetching,
    subscriptionEventsIsRefreshing,
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
