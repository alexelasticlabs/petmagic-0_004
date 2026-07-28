import type {
  AdminGenerationControlSettings,
  UpdateAdminGenerationControlCommand,
} from "./api-client.types.generation-control";

export type GenerationCapacityMutableSettings = Omit<
  AdminGenerationControlSettings,
  "version" | "updatedAtUtc" | "updatedByAdminId"
>;

export type GenerationCapacitySettingsDraft = {
  baseVersion: number;
  baseValues: GenerationCapacityMutableSettings;
  values: GenerationCapacityMutableSettings;
};

export function generationCapacityMutableSettings(
  settings: AdminGenerationControlSettings
): GenerationCapacityMutableSettings {
  return {
    globalMaxConcurrent: settings.globalMaxConcurrent,
    imageMaxConcurrent: settings.imageMaxConcurrent,
    imageProtectedConcurrent: settings.imageProtectedConcurrent,
    videoGuaranteedConcurrent: settings.videoGuaranteedConcurrent,
    videoMaxConcurrent: settings.videoMaxConcurrent,
    videoBorrowMaxConcurrent: settings.videoBorrowMaxConcurrent,
    workerLoopsPerInstance: settings.workerLoopsPerInstance,
    falConfiguredConcurrency: settings.falConfiguredConcurrency,
    falReservedConcurrency: settings.falReservedConcurrency,
    falBalanceLowThresholdUsd: settings.falBalanceLowThresholdUsd,
    falBalanceCriticalThresholdUsd: settings.falBalanceCriticalThresholdUsd,
  };
}

export function updateGenerationCapacitySettingsDraft(
  current: GenerationCapacitySettingsDraft | null,
  serverSettings: AdminGenerationControlSettings,
  key: keyof GenerationCapacityMutableSettings,
  value: number
): GenerationCapacitySettingsDraft {
  const draft =
    current ??
    (() => {
      const baseValues = generationCapacityMutableSettings(serverSettings);
      return {
        baseVersion: serverSettings.version,
        baseValues,
        values: baseValues,
      };
    })();

  return {
    ...draft,
    values: {
      ...draft.values,
      [key]: value,
    },
  };
}

export function createGenerationCapacitySettingsCommand(
  draft: GenerationCapacitySettingsDraft,
  reason: string
): UpdateAdminGenerationControlCommand {
  return {
    ...draft.values,
    expectedVersion: draft.baseVersion,
    reason,
  };
}
