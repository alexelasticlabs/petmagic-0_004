import { formatDuration, formatPromoBadge } from "@/components/templates/template-editor-model";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import styles from "@/components/templates/template-phone-preview-card.module.css";
import { type TemplatePromoBadgeMode } from "@/lib/api-client";
import Image from "next/image";

type TemplatePreviewCardProps = {
  title: string;
  shortDescription: string;
  tags?: string[];
  previewUrl?: string | null;
  previewContentType?: string | null;
  templateKind?: "video" | "image";
  templateKindLabel: string;
  tokenCost: number | string;
  category: string;
  isPremium: boolean;
  accessLabel: string;
  referenceDurationSeconds?: number;
  promoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  musicDescription?: string;
  className?: string;
};

export function TemplatePreviewCard({
  title,
  shortDescription,
  tags,
  previewUrl,
  previewContentType,
  templateKind,
  templateKindLabel,
  tokenCost,
  category,
  isPremium,
  accessLabel,
  referenceDurationSeconds,
  promoBadge,
  musicDescription,
  className,
}: TemplatePreviewCardProps) {
  const normalizedTitle = title.trim();
  const normalizedDescription = shortDescription.trim();
  const normalizedCategory = category.trim();
  const normalizedMusicDescription = musicDescription?.trim();
  const normalizedTags = (tags ?? []).map((tag) => tag.trim()).filter(Boolean).slice(0, 4);
  const resolvedTemplateKind = templateKind ?? inferTemplateMediaKind(previewContentType?.trim() ?? "", previewUrl?.trim() ?? "");
  const originalTemplateKindLabel = templateKindLabel.trim();
  const resolvedTemplateKindLabel = (resolvedTemplateKind === "video" ? "Video" : "Image");
  const resolvedAccessLabel = accessLabel.trim();

  return (
    <div className={joinClassNames(styles.phonePreview, resolvedTemplateKind === "video" ? styles.phonePreviewVideo : styles.phonePreviewImage, className)}>
      <div className={styles.phoneMedia}>
        {renderPhonePreviewMedia(previewUrl, previewContentType, normalizedTitle || "Template preview")}
        {promoBadge || resolvedTemplateKindLabel ? (
          <div className={styles.phoneTopRow}>
            {promoBadge ? (
              <span className={joinClassNames(styles.phoneHeroBadge, getPromoBadgeClassName(promoBadge))}>
                {formatPromoBadge(promoBadge)}
              </span>
            ) : (
              <span className={styles.phoneTopSpacer} aria-hidden="true" />
            )}
            <span className={joinClassNames(styles.phoneMediaKindBadge, resolvedTemplateKind === "video" ? styles.phoneMediaKindBadgeVideo : styles.phoneMediaKindBadgeImage)}>
              <span className={styles.phoneMediaKindIcon} aria-hidden="true">
                {resolvedTemplateKind === "video" ? (
                  <svg viewBox="0 0 16 16" focusable="false">
                    <path d="M5.5 4.2c0-.58.64-.93 1.13-.62l5.14 3.3a.74.74 0 0 1 0 1.24l-5.14 3.3a.74.74 0 0 1-1.13-.62V4.2Z" fill="currentColor" />
                  </svg>
                ) : (
                  <svg viewBox="0 0 16 16" focusable="false">
                    <path d="M3.25 3.25h9.5a1 1 0 0 1 1 1v7.5a1 1 0 0 1-1 1h-9.5a1 1 0 0 1-1-1v-7.5a1 1 0 0 1 1-1Zm0 1v7.5h9.5v-7.5h-9.5Zm1.35 5.65 1.85-2.25a.7.7 0 0 1 1.08.01l1.22 1.5.98-1.12a.7.7 0 0 1 1.05.01l1.12 1.3v1.4H4.6v-.85Zm1.55-3.75a1.05 1.05 0 1 1 0 2.1 1.05 1.05 0 0 1 0-2.1Z" fill="currentColor" />
                  </svg>
                )}
              </span>
              <span title={originalTemplateKindLabel || undefined}>{resolvedTemplateKindLabel}</span>
            </span>
          </div>
        ) : null}
        <div className={styles.phoneCardShade} />

        <div className={styles.phoneBottomContent}>
          <div className={styles.phoneMetricRow}>
            <span className={styles.phoneMetricBadge}>
              <span className={styles.phoneMetricIcon} aria-hidden="true">
                <svg viewBox="0 0 16 16" focusable="false">
                  <path d="M3.35 7.55c.62 0 1.12-.59 1.12-1.32 0-.72-.5-1.31-1.12-1.31s-1.12.59-1.12 1.31c0 .73.5 1.32 1.12 1.32Zm9.3 0c.62 0 1.12-.59 1.12-1.32 0-.72-.5-1.31-1.12-1.31s-1.12.59-1.12 1.31c0 .73.5 1.32 1.12 1.32ZM5.8 5.45c.67 0 1.22-.67 1.22-1.5s-.55-1.5-1.22-1.5-1.22.67-1.22 1.5.55 1.5 1.22 1.5Zm4.4 0c.67 0 1.22-.67 1.22-1.5s-.55-1.5-1.22-1.5-1.22.67-1.22 1.5.55 1.5 1.22 1.5Zm-2.23 1.3c-1.88 0-3.67 1.22-3.67 2.94 0 1.09.83 1.86 2.02 1.86.56 0 1-.11 1.41-.21.35-.09.68-.17 1.02-.17s.67.08 1.02.17c.41.1.85.21 1.41.21 1.19 0 2.02-.77 2.02-1.86 0-1.72-1.79-2.94-3.67-2.94H7.97Z" fill="currentColor" />
                </svg>
              </span>
              <span>{tokenCost}</span>
            </span>
          </div>

          <h3 className={styles.phoneTitle}>{normalizedTitle}</h3>
          <p className={styles.phoneDescription}>{normalizedDescription}</p>
          {normalizedTags.length ? (
            <div className={styles.phoneTagRow}>
              {normalizedTags.map((tag) => (
                <span key={tag} className={styles.phoneTag}>#{tag}</span>
              ))}
            </div>
          ) : null}
          {normalizedMusicDescription ? (
            <p className={styles.phoneMusicDescription}>
              <span className={styles.phoneMusicLabel} aria-hidden="true">
                <svg viewBox="0 0 16 16" focusable="false">
                  <path d="M10.7 2.15a.55.55 0 0 1 .7.53v7.05a2.2 2.2 0 1 1-1.1-1.92V5.08L6.2 6.1v5.03a2.2 2.2 0 1 1-1.1-1.92V5.67c0-.25.17-.47.41-.53l5.19-1.3Z" fill="currentColor" />
                </svg>
              </span>
              <span className={styles.phoneMusicText}>{normalizedMusicDescription}</span>
            </p>
          ) : null}

          <div className={styles.phoneMetaRow}>
            {resolvedTemplateKind === "video" && (
              <>
                <span>{formatDuration(referenceDurationSeconds)}</span>
                <span className={styles.phoneMetaDot} aria-hidden="true" />
              </>
            )}
            <span>{normalizedCategory}</span>
            <span className={styles.phoneMetaSpacer} />
            <span className={joinClassNames(styles.phoneAccessTag, isPremium ? styles.phoneAccessTagPremium : styles.phoneAccessTagFree)}>
              <span className={joinClassNames(styles.phoneAccessIcon, isPremium ? styles.phoneAccessIconPremium : styles.phoneAccessIconFree)} aria-hidden="true">
                <svg viewBox="0 0 16 16" focusable="false">
                  <path d="M8 1.75 13 4.6v5.8L8 13.25 3 10.4V4.6l5-2.85Zm0 1.72L4.5 5.45v4.1L8 11.53l3.5-1.98v-4.1L8 3.47Z" fill="currentColor" />
                </svg>
              </span>
              <span>{resolvedAccessLabel}</span>
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

function renderPhonePreviewMedia(url: string | null | undefined, contentType: string | null | undefined, alt: string) {
  const trimmedUrl = url?.trim() ?? "";
  if (!trimmedUrl) {
    return <div className={styles.phonePlaceholder} aria-hidden="true" />;
  }

  if (inferTemplateMediaKind(contentType?.trim() ?? "", trimmedUrl) === "video") {
    return <video src={trimmedUrl} className={styles.phoneMediaAsset} muted autoPlay loop playsInline preload="metadata" aria-label={alt} />;
  }

  return <Image src={trimmedUrl} alt={alt} width={320} height={568} sizes="(max-width: 760px) 100vw, 18rem" unoptimized className={styles.phoneMediaAsset} />;
}

function getPromoBadgeClassName(value: Exclude<TemplatePromoBadgeMode, "Auto">): string {
  switch (value) {
    case "Trending":
      return styles.phoneHeroBadgeTrending;
    case "Popular":
      return styles.phoneHeroBadgePopular;
    case "Funny":
      return styles.phoneHeroBadgeFunny;
    default:
      return styles.phoneHeroBadgeNew;
  }
}

function joinClassNames(...classes: Array<string | null | undefined | false>) {
  return classes.filter(Boolean).join(" ");
}

export { TemplatePreviewCard as TemplatePhonePreviewCard };
