"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { type EconomyPageText } from "@/components/economy-page.content";
import {
  createDefaultProviderConfigDraft,
  isPackDraftDirty,
  isProviderConfigDraftDirty,
  isSubscriptionPlanDraftDirty,
  toDraft,
  toCurrencyPackPayload,
  toProviderConfigCreatePayload,
  toProviderConfigDraft,
  toProviderConfigMatchPayload,
  toProviderConfigPayload,
  toSubscriptionPlanDraft,
  toSubscriptionPlanPayload,
  type PackDraft,
  type ProviderConfigCreateDraft,
  type ProviderConfigDraft,
  type ProviderConfigMatchDraft,
  type SubscriptionPlanDraft,
} from "@/components/economy-page.helpers";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  cloneAdminPaymentProviderConfig,
  createAdminPaymentProviderConfig,
  deleteAdminPaymentProviderConfig,
  fetchAdminWatermarkSettings,
  testAdminPaymentProviderConfigMatch,
  updateAdminCurrencyPack,
  updateAdminPaymentProviderConfig,
  updateAdminSubscriptionPlan,
  updateAdminWatermarkSettings,
  type AdminCurrencyPack,
  type AdminPaymentProviderConfiguration,
  type AdminPaymentProviderConfigurationMatch,
  type AdminSubscriptionPlan,
  type AdminWatermarkSettings,
} from "@/lib/api-client";

type FeedbackSetter = (feedback: { tone: "success" | "danger"; message: string } | null) => void;

type UseEconomyCatalogMutationsParams = {
  text: EconomyPageText;
  canManageEconomy: boolean;
  packs: AdminCurrencyPack[];
  subscriptionPlans: AdminSubscriptionPlan[];
  providerConfigs: AdminPaymentProviderConfiguration[];
  setFeedback: FeedbackSetter;
};

function assertCanManage(canManageEconomy: boolean, message: string) {
  if (!canManageEconomy) {
    throw new Error(message);
  }
}

export function useEconomyCatalogMutations({
  text,
  canManageEconomy,
  packs,
  subscriptionPlans,
  providerConfigs,
  setFeedback,
}: UseEconomyCatalogMutationsParams) {
  const queryClient = useQueryClient();
  const [drafts, setDrafts] = useState<Record<string, PackDraft>>({});
  const [planDrafts, setPlanDrafts] = useState<Record<string, SubscriptionPlanDraft>>({});
  const [providerConfigDrafts, setProviderConfigDrafts] = useState<
    Record<string, ProviderConfigDraft>
  >({});
  const [cloneRegionDrafts, setCloneRegionDrafts] = useState<Record<string, string>>({});
  const [createProviderDraft, setCreateProviderDraft] = useState<ProviderConfigCreateDraft>(() =>
    createDefaultProviderConfigDraft()
  );
  const [matchDraft, setMatchDraft] = useState<ProviderConfigMatchDraft>({
    provider: "stripe",
    platform: "web",
    country: "US",
    appVersion: "1.0.0",
  });
  const [matchResult, setMatchResult] = useState<AdminPaymentProviderConfigurationMatch | null>(
    null
  );
  const [watermarkDraft, setWatermarkDraft] = useState<AdminWatermarkSettings | null>(null);

  const watermarkQuery = useQuery({
    queryKey: adminQueryKeys.templateWatermarkSettings,
    queryFn: ({ signal }) => fetchAdminWatermarkSettings(signal),
    enabled: canManageEconomy,
  });

  function updateWatermarkDraft(patch: Partial<AdminWatermarkSettings>) {
    setWatermarkDraft((current) => {
      const base = current ?? watermarkQuery.data;
      return base ? { ...base, ...patch } : current;
    });
  }

  const savePackMutation = useMutation({
    mutationFn: async (packId: string) => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      const pack = packs.find((item) => item.packId === packId);
      const draft = drafts[packId] ?? (pack ? toDraft(pack) : null);
      if (!draft) {
        throw new Error(text.packMissingDraft);
      }

      return updateAdminCurrencyPack(packId, toCurrencyPackPayload(draft, text));
    },
    onSuccess: async (pack) => {
      setFeedback({ tone: "success", message: text.packSaved });
      setDrafts((current) => ({ ...current, [pack.packId]: toDraft(pack) }));
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyPacks }),
      ]);
    },
    onError: (error) => {
      setFeedback({ tone: "danger", message: getAdminErrorMessage(error, text.packSaveError) });
    },
  });

  const saveWatermarkMutation = useMutation({
    mutationFn: async () => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      const draft = watermarkDraft ?? watermarkQuery.data;
      if (!draft) {
        throw new Error(text.watermarkSettingsNotLoaded);
      }

      return updateAdminWatermarkSettings(draft);
    },
    onSuccess: async (settings) => {
      setFeedback({
        tone: "success",
        message: text.watermarkSaved,
      });
      setWatermarkDraft(settings);
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateWatermarkSettings }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.watermarkSaveError),
      });
    },
  });

  const savePlanMutation = useMutation({
    mutationFn: async (planId: string) => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      const plan = subscriptionPlans.find((item) => item.planId === planId);
      const draft = planDrafts[planId] ?? (plan ? toSubscriptionPlanDraft(plan) : null);
      if (!draft) {
        throw new Error(text.planMissingDraft);
      }

      return updateAdminSubscriptionPlan(planId, toSubscriptionPlanPayload(draft, text));
    },
    onSuccess: async (plan) => {
      setFeedback({ tone: "success", message: text.planSaved });
      setPlanDrafts((current) => ({ ...current, [plan.planId]: toSubscriptionPlanDraft(plan) }));
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economySubscriptionPlans }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.planSaveError),
      });
    },
  });

  const saveProviderConfigMutation = useMutation({
    mutationFn: async (configurationId: string) => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      const config = providerConfigs.find((item) => item.configurationId === configurationId);
      const draft =
        providerConfigDrafts[configurationId] ?? (config ? toProviderConfigDraft(config) : null);
      if (!draft) {
        throw new Error(text.providerConfigMissingDraft);
      }

      return updateAdminPaymentProviderConfig(
        configurationId,
        toProviderConfigPayload(draft, text)
      );
    },
    onSuccess: async (config) => {
      setFeedback({ tone: "success", message: text.providerConfigSaved });
      setProviderConfigDrafts((current) => ({
        ...current,
        [config.configurationId]: toProviderConfigDraft(config),
      }));
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigSaveError),
      });
    },
  });

  const createProviderConfigMutation = useMutation({
    mutationFn: async () => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      return createAdminPaymentProviderConfig(
        toProviderConfigCreatePayload(createProviderDraft, text)
      );
    },
    onSuccess: async () => {
      setFeedback({ tone: "success", message: text.providerConfigCreated });
      setCreateProviderDraft(createDefaultProviderConfigDraft());
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigCreateError),
      });
    },
  });

  const cloneProviderConfigMutation = useMutation({
    mutationFn: async (payload: { configurationId: string; region: string }) => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      return cloneAdminPaymentProviderConfig(payload.configurationId, { region: payload.region });
    },
    onSuccess: async (_, variables) => {
      setFeedback({ tone: "success", message: text.providerConfigCloned });
      setCloneRegionDrafts((current) => ({ ...current, [variables.configurationId]: "" }));
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigCloneError),
      });
    },
  });

  const deleteProviderConfigMutation = useMutation({
    mutationFn: async (configurationId: string) => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      await deleteAdminPaymentProviderConfig(configurationId);
    },
    onSuccess: async () => {
      setFeedback({ tone: "success", message: text.providerConfigDeleted });
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigDeleteError),
      });
    },
  });

  const testProviderConfigMutation = useMutation({
    mutationFn: async () => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      const payload = toProviderConfigMatchPayload(matchDraft, text);
      return testAdminPaymentProviderConfigMatch(payload);
    },
    onSuccess: (result) => {
      setMatchResult(result);
    },
    onError: (error) => {
      setMatchResult(null);
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigTestError),
      });
    },
  });

  function requestSavePack(packId: string) {
    if (savePackMutation.isPending) {
      return;
    }

    const pack = packs.find((item) => item.packId === packId);
    const draft = drafts[packId] ?? (pack ? toDraft(pack) : null);
    if (!pack || !draft || !isPackDraftDirty(pack, draft)) {
      return;
    }

    savePackMutation.mutate(packId);
  }

  function requestSavePlan(planId: string) {
    if (savePlanMutation.isPending) {
      return;
    }

    const plan = subscriptionPlans.find((item) => item.planId === planId);
    const draft = planDrafts[planId] ?? (plan ? toSubscriptionPlanDraft(plan) : null);
    if (!plan || !draft || !isSubscriptionPlanDraftDirty(plan, draft)) {
      return;
    }

    savePlanMutation.mutate(planId);
  }

  function requestSaveProviderConfig(configurationId: string) {
    if (saveProviderConfigMutation.isPending) {
      return;
    }

    const config = providerConfigs.find((item) => item.configurationId === configurationId);
    const draft =
      providerConfigDrafts[configurationId] ?? (config ? toProviderConfigDraft(config) : null);
    if (!config || !draft || !isProviderConfigDraftDirty(config, draft)) {
      return;
    }

    saveProviderConfigMutation.mutate(configurationId);
  }

  function requestCreateProviderConfig() {
    if (createProviderConfigMutation.isPending) {
      return;
    }

    createProviderConfigMutation.mutate();
  }

  function requestTestProviderConfig() {
    if (testProviderConfigMutation.isPending) {
      return;
    }

    testProviderConfigMutation.mutate();
  }

  function requestCloneProviderConfig(payload: { configurationId: string; region: string }) {
    if (cloneProviderConfigMutation.isPending) {
      return;
    }

    cloneProviderConfigMutation.mutate(payload);
  }

  async function requestDeleteProviderConfig(configurationId: string): Promise<boolean> {
    try {
      await deleteProviderConfigMutation.mutateAsync(configurationId);
      return true;
    } catch {
      return false;
    }
  }

  const effectiveWatermarkDraft = watermarkDraft ?? watermarkQuery.data ?? null;
  const isSaveWatermarkDisabled =
    !canManageEconomy || !effectiveWatermarkDraft || saveWatermarkMutation.isPending;

  function requestSaveWatermark() {
    if (isSaveWatermarkDisabled) {
      return;
    }

    saveWatermarkMutation.mutate();
  }

  return {
    drafts,
    setDrafts,
    planDrafts,
    setPlanDrafts,
    providerConfigDrafts,
    setProviderConfigDrafts,
    cloneRegionDrafts,
    setCloneRegionDrafts,
    createProviderDraft,
    setCreateProviderDraft,
    matchDraft,
    setMatchDraft,
    matchResult,
    watermarkQuery,
    effectiveWatermarkDraft,
    isSaveWatermarkDisabled,
    updateWatermarkDraft,
    requestSaveWatermark,
    saveWatermarkPending: saveWatermarkMutation.isPending,
    requestSavePack,
    savePackPending: savePackMutation.isPending,
    savePackId: savePackMutation.variables,
    requestSavePlan,
    savePlanPending: savePlanMutation.isPending,
    savePlanId: savePlanMutation.variables,
    requestSaveProviderConfig,
    saveProviderConfigPending: saveProviderConfigMutation.isPending,
    saveProviderConfigId: saveProviderConfigMutation.variables,
    requestCreateProviderConfig,
    createProviderConfigPending: createProviderConfigMutation.isPending,
    requestTestProviderConfig,
    testProviderConfigPending: testProviderConfigMutation.isPending,
    requestCloneProviderConfig,
    cloneProviderConfigPending: cloneProviderConfigMutation.isPending,
    cloneProviderConfigId: cloneProviderConfigMutation.variables?.configurationId,
    requestDeleteProviderConfig,
    deleteProviderConfigPending: deleteProviderConfigMutation.isPending,
    deleteProviderConfigId: deleteProviderConfigMutation.variables,
  };
}
