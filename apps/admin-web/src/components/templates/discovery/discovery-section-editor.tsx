"use client";

import { useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";

import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { Button } from "@/components/ui/button";
import {
  discoveryLocales,
  type DiscoveryLocale,
  type DiscoveryPreview,
  type DiscoverySection,
} from "@/lib/api-client.discovery";
import { fetchAdminTemplates } from "@/lib/api-client.templates";
import type { AdminTemplateListItem } from "@/lib/api-client.types.templates";

import { moveDiscoveryItem } from "./discovery-editor-model";
import styles from "./discovery-editor.module.css";

import type { DiscoveryText } from "./discovery-editor.content";

export function DiscoveryCopyFields({
  copy,
  locale,
  onLocale,
  onChange,
  title,
  subtitle,
  text,
}: {
  copy: DiscoverySection["copy"];
  locale: DiscoveryLocale;
  onLocale: (value: DiscoveryLocale) => void;
  onChange: (copy: DiscoverySection["copy"]) => void;
  title: string;
  subtitle: string;
  text: DiscoveryText;
}) {
  const current = copy[locale] ?? { title: "", subtitle: "" };
  return (
    <>
      <label className={styles.field}>
        {text.contentLocale}
        <select
          value={locale}
          onChange={(event) => onLocale(event.target.value as DiscoveryLocale)}
        >
          {discoveryLocales.map((value) => (
            <option key={value} value={value}>
              {value.toUpperCase()}
            </option>
          ))}
        </select>
      </label>
      <label className={styles.field}>
        {title}
        <input
          maxLength={120}
          value={current.title}
          placeholder={copy.en?.title}
          onChange={(event) =>
            onChange({ ...copy, [locale]: { ...current, title: event.target.value } })
          }
        />
      </label>
      <label className={styles.field}>
        {subtitle}
        <textarea
          rows={2}
          maxLength={240}
          value={current.subtitle}
          placeholder={copy.en?.subtitle}
          onChange={(event) =>
            onChange({ ...copy, [locale]: { ...current, subtitle: event.target.value } })
          }
        />
      </label>
      <p className={styles.hint}>{text.translationHint}</p>
    </>
  );
}

export function DiscoverySectionEditor({
  section,
  categoryName,
  onChange,
  onRemove,
  locale,
  onLocale,
  preview,
  text,
  disabled,
}: {
  section: DiscoverySection;
  categoryName: string;
  onChange: (value: DiscoverySection) => void;
  onRemove: () => void;
  locale: DiscoveryLocale;
  onLocale: (value: DiscoveryLocale) => void;
  preview?: DiscoveryPreview;
  text: DiscoveryText;
  disabled: boolean;
}) {
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [skip, setSkip] = useState(0);
  const [selectedNames, setSelectedNames] = useState<Record<string, string>>({});
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search.trim()), 250);
    return () => clearTimeout(timer);
  }, [search]);
  const templates = useQuery({
    queryKey: [
      "discovery-template-picker",
      section.categoryId,
      categoryName,
      debouncedSearch,
      skip,
    ],
    queryFn: ({ signal }) =>
      fetchAdminTemplates(
        {
          category: categoryName,
          status: "Active",
          visibility: "public",
          readiness: "ready",
          search: debouncedSearch,
          skip,
          take: 12,
        },
        signal
      ),
    enabled: Boolean(categoryName),
  });
  const options = templates.data?.items ?? [];
  const savedItems = preview?.sections.find((value) => value.sectionId === section.id)?.items ?? [];
  function label(id: string) {
    return (
      selectedNames[id] ||
      options.find((item) => item.templateId === id)?.title ||
      savedItems.find((item) => item.id === id)?.title ||
      id
    );
  }
  function remember(item: AdminTemplateListItem) {
    setSelectedNames((previous) => ({ ...previous, [item.templateId]: item.title }));
  }
  const pinIds = section.templateIds.filter((id) => id !== section.heroTemplateId);
  return (
    <fieldset className={styles.editorFields} disabled={disabled}>
      <div className={styles.sectionTitle}>
        <div>
          <span className={styles.eyebrow}>{text.category}</span>
          <h2>{categoryName || section.categoryId}</h2>
        </div>
        <Button variant="ghost" onClick={onRemove}>
          {text.remove}
        </Button>
      </div>
      <label className={styles.check}>
        <input
          type="checkbox"
          checked={section.isEnabled}
          onChange={(event) => onChange({ ...section, isEnabled: event.target.checked })}
        />
        {text.enabled}
      </label>
      <div className={styles.twoColumns}>
        <label className={styles.check}>
          <input
            type="checkbox"
            checked={section.showInCarousel}
            onChange={(event) => onChange({ ...section, showInCarousel: event.target.checked })}
          />
          {text.carousel}
        </label>
        <label className={styles.check}>
          <input
            type="checkbox"
            checked={section.showAsRail}
            onChange={(event) => onChange({ ...section, showAsRail: event.target.checked })}
          />
          {text.rail}
        </label>
      </div>
      <DiscoveryCopyFields
        copy={section.copy}
        locale={locale}
        onLocale={onLocale}
        onChange={(copy) => onChange({ ...section, copy })}
        title={text.sectionTitle}
        subtitle={text.sectionSubtitle}
        text={text}
      />
      <div className={styles.twoColumns}>
        <label className={styles.field}>
          {text.mode}
          <select
            value={section.selectionMode}
            onChange={(event) => {
              const selectionMode = event.target.value as DiscoverySection["selectionMode"];
              onChange({
                ...section,
                selectionMode,
                templateIds: selectionMode === "Latest" ? [] : section.templateIds,
              });
            }}
          >
            {(["Latest", "Manual", "Hybrid"] as const).map((value) => (
              <option key={value} value={value}>
                {text[value]}
              </option>
            ))}
          </select>
        </label>
        <label className={styles.field}>
          {text.limit}
          <select
            value={section.itemLimit}
            onChange={(event) => onChange({ ...section, itemLimit: Number(event.target.value) })}
          >
            {Array.from({ length: 12 }, (_, index) => index + 1).map((value) => (
              <option key={value}>{value}</option>
            ))}
          </select>
        </label>
      </div>
      <p className={styles.hint}>
        {section.selectionMode === "Latest"
          ? text.latestHint
          : section.selectionMode === "Hybrid"
            ? text.hybridHint
            : text.manualHint}
      </p>
      <div className={styles.coverSelection}>
        <div>
          <span className={styles.eyebrow}>{text.cover}</span>
          <strong>
            {section.heroTemplateId ? label(section.heroTemplateId) : text.automaticCover}
          </strong>
        </div>
        {section.heroTemplateId ? (
          <Button
            size="sm"
            variant="ghost"
            onClick={() => onChange({ ...section, heroTemplateId: null })}
          >
            {text.unpin}
          </Button>
        ) : null}
      </div>
      {section.selectionMode !== "Latest" ? (
        <div className={styles.pinList}>
          <h3>{text.pinned}</h3>
          {pinIds.map((id, index) => (
            <div key={id} className={styles.pinRow}>
              <span>
                {index + 1}. {label(id)}
              </span>
              <div className={styles.rowActions}>
                <Button
                  size="sm"
                  aria-label={`${text.up}: ${label(id)}`}
                  disabled={index === 0}
                  onClick={() =>
                    onChange({
                      ...section,
                      templateIds: moveDiscoveryItem(pinIds, index, index - 1),
                    })
                  }
                >
                  ↑
                </Button>
                <Button
                  size="sm"
                  aria-label={`${text.down}: ${label(id)}`}
                  disabled={index === pinIds.length - 1}
                  onClick={() =>
                    onChange({
                      ...section,
                      templateIds: moveDiscoveryItem(pinIds, index, index + 1),
                    })
                  }
                >
                  ↓
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  aria-label={`${text.unpin}: ${label(id)}`}
                  onClick={() =>
                    onChange({
                      ...section,
                      templateIds: section.templateIds.filter((value) => value !== id),
                    })
                  }
                >
                  ×
                </Button>
              </div>
            </div>
          ))}
        </div>
      ) : null}
      <label className={styles.field}>
        {text.templateSearch}
        <input
          type="search"
          value={search}
          maxLength={120}
          onChange={(event) => {
            setSearch(event.target.value);
            setSkip(0);
          }}
        />
      </label>
      {templates.isError ? (
        <div role="alert">
          {text.failed}
          <Button onClick={() => void templates.refetch()}>{text.retry}</Button>
        </div>
      ) : null}
      {templates.isFetching ? (
        <p role="status" className={styles.hint}>
          {text.loading}
        </p>
      ) : null}
      {!templates.isFetching && options.length === 0 ? (
        <p className={styles.hint}>{text.noTemplates}</p>
      ) : null}
      <div className={styles.pickerGrid}>
        {options.map((item) => {
          const media =
            item.thumbnailAsset?.url ||
            (item.previewAsset?.contentType.startsWith("image/")
              ? item.previewAsset.url
              : undefined);
          const pinned =
            section.templateIds.includes(item.templateId) ||
            section.heroTemplateId === item.templateId;
          return (
            <article key={item.templateId} className={styles.pickerCard}>
              {media ? (
                <TemplateSecureMedia
                  url={media}
                  kind="image"
                  alt={item.title}
                  className={styles.pickerImage}
                />
              ) : (
                <div className={styles.pickerImage}>✦</div>
              )}
              <strong>{item.title}</strong>
              <small>
                {item.templateType} · {item.tokenCost} PawSpark
              </small>
              <Button
                size="sm"
                variant={section.heroTemplateId === item.templateId ? "primary" : "secondary"}
                disabled={section.heroTemplateId === item.templateId}
                onClick={() => {
                  remember(item);
                  onChange({
                    ...section,
                    heroTemplateId: item.templateId,
                    templateIds: section.templateIds.filter((id) => id !== item.templateId),
                  });
                }}
              >
                {text.chooseCover}
              </Button>
              {section.selectionMode !== "Latest" ? (
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={pinned || section.templateIds.length >= 12}
                  onClick={() => {
                    remember(item);
                    onChange({
                      ...section,
                      templateIds: [...section.templateIds, item.templateId],
                    });
                  }}
                >
                  {text.pin}
                </Button>
              ) : null}
            </article>
          );
        })}
      </div>
      <div className={styles.rowActions}>
        <Button
          size="sm"
          disabled={skip === 0 || templates.isFetching}
          onClick={() => setSkip(Math.max(0, skip - 12))}
        >
          {text.previous}
        </Button>
        <Button
          size="sm"
          disabled={!templates.data?.hasMore || templates.isFetching}
          onClick={() => setSkip(skip + 12)}
        >
          {text.next}
        </Button>
      </div>
    </fieldset>
  );
}
