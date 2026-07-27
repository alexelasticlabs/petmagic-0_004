"use client";

import { useState } from "react";

import { AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { EconomySelectField } from "@/components/economy-page-select-field";
import { type EconomyPageText } from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import {
  WATERMARK_COST_MAX_LENGTH,
  WATERMARK_FORM_ID,
  WATERMARK_LOGO_URL_MAX_LENGTH,
  WATERMARK_OPACITY_MAX_LENGTH,
  WATERMARK_TEXT_MAX_LENGTH,
  WatermarkPreviewPanel,
  normalizeWatermarkPosition,
  normalizeWatermarkSize,
} from "@/components/economy-page.shared";
import { Button } from "@/components/ui/button";
import { type AdminWatermarkSettings } from "@/lib/api-client";

type EconomyPageWatermarkSectionProps = {
  text: EconomyPageText;
  effectiveWatermarkDraft: AdminWatermarkSettings | null;
  isLoading: boolean;
  isSaveDisabled: boolean;
  isSavePending: boolean;
  onSubmit: () => void;
  onUpdateDraft: (patch: Partial<AdminWatermarkSettings>) => void;
};

type EconomyPageWatermarkSettingsCardProps = Omit<
  EconomyPageWatermarkSectionProps,
  "effectiveWatermarkDraft" | "isLoading"
> & {
  effectiveWatermarkDraft: AdminWatermarkSettings;
};

export function EconomyPageWatermarkSection({
  text,
  effectiveWatermarkDraft,
  isLoading,
  isSaveDisabled,
  isSavePending,
  onSubmit,
  onUpdateDraft,
}: EconomyPageWatermarkSectionProps) {
  if (isLoading || !effectiveWatermarkDraft) {
    return (
      <AdminCard
        title={text.watermarkTitle}
        description={text.watermarkDescription}
        action={
          <Button type="button" disabled={isSaveDisabled}>
            {isSavePending ? text.savingAction : text.saveWatermarkAction}
          </Button>
        }
      >
        <AdminStateCard tone="info" title={text.watermarkLoadingTitle} />
      </AdminCard>
    );
  }

  return (
    <EconomyPageWatermarkSettingsCard
      text={text}
      effectiveWatermarkDraft={effectiveWatermarkDraft}
      isSaveDisabled={isSaveDisabled}
      isSavePending={isSavePending}
      onSubmit={onSubmit}
      onUpdateDraft={onUpdateDraft}
    />
  );
}

function EconomyPageWatermarkSettingsCard({
  text,
  effectiveWatermarkDraft,
  isSaveDisabled,
  isSavePending,
  onSubmit,
  onUpdateDraft,
}: EconomyPageWatermarkSettingsCardProps) {
  const [costCreditsInput, setCostCreditsInput] = useState(() =>
    String(effectiveWatermarkDraft.costCredits)
  );
  const [opacityInput, setOpacityInput] = useState(() => String(effectiveWatermarkDraft.opacity));

  const parsedCostCredits = Number(costCreditsInput);
  const parsedOpacity = Number(opacityInput);
  const hasInvalidNumbers =
    !/^\d+$/.test(costCreditsInput) ||
    !Number.isInteger(parsedCostCredits) ||
    parsedCostCredits < 1 ||
    !/^\d+(?:\.\d+)?$/.test(opacityInput) ||
    !Number.isFinite(parsedOpacity) ||
    parsedOpacity < 0.45 ||
    parsedOpacity > 0.65;
  const isFormSaveDisabled = isSaveDisabled || hasInvalidNumbers;
  const positionOptions = [
    { value: "bottom-right", label: text.watermarkPositionBottomRight },
    { value: "bottom-left", label: text.watermarkPositionBottomLeft },
    { value: "top-right", label: text.watermarkPositionTopRight },
    { value: "top-left", label: text.watermarkPositionTopLeft },
  ];
  const sizeOptions = [
    { value: "small", label: text.watermarkSizeSmall },
    { value: "medium", label: text.watermarkSizeMedium },
    { value: "large", label: text.watermarkSizeLarge },
  ];

  return (
    <AdminCard
      title={text.watermarkTitle}
      description={text.watermarkDescription}
      action={
        <Button type="submit" form={WATERMARK_FORM_ID} disabled={isFormSaveDisabled}>
          {isSavePending ? text.savingAction : text.saveWatermarkAction}
        </Button>
      }
    >
      <form
        id={WATERMARK_FORM_ID}
        className={styles.rewardFields}
        onSubmit={(event) => {
          event.preventDefault();
          if (!isFormSaveDisabled) {
            onSubmit();
          }
        }}
      >
        <div className={styles.formRow}>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={effectiveWatermarkDraft.enabled}
              disabled={isSavePending}
              onChange={(event) => onUpdateDraft({ enabled: event.target.checked })}
            />
            <span>{text.watermarkEnabledState}</span>
          </label>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={effectiveWatermarkDraft.applyToImages}
              disabled={isSavePending}
              onChange={(event) => onUpdateDraft({ applyToImages: event.target.checked })}
            />
            <span>{text.watermarkImagesLabel}</span>
          </label>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={effectiveWatermarkDraft.applyToVideos}
              disabled={isSavePending}
              onChange={(event) => onUpdateDraft({ applyToVideos: event.target.checked })}
            />
            <span>{text.watermarkVideosLabel}</span>
          </label>
        </div>
        <div className={styles.formRow}>
          <label className={styles.field}>
            <span>{text.watermarkTextLabel}</span>
            <input
              className={styles.input}
              value={effectiveWatermarkDraft.text}
              disabled={isSavePending}
              maxLength={WATERMARK_TEXT_MAX_LENGTH}
              onChange={(event) =>
                onUpdateDraft({
                  text: event.target.value.slice(0, WATERMARK_TEXT_MAX_LENGTH),
                })
              }
            />
          </label>
          <label className={styles.field}>
            <span>{text.watermarkCostCreditsLabel}</span>
            <input
              className={styles.input}
              type="text"
              inputMode="numeric"
              pattern="[0-9]*"
              maxLength={WATERMARK_COST_MAX_LENGTH}
              disabled={isSavePending}
              aria-invalid={hasInvalidNumbers}
              value={costCreditsInput}
              onChange={(event) => {
                const value = event.target.value
                  .replace(/\D+/g, "")
                  .slice(0, WATERMARK_COST_MAX_LENGTH);
                setCostCreditsInput(value);

                const nextCostCredits = Number(value);
                if (Number.isInteger(nextCostCredits) && nextCostCredits >= 1) {
                  onUpdateDraft({ costCredits: nextCostCredits });
                }
              }}
            />
          </label>
        </div>
        <div className={styles.formRow}>
          <label className={styles.field}>
            <span>{text.watermarkOpacityLabel}</span>
            <input
              className={styles.input}
              type="text"
              inputMode="decimal"
              maxLength={WATERMARK_OPACITY_MAX_LENGTH}
              disabled={isSavePending}
              aria-invalid={hasInvalidNumbers}
              value={opacityInput}
              onChange={(event) => {
                const value = event.target.value
                  .replace(/[^\d.]+/g, "")
                  .replace(/(\..*)\./g, "$1")
                  .slice(0, WATERMARK_OPACITY_MAX_LENGTH);
                setOpacityInput(value);

                const nextOpacity = Number(value);
                if (Number.isFinite(nextOpacity) && nextOpacity >= 0.45 && nextOpacity <= 0.65) {
                  onUpdateDraft({ opacity: nextOpacity });
                }
              }}
            />
          </label>
          <label className={styles.field}>
            <span>{text.watermarkLogoUrlLabel}</span>
            <input
              className={styles.input}
              value={effectiveWatermarkDraft.logoUrl ?? ""}
              disabled={isSavePending}
              maxLength={WATERMARK_LOGO_URL_MAX_LENGTH}
              onChange={(event) =>
                onUpdateDraft({
                  logoUrl: event.target.value.slice(0, WATERMARK_LOGO_URL_MAX_LENGTH),
                })
              }
            />
          </label>
        </div>
        <div className={styles.formRow}>
          <EconomySelectField
            label={text.watermarkPositionLabel}
            value={normalizeWatermarkPosition(effectiveWatermarkDraft.position)}
            options={positionOptions}
            onChange={(position) => onUpdateDraft({ position })}
            disabled={isSavePending}
          />
          <EconomySelectField
            label={text.watermarkSizeLabel}
            value={normalizeWatermarkSize(effectiveWatermarkDraft.size)}
            options={sizeOptions}
            onChange={(size) => onUpdateDraft({ size })}
            disabled={isSavePending}
          />
        </div>
        {hasInvalidNumbers ? (
          <p className={styles.validationMessage} role="alert">
            {text.invalidWatermarkNumbers}
          </p>
        ) : null}
        <WatermarkPreviewPanel text={text} settings={effectiveWatermarkDraft} />
      </form>
    </AdminCard>
  );
}
