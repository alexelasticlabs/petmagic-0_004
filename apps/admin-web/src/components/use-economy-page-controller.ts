"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

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
    useAuthSession,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type UseEconomyPageControllerParams = {
    locale: Locale;
};

export function useEconomyPageController({ locale }: UseEconomyPageControllerParams) {
    const router = useRouter();
    const session = useAuthSession();
    const [ledgerSource, setLedgerSource] = useState("");
    const [purchaseStatus, setPurchaseStatus] = useState("");
    const [subscriptionStatus, setSubscriptionStatus] = useState("");
    const [subscriptionProvider, setSubscriptionProvider] = useState("");
    const [eventStatus, setEventStatus] = useState("");
    const [eventProvider, setEventProvider] = useState("");

    useEffect(() => {
        if (!session) {
            ensureAdminSession(locale, router);
        }
    }, [locale, router, session]);

    const ledgerQuery = useQuery({
        queryKey: adminQueryKeys.economyLedger(ledgerSource || "all", "all"),
        queryFn: () => fetchAdminEconomyLedger({ take: 20, source: ledgerSource || undefined }),
    });

    const purchasesQuery = useQuery({
        queryKey: adminQueryKeys.economyPurchases(purchaseStatus || "all"),
        queryFn: () => fetchAdminEconomyPurchases({ take: 20, status: purchaseStatus || undefined }),
    });

    const subscriptionsQuery = useQuery({
        queryKey: adminQueryKeys.economySubscriptions(subscriptionStatus || "all", subscriptionProvider || "all"),
        queryFn: () =>
            fetchAdminEconomySubscriptions({
                take: 20,
                status: subscriptionStatus || undefined,
                provider: subscriptionProvider || undefined,
            }),
    });

    const subscriptionPlansQuery = useQuery({
        queryKey: adminQueryKeys.economySubscriptionPlans,
        queryFn: fetchAdminSubscriptionPlans,
    });

    const providerConfigsQuery = useQuery({
        queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        queryFn: fetchAdminPaymentProviderConfigs,
    });

    const subscriptionEventsQuery = useQuery({
        queryKey: adminQueryKeys.economySubscriptionEvents(eventProvider || "all", eventStatus || "all"),
        queryFn: () =>
            fetchAdminSubscriptionEvents({
                take: 20,
                provider: eventProvider || undefined,
                status: eventStatus || undefined,
            }),
    });

    const packsQuery = useQuery({
        queryKey: adminQueryKeys.economyPacks,
        queryFn: fetchAdminCurrencyPacks,
    });

    const ledgerItems = useMemo(() => ledgerQuery.data?.items ?? [], [ledgerQuery.data?.items]);
    const purchaseItems = useMemo(() => purchasesQuery.data?.items ?? [], [purchasesQuery.data?.items]);
    const subscriptionItems = useMemo(() => subscriptionsQuery.data?.items ?? [], [subscriptionsQuery.data?.items]);
    const subscriptionPlans = subscriptionPlansQuery.data ?? [];
    const providerConfigs = providerConfigsQuery.data ?? [];
    const subscriptionEvents = useMemo(
        () => subscriptionEventsQuery.data?.items ?? [],
        [subscriptionEventsQuery.data?.items],
    );
    const packs = useMemo(() => packsQuery.data ?? [], [packsQuery.data]);

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

    return {
        eventProvider,
        eventStatus,
        hasError,
        isLoading,
        ledgerItems,
        ledgerSource,
        metrics,
        packs,
        providerConfigs,
        purchaseItems,
        purchaseStatus,
        premiumMetrics,
        setEventProvider,
        setEventStatus,
        setLedgerSource,
        setPurchaseStatus,
        setSubscriptionProvider,
        setSubscriptionStatus,
        subscriptionEvents,
        subscriptionItems,
        subscriptionPlans,
        subscriptionProvider,
        subscriptionStatus,
    };
}
