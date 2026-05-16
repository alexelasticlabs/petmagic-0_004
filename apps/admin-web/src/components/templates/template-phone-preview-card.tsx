import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import styles from "@/components/templates/template-phone-preview-card.module.css";
import { formatDuration, formatPromoBadge } from "@/components/templates/template-video-editor-model";
import { type TemplatePromoBadgeMode } from "@/lib/api-client";
import Image from "next/image";

type TemplatePhonePreviewCardProps = {
  title: string;
  shortDescription: string;
  tags?: string[] | string;
  previewUrl?: string | null;
  previewContentType?: string | null;
  tokenCost: number | string;
  category: string;
  isPremium: boolean;
  referenceDurationSeconds?: number;
  promoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  musicDescription?: string;
  className?: string;
};

export function TemplatePhonePreviewCard({
  title,
  shortDescription,
  tags,
  previewUrl,
  previewContentType,
  tokenCost,
  category,
  isPremium,
  referenceDurationSeconds,
  promoBadge,
  musicDescription,
  className,
}: TemplatePhonePreviewCardProps) {
  const normalizedTitle = title.trim();
  const normalizedDescription = shortDescription.trim();
  const normalizedTags = normalizePreviewTags(tags);
  const normalizedCategory = category.trim();
  const normalizedMusicDescription = musicDescription?.trim();

  return (
    <div className={joinClassNames(styles.phonePreview, className)}>
      <div className={styles.phoneMedia}>
        {renderPhonePreviewMedia(previewUrl, previewContentType, normalizedTitle || "Template preview")}
        {promoBadge ? (
          <div className={styles.phoneTopRow}>
            <span className={joinClassNames(styles.phoneHeroBadge, getPromoBadgeClassName(promoBadge))}>
              {formatPromoBadge(promoBadge)}
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
          {normalizedTags.length ? (
            <div className={styles.phoneTagRow}>
              {normalizedTags.map((tag) => <span key={tag} className={styles.phoneTag}>#{tag}</span>)}
            </div>
          ) : null}

          <div className={styles.phoneMetaRow}>
            <span>{formatDuration(referenceDurationSeconds)}</span>
            <span className={styles.phoneMetaDot} aria-hidden="true" />
            <span>{normalizedCategory}</span>
            <span className={styles.phoneMetaSpacer} />
            <span className={joinClassNames(styles.phoneAccessTag, isPremium ? styles.phoneAccessTagPremium : styles.phoneAccessTagFree)}>
              <span className={joinClassNames(styles.phoneAccessIcon, isPremium ? styles.phoneAccessIconPremium : styles.phoneAccessIconFree)} aria-hidden="true">
                <svg viewBox="0 0 16 16" focusable="false">
                  <path d="M8 1.75 13 4.6v5.8L8 13.25 3 10.4V4.6l5-2.85Zm0 1.72L4.5 5.45v4.1L8 11.53l3.5-1.98v-4.1L8 3.47Z" fill="currentColor" />
                </svg>
              </span>
              <span>{isPremium ? "Premium" : "Free"}</span>
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

function normalizePreviewTags(tags: string[] | string | undefined): string[] {
  const rawTags = Array.isArray(tags) ? tags : typeof tags === "string" ? tags.split(",") : [];

  return Array.from(
    new Set(
      rawTags
        .map((tag) => tag.trim().replace(/^#+/, ""))
        .filter(Boolean),
    ),
  ).slice(0, 3);
}
