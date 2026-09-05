"use client";

import { useState } from "react";

import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { Button } from "@/components/ui/button";
import type { DiscoveryFeedItem, DiscoveryPreview } from "@/lib/api-client.discovery";

import styles from "./discovery-editor.module.css";

import type { DiscoveryText } from "./discovery-editor.content";

export function DiscoveryMedia({
  item,
  className,
}: {
  item: DiscoveryFeedItem;
  className?: string;
}) {
  const url = item.thumbnailUrl || item.media.thumbnailUrl || item.media.animatedPreviewUrl;
  return url ? (
    <TemplateSecureMedia url={url} kind="image" alt={item.title} className={className} />
  ) : (
    <div className={styles.mediaFallback}>✦</div>
  );
}

export function DiscoveryPhonePreview({
  data,
  text,
}: {
  data: DiscoveryPreview;
  text: DiscoveryText;
}) {
  const [position, setPosition] = useState(0);
  const carousel = data.sections.filter((section) => section.showInCarousel);
  const current = carousel[Math.min(position, Math.max(0, carousel.length - 1))];
  return (
    <div className={styles.phone} data-testid="discovery-phone-preview">
      <div className={styles.phoneBrand}>
        <span>✦</span> PetMagic
      </div>
      <h3>{data.page?.title}</h3>
      <p className={styles.phoneSubtitle}>{data.page?.subtitle}</p>
      {data.page?.searchEnabled ? (
        <div className={styles.phoneSearch}>⌕ {text.searchPlaceholder}</div>
      ) : null}
      {data.page?.carouselEnabled && current ? (
        <div className={styles.heroPreview}>
          <DiscoveryMedia item={current.items[0]} className={styles.heroImage} />
          <div className={styles.heroCaption}>
            <small>{current.category}</small>
            <strong>{current.title}</strong>
            <span>{current.subtitle}</span>
          </div>
          <div className={styles.heroNavigation}>
            <button
              type="button"
              aria-label={text.previous}
              onClick={() =>
                setPosition(
                  (Math.min(position, carousel.length - 1) - 1 + carousel.length) % carousel.length
                )
              }
            >
              ‹
            </button>
            <span>
              {Math.min(position, carousel.length - 1) + 1} / {carousel.length}
            </span>
            <button
              type="button"
              aria-label={text.next}
              onClick={() => setPosition((position + 1) % carousel.length)}
            >
              ›
            </button>
          </div>
        </div>
      ) : null}
      {data.sections
        .filter((section) => section.showAsRail)
        .map((section) => (
          <section key={section.sectionId} className={styles.phoneSection}>
            <div className={styles.railHeading}>
              <strong>{section.title}</strong>
              <span>{text.more} ›</span>
            </div>
            <div className={styles.previewRail}>
              {section.items.map((item) => (
                <div key={item.id} className={styles.previewCard}>
                  <DiscoveryMedia item={item} className={styles.previewImage} />
                  <strong>{item.title}</strong>
                  <small>{item.tokenCost} PawSpark</small>
                </div>
              ))}
            </div>
          </section>
        ))}
      {data.sections.length === 0 ? (
        <p className={styles.phoneSubtitle}>{text.previewEmpty}</p>
      ) : null}
    </div>
  );
}

export function PreviewError({ retry, text }: { retry: () => void; text: DiscoveryText }) {
  return (
    <div role="alert">
      <p>{text.failed}</p>
      <Button onClick={retry}>{text.retry}</Button>
    </div>
  );
}
