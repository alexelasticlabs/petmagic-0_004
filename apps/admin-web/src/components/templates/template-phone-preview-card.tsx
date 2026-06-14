import {
  AccessTierIcon,
  ImageIcon,
  MusicIcon,
  PawIcon,
  PlayCircleIcon,
} from "@/components/admin/admin-icons";
import { formatDuration, formatPromoBadge } from "@/components/templates/template-editor-model";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import styles from "@/components/templates/template-phone-preview-card.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { type TemplatePromoBadgeMode } from "@/lib/api-client";
import { joinClassNames } from "@/lib/join-class-names";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

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
  const normalizedTitle = sanitizeSensitiveText(title, 96);
  const normalizedDescription = sanitizeSensitiveText(shortDescription, 180);
  const normalizedCategory = sanitizeSensitiveText(category, 64);
  const normalizedMusicDescription = musicDescription
    ? sanitizeSensitiveText(musicDescription, 160)
    : "";
  const normalizedTags = (tags ?? [])
    .map((tag) => sanitizeSensitiveText(tag, 40))
    .filter((tag) => tag !== "—")
    .slice(0, 4);
  const resolvedTemplateKind =
    templateKind ??
    inferTemplateMediaKind(previewContentType?.trim() ?? "", previewUrl?.trim() ?? "");
  const originalTemplateKindLabel = templateKindLabel.trim();
  const resolvedTemplateKindLabel = resolvedTemplateKind === "video" ? "Video" : "Image";
  const resolvedAccessLabel = accessLabel.trim();

  return (
    <div
      className={joinClassNames(
        styles.phonePreview,
        resolvedTemplateKind === "video" ? styles.phonePreviewVideo : styles.phonePreviewImage,
        className
      )}
    >
      <div className={styles.phoneMedia}>
        {renderPhonePreviewMedia(
          previewUrl,
          previewContentType,
          normalizedTitle || "Template preview"
        )}
        {promoBadge || resolvedTemplateKindLabel ? (
          <div className={styles.phoneTopRow}>
            {promoBadge ? (
              <span
                className={joinClassNames(
                  styles.phoneHeroBadge,
                  getPromoBadgeClassName(promoBadge)
                )}
              >
                {formatPromoBadge(promoBadge)}
              </span>
            ) : (
              <span className={styles.phoneTopSpacer} aria-hidden="true" />
            )}
            <span
              className={joinClassNames(
                styles.phoneMediaKindBadge,
                resolvedTemplateKind === "video"
                  ? styles.phoneMediaKindBadgeVideo
                  : styles.phoneMediaKindBadgeImage
              )}
            >
              <span className={styles.phoneMediaKindIcon} aria-hidden="true">
                {resolvedTemplateKind === "video" ? (
                  <PlayCircleIcon className={styles.phoneInlineIcon} />
                ) : (
                  <ImageIcon className={styles.phoneInlineIcon} />
                )}
              </span>
              <span title={originalTemplateKindLabel || undefined}>
                {resolvedTemplateKindLabel}
              </span>
            </span>
          </div>
        ) : null}
        <div className={styles.phoneCardShade} />

        <div className={styles.phoneBottomContent}>
          <div className={styles.phoneMetricRow}>
            <span className={styles.phoneMetricBadge}>
              <span className={styles.phoneMetricIcon} aria-hidden="true">
                <PawIcon className={styles.phoneInlineIcon} />
              </span>
              <span>{tokenCost}</span>
            </span>
          </div>

          <h3 className={styles.phoneTitle}>{normalizedTitle}</h3>
          <p className={styles.phoneDescription}>{normalizedDescription}</p>
          {normalizedTags.length ? (
            <div className={styles.phoneTagRow}>
              {normalizedTags.map((tag) => (
                <span key={tag} className={styles.phoneTag}>
                  #{tag}
                </span>
              ))}
            </div>
          ) : null}
          {normalizedMusicDescription ? (
            <p className={styles.phoneMusicDescription}>
              <span className={styles.phoneMusicLabel} aria-hidden="true">
                <MusicIcon className={styles.phoneInlineIcon} />
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
            <span
              className={joinClassNames(
                styles.phoneAccessTag,
                isPremium ? styles.phoneAccessTagPremium : styles.phoneAccessTagFree
              )}
            >
              <span
                className={joinClassNames(
                  styles.phoneAccessIcon,
                  isPremium ? styles.phoneAccessIconPremium : styles.phoneAccessIconFree
                )}
                aria-hidden="true"
              >
                <AccessTierIcon className={styles.phoneInlineIcon} />
              </span>
              <span>{resolvedAccessLabel}</span>
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

function renderPhonePreviewMedia(
  url: string | null | undefined,
  contentType: string | null | undefined,
  alt: string
) {
  const trimmedUrl = url?.trim() ?? "";
  if (!trimmedUrl) {
    return <div className={styles.phonePlaceholder} aria-hidden="true" />;
  }

  if (inferTemplateMediaKind(contentType?.trim() ?? "", trimmedUrl) === "video") {
    return (
      <TemplateSecureMedia
        url={trimmedUrl}
        kind="video"
        className={styles.phoneMediaAsset}
        muted
        autoPlay
        loop
        playsInline
        preload="metadata"
        ariaLabel={alt}
        logContext={{ contentType, surface: "phone_preview" }}
      />
    );
  }

  return (
    <TemplateSecureMedia
      url={trimmedUrl}
      kind="image"
      alt={alt}
      width={320}
      height={568}
      className={styles.phoneMediaAsset}
      logContext={{ contentType, surface: "phone_preview" }}
    />
  );
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

export { TemplatePreviewCard as TemplatePhonePreviewCard };
