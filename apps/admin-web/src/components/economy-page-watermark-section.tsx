"use client";

import { AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
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

export function EconomyPageWatermarkSection({
  text,
  effectiveWatermarkDraft,
  isLoading,
  isSaveDisabled,
  isSavePending,
  onSubmit,
  onUpdateDraft,
}: EconomyPageWatermarkSectionProps) {
  return (
    <AdminCard
      title={text.watermarkTitle}
      description={text.watermarkDescription}
      action={
        <Button type="submit" form={WATERMARK_FORM_ID} disabled={isSaveDisabled}>
          {isSavePending ? text.savingAction : text.saveWatermarkAction}
        </Button>
      }
    >
      {isLoading || !effectiveWatermarkDraft ? (
        <AdminStateCard tone="info" title={text.watermarkLoadingTitle} />
      ) : (
        <form
          id={WATERMARK_FORM_ID}
          className={styles.rewardFields}
          onSubmit={(event) => {
            event.preventDefault();
            onSubmit();
          }}
        >
          <div className={styles.formRow}>
            <label className={styles.checkboxField}>
              <input
                type="checkbox"
                checked={effectiveWatermarkDraft.enabled}
                onChange={(event) => onUpdateDraft({ enabled: event.target.checked })}
              />
              <span>{text.watermarkEnabledState}</span>
            </label>
            <label className={styles.checkboxField}>
              <input
                type="checkbox"
                checked={effectiveWatermarkDraft.applyToImages}
                onChange={(event) => onUpdateDraft({ applyToImages: event.target.checked })}
              />
              <span>{text.watermarkImagesLabel}</span>
            </label>
            <label className={styles.checkboxField}>
              <input
                type="checkbox"
                checked={effectiveWatermarkDraft.applyToVideos}
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
                value={String(effectiveWatermarkDraft.costCredits)}
                onChange={(event) => {
                  const value = event.target.value
                    .replace(/\D+/g, "")
                    .slice(0, WATERMARK_COST_MAX_LENGTH);
                  onUpdateDraft({
                    costCredits: Math.max(1, Number.parseInt(value, 10) || 1),
                  });
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
                value={String(effectiveWatermarkDraft.opacity)}
                onChange={(event) => {
                  const value = event.target.value
                    .replace(/[^\d.]+/g, "")
                    .replace(/(\..*)\./g, "$1")
                    .slice(0, WATERMARK_OPACITY_MAX_LENGTH);
                  onUpdateDraft({
                    opacity: Math.min(0.65, Math.max(0.45, Number.parseFloat(value) || 0.55)),
                  });
                }}
              />
            </label>
            <label className={styles.field}>
              <span>{text.watermarkLogoUrlLabel}</span>
              <input
                className={styles.input}
                value={effectiveWatermarkDraft.logoUrl ?? ""}
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
            <label className={styles.field}>
              <span>{text.watermarkPositionLabel}</span>
              <select
                className={styles.input}
                value={normalizeWatermarkPosition(effectiveWatermarkDraft.position)}
                onChange={(event) => onUpdateDraft({ position: event.target.value })}
              >
                <option value="bottom-right">{text.watermarkPositionBottomRight}</option>
                <option value="bottom-left">{text.watermarkPositionBottomLeft}</option>
                <option value="top-right">{text.watermarkPositionTopRight}</option>
                <option value="top-left">{text.watermarkPositionTopLeft}</option>
              </select>
            </label>
            <label className={styles.field}>
              <span>{text.watermarkSizeLabel}</span>
              <select
                className={styles.input}
                value={normalizeWatermarkSize(effectiveWatermarkDraft.size)}
                onChange={(event) => onUpdateDraft({ size: event.target.value })}
              >
                <option value="small">{text.watermarkSizeSmall}</option>
                <option value="medium">{text.watermarkSizeMedium}</option>
                <option value="large">{text.watermarkSizeLarge}</option>
              </select>
            </label>
          </div>
          <WatermarkPreviewPanel text={text} settings={effectiveWatermarkDraft} />
        </form>
      )}
    </AdminCard>
  );
}
