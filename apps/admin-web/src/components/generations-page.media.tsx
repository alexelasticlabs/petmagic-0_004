"use client";

import { useEffect, useState } from "react";

import { isUnsafeAdminMediaHost } from "@/lib/admin-unsafe-remote-host";

import styles from "./generations-page.module.css";

import type { GenerationsPageText } from "./generations-page.content";

export function generationMediaKind(url: string, fallback: "image" | "video" = "image") {
  try {
    const path = new URL(url).pathname;
    if (/\.(mp4|webm|mov|m4v)$/i.test(path)) return "video";
    if (/\.(png|jpe?g|webp|avif|gif)$/i.test(path)) return "image";
  } catch {
    return fallback;
  }
  return fallback;
}

export function safeGenerationMediaUrl(value?: string | null): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === "https:" &&
      !url.username &&
      !url.password &&
      !isUnsafeAdminMediaHost(url.hostname)
      ? url.href
      : null;
  } catch {
    return null;
  }
}

// Use the signed URL directly: videos can stream/seek with Range requests and
// images do not require JavaScript CORS permission or a full-file blob download.
export function GenerationMedia({
  url,
  kind,
  title,
  emptyText,
  text,
}: {
  url?: string | null;
  kind: "image" | "video";
  title: string;
  emptyText: string;
  text: GenerationsPageText;
}) {
  const source = safeGenerationMediaUrl(url);
  const [state, setState] = useState<"loading" | "ready" | "error">("loading");
  useEffect(() => {
    if (!source || state !== "loading") return;
    const timer = window.setTimeout(() => setState("error"), 30_000);
    return () => window.clearTimeout(timer);
  }, [source, state]);

  return (
    <section className={styles.previewCard} aria-label={title}>
      <header>
        <strong>{title}</strong>
        {source ? (
          <a
            className={styles.inlineAction}
            href={source}
            target="_blank"
            rel="noopener noreferrer"
          >
            {text.openMedia}
          </a>
        ) : null}
      </header>
      <div className={styles.previewFrame} aria-busy={Boolean(source && state === "loading")}>
        {source && state !== "error" ? (
          kind === "video" ? (
            <video
              className={styles.previewImage}
              src={source}
              controls
              playsInline
              preload="metadata"
              aria-label={title}
              onLoadedMetadata={() => setState("ready")}
              onError={() => setState("error")}
            />
          ) : (
            // eslint-disable-next-line @next/next/no-img-element -- Private signed media must retain its URL and expiry.
            <img
              className={styles.previewImage}
              src={source}
              alt={title}
              referrerPolicy="no-referrer"
              onLoad={() => setState("ready")}
              onError={() => setState("error")}
            />
          )
        ) : null}
        {!source || state !== "ready" ? (
          <div className={styles.mediaState} role="status">
            {source ? (state === "error" ? text.mediaError : text.mediaLoading) : emptyText}
            {source && state === "error" ? <small>{text.mediaRetryHint}</small> : null}
          </div>
        ) : null}
      </div>
    </section>
  );
}
