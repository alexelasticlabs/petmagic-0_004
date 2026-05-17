"use client";

import {
  CalendarIcon,
  ChartIcon,
  ClockIcon,
  DownloadIcon,
  ImageIcon,
  PlayCircleIcon,
  RefreshIcon,
  TableIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import { ensureAdminSession } from "@/components/admin/admin-session";
import styles from "@/components/templates/template-test-page.module.css";
import { Button } from "@/components/ui/button";
import {
  fetchAdminTemplate,
  fetchAdminTemplateTest,
  startAdminTemplateTest,
  type AdminTemplate,
  type AdminTemplateTestRun,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState, type ChangeEvent, type DragEvent, type KeyboardEvent, type ReactNode } from "react";

type TemplateTestPageProps = {
  locale: Locale;
  templateId: string;
};

type TimelineItem = {
  label: string;
  at: string;
  description: string;
  done: boolean;
};

type ArtifactItem = {
  key: string;
  title: string;
  accent: "source" | "preprocess" | "result";
  imageUrl?: string;
  videoUrl?: string;
  placeholderEyebrow: string;
  placeholderTitle: string;
  placeholderText: string;
  openLabel?: string;
  downloadLabel?: string;
  downloadName?: string;
};

export function TemplateTestPage({ locale, templateId }: TemplateTestPageProps) {
  const isRu = locale === "ru";
  const text = getDictionary(locale);
  const router = useRouter();
  const [template, setTemplate] = useState<AdminTemplate | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [selectedFilePreviewUrl, setSelectedFilePreviewUrl] = useState<string | null>(null);
  const selectedFilePreviewObjectUrlRef = useRef<string | null>(null);
  const [run, setRun] = useState<AdminTemplateTestRun | null>(null);
  const [runError, setRunError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSourceDragActive, setIsSourceDragActive] = useState(false);

  useEffect(() => {
    let isCancelled = false;

    async function loadTemplate() {
      setIsLoading(true);
      setLoadError(null);

      try {
        if (!ensureAdminSession(locale, router)) {
          return;
        }

        const response = await fetchAdminTemplate(templateId);
        if (!isCancelled) {
          setTemplate(response);
        }
      } catch {
        if (!isCancelled) {
          setLoadError(isRu ? "Не удалось загрузить шаблон для теста." : "Failed to load the template for testing.");
        }
      } finally {
        if (!isCancelled) {
          setIsLoading(false);
        }
      }
    }

    void loadTemplate();

    return () => {
      isCancelled = true;
    };
  }, [isRu, locale, router, templateId]);

  useEffect(() => {
    if (!run || (run.status !== "Queued" && run.status !== "Processing")) {
      return;
    }

    const timer = window.setTimeout(async () => {
      try {
        const latest = await fetchAdminTemplateTest(run.generationId);
        setRun(latest);
      } catch {
        setRunError(isRu ? "Не удалось обновить статус теста." : "Failed to refresh test status.");
      }
    }, 2500);

    return () => {
      window.clearTimeout(timer);
    };
  }, [isRu, run]);

  useEffect(() => () => {
    if (selectedFilePreviewObjectUrlRef.current) {
      URL.revokeObjectURL(selectedFilePreviewObjectUrlRef.current);
    }
  }, []);

  async function handleStartTest() {
    if (!selectedFile) {
      setRunError(isRu ? "Сначала выберите тестовое фото питомца." : "Choose a test pet photo first.");
      return;
    }

    setIsSubmitting(true);
    setRunError(null);

    try {
      const started = await startAdminTemplateTest(templateId, selectedFile);
      setRun(started);
    } catch (error) {
      setRunError(getStartTestErrorMessage(error, isRu, template?.templateType === "Video"));
    } finally {
      setIsSubmitting(false);
    }
  }

  function handleSourceFileSelected(file: File | null) {
    if (!file) {
      return;
    }

    if (!file.type.startsWith("image/")) {
      setRunError(isRu ? "Можно загрузить только image/* файл." : "Only image/* files are supported.");
      return;
    }

    clearSelectedFilePreviewUrl();
    const objectUrl = URL.createObjectURL(file);
    selectedFilePreviewObjectUrlRef.current = objectUrl;
    setSelectedFile(file);
    setSelectedFilePreviewUrl(objectUrl);
    setRun(null);
    setRunError(null);
  }

  function handleResetTest() {
    clearSelectedFilePreviewUrl();
    setSelectedFile(null);
    setRun(null);
    setRunError(null);
  }

  function clearSelectedFilePreviewUrl() {
    if (selectedFilePreviewObjectUrlRef.current) {
      URL.revokeObjectURL(selectedFilePreviewObjectUrlRef.current);
      selectedFilePreviewObjectUrlRef.current = null;
    }

    setSelectedFilePreviewUrl(null);
  }

  const isVideoTemplate = template?.templateType !== "Image";
  const templateSlug = isVideoTemplate ? "video" : "image";
  const timeline = useMemo(() => buildTimeline(run, locale, isVideoTemplate), [isVideoTemplate, locale, run]);
  const catalogPath = `/${locale}/templates/${templateSlug}`;
  const editorPath = `/${locale}/templates/${templateSlug}/editor?templateId=${templateId}`;
  const sourceImageUrl = selectedFilePreviewUrl ?? run?.sourceImageAsset?.url ?? undefined;
  const selectedFileName = selectedFile?.name ?? run?.sourceImageAsset?.fileName ?? (isRu ? "Фото не выбрано" : "No photo selected");
  const selectedFileMeta = selectedFile
    ? `${formatBytes(selectedFile.size)} • ${selectedFile.type || "image/*"}`
    : run?.sourceImageAsset?.fileSizeBytes
      ? `${formatBytes(run.sourceImageAsset.fileSizeBytes)} • ${run.sourceImageAsset.contentType}`
      : (isRu ? "Выберите image/* файл" : "Choose an image/* file");
  const generationDuration = formatGenerationDuration(run, isRu);
  const petMagicBillingLabel = isRu ? "Стоимость PetMagic" : "PetMagic billing";
  const falProviderCostLabel = isRu ? "Стоимость Fal" : (isVideoTemplate ? "Fal motion cost" : "Fal image cost");
  const falInferenceLabel = isRu ? "Fal inference" : (isVideoTemplate ? "Fal inference time" : "Fal image inference");
  const internalTokenCost = run?.tokenCost ?? template?.tokenCost ?? 0;
  const internalBillingText = formatTokenCost(internalTokenCost, isRu);
  const providerCostText = formatProviderCost(run, locale);
  const providerInferenceText = formatProviderInference(run, isRu, isVideoTemplate);
  const statusText = run?.status ?? (isRu ? "Ожидает запуска" : "Waiting to start");
  const lastUpdateText = run ? formatDateTime(run.updatedAtUtc, locale, true) : "-";
  const finalDownloadName = run && template
    ? buildGeneratedDownloadName(template.title, run.generationId, isVideoTemplate ? ".mp4" : ".png")
    : undefined;
  const runDetails = buildRunDetails({
    run,
    locale,
    isRu,
    isVideoTemplate,
    statusText,
    petMagicBillingLabel,
    internalBillingText,
    falProviderCostLabel,
    providerCostText,
  });
  const hasSourceImage = Boolean(sourceImageUrl);
  const middleArtifact: ArtifactItem | null = isVideoTemplate
    ? {
      key: "normalized",
      title: isRu ? "Препроцессинг" : "Preprocessing",
      accent: "preprocess",
      imageUrl: run?.normalizedImageUrl ?? undefined,
      placeholderEyebrow: isRu ? "Stage 01" : "Stage 01",
      placeholderTitle: isRu ? "Нормализованное фото" : "Normalized photo",
      placeholderText: selectedFile || run?.sourceImageAsset
        ? (isRu ? "Карточка заполнится сразу после завершения препроцессинга." : "This frame will fill in as soon as preprocessing finishes.")
        : (isRu ? "Загрузите фото питомца, чтобы подготовить кадр для генерации движения." : "Upload a pet photo to prepare the frame for motion generation."),
    }
    : null;
  const resultArtifact: ArtifactItem = {
    key: "output",
    title: isVideoTemplate ? (isRu ? "Финальное видео" : "Final video") : (isRu ? "Финальное изображение" : "Final image"),
    accent: "result",
    imageUrl: isVideoTemplate ? undefined : run?.outputUrl ?? undefined,
    videoUrl: isVideoTemplate ? run?.outputUrl ?? undefined : undefined,
    placeholderEyebrow: isVideoTemplate ? (isRu ? "Stage 02" : "Stage 02") : (isRu ? "Result" : "Result"),
    placeholderTitle: isVideoTemplate ? (isRu ? "Готовый ролик" : "Ready video") : (isRu ? "Готовое изображение" : "Ready image"),
    placeholderText: run?.status === "Processing"
      ? (isVideoTemplate
        ? (isRu ? "Видео собирается. После завершения здесь появятся просмотр и скачивание." : "The video is being assembled. Preview and download will appear here after completion.")
        : (isRu ? "Изображение генерируется. После завершения здесь появятся просмотр и скачивание." : "The image is being generated. Preview and download will appear here after completion."))
      : (isVideoTemplate
        ? (isRu ? "После генерации здесь всегда будут доступны просмотр и скачивание финального видео." : "After generation, preview and download for the final video will always appear here.")
        : (isRu ? "После генерации здесь будут доступны просмотр и скачивание итогового изображения." : "After generation, preview and download for the final image will appear here.")),
    openLabel: isRu ? "Открыть" : "Open",
    downloadLabel: isRu ? "Скачать" : "Download",
    downloadName: finalDownloadName,
  };

  if (isLoading) {
    return (
      <section className={styles.page}>
        <p className={styles.infoText}>{isRu ? "Загрузка тестового стенда..." : "Loading test workspace..."}</p>
      </section>
    );
  }

  if (loadError || !template) {
    return (
      <section className={styles.page}>
        <p className={styles.errorText}>{loadError ?? (isRu ? "Шаблон не найден." : "Template was not found.")}</p>
      </section>
    );
  }

  return (
    <section className={styles.page}>
      <div className={styles.pageHeader}>
        <div className={styles.breadcrumbs}>
          <Link href={catalogPath}>{isVideoTemplate ? (isRu ? "Видео шаблоны" : "Video templates") : (isRu ? "Шаблоны изображений" : "Image templates")}</Link>
          <span aria-hidden="true">/</span>
          <Link href={editorPath}>{template.title}</Link>
          <span aria-hidden="true">/</span>
          <span>{isRu ? "Тест шаблона" : "Template test"}</span>
        </div>

        <div className={styles.headerGrid}>
          <div className={styles.headerMeta}>
            <div className={styles.pillRow}>
              <StatusPill tone={template.status === "Active" ? "success" : template.status === "Draft" ? "warning" : "muted"}>
                {formatTemplateStatus(template.status, locale)}
              </StatusPill>
              <StatusPill tone={template.isPremium ? "premium" : "success"}>{template.isPremium ? text.premiumLabel : text.freeLabel}</StatusPill>
              <StatusPill tone="muted">{template.tokenCost} tokens</StatusPill>
              <StatusPill tone="muted">{isVideoTemplate ? formatReferenceDuration(template.referenceVideoDurationSeconds, isRu) : (template.imageModel ?? (isRu ? "Image model" : "Image model"))}</StatusPill>
            </div>
          </div>

          <div className={styles.headerActions}>
            <Link href={catalogPath} className={styles.secondaryLink}><TableIcon className={styles.inlineIcon} /><span>{isRu ? "К каталогу" : "Back to catalog"}</span></Link>
            <Link href={editorPath} className={styles.primaryLink}><ChartIcon className={styles.inlineIcon} /><span>{isRu ? "Открыть редактор" : "Open editor"}</span></Link>
          </div>
        </div>
      </div>

      <div className={styles.workflowGrid}>
        <div className={styles.resultsColumn}>
          <section className={styles.card}>
            <div className={styles.sectionHeaderRow}>
              <StepHeader number="1" title={isRu ? "Результат генерации" : "Generation result"} />
              <div className={styles.resultHeaderActions}>
                <StatusPill tone={run?.status === "Completed" ? "success" : run?.status === "Failed" ? "danger" : run ? "info" : "muted"}>
                  {statusText}
                </StatusPill>
                <Button variant="primary" disabled={isSubmitting} onClick={() => void handleStartTest()}>
                  <PlayCircleIcon className={styles.inlineIcon} />
                  {isSubmitting ? (isRu ? "Запуск..." : "Launching...") : (isRu ? "Сгенерировать тест" : "Generate test")}
                </Button>
              </div>
            </div>

            {runError ? <p className={styles.errorText}>{runError}</p> : null}

            <div className={`${styles.mediaGrid} ${isVideoTemplate ? "" : styles.mediaGridImage}`.trim()}>
              <SourceUploadCard
                isRu={isRu}
                imageUrl={sourceImageUrl}
                fileName={selectedFileName}
                fileMeta={selectedFileMeta}
                isDragActive={isSourceDragActive}
                onDragActiveChange={setIsSourceDragActive}
                onFileSelected={handleSourceFileSelected}
                onReset={hasSourceImage ? handleResetTest : undefined}
              />
              <WorkflowConnector />
              {middleArtifact ? (
                <>
                  <MediaPreviewCard
                    key={middleArtifact.key}
                    title={middleArtifact.title}
                    accent={middleArtifact.accent}
                    imageUrl={middleArtifact.imageUrl}
                    videoUrl={middleArtifact.videoUrl}
                    placeholderEyebrow={middleArtifact.placeholderEyebrow}
                    placeholderTitle={middleArtifact.placeholderTitle}
                    placeholderText={middleArtifact.placeholderText}
                    openLabel={middleArtifact.openLabel}
                    downloadLabel={middleArtifact.downloadLabel}
                    downloadName={middleArtifact.downloadName}
                  />
                  <WorkflowConnector />
                </>
              ) : null}
              <MediaPreviewCard
                key={resultArtifact.key}
                title={resultArtifact.title}
                accent={resultArtifact.accent}
                imageUrl={resultArtifact.imageUrl}
                videoUrl={resultArtifact.videoUrl}
                placeholderEyebrow={resultArtifact.placeholderEyebrow}
                placeholderTitle={resultArtifact.placeholderTitle}
                placeholderText={resultArtifact.placeholderText}
                openLabel={resultArtifact.openLabel}
                downloadLabel={resultArtifact.downloadLabel}
                downloadName={resultArtifact.downloadName}
              />
            </div>

            <div className={styles.resultMetrics}>
              <MetricTile label={petMagicBillingLabel} value={internalBillingText} />
              <MetricTile label={falProviderCostLabel} value={providerCostText} />
              <MetricTile label={falInferenceLabel} value={providerInferenceText} />
              <MetricTile label={isRu ? "Время генерации" : "Generation time"} value={generationDuration} />
              <MetricTile label={isRu ? "Последнее обновление" : "Last update"} value={lastUpdateText} />
            </div>
          </section>

          <section className={styles.card}>
            <StepHeader number="2" title={isRu ? "События генерации" : "Generation events"} />
            <div className={styles.timeline}>
              {timeline.length ? timeline.map((event) => (
                <div key={`${event.label}-${event.at}`} className={styles.timelineItem}>
                  <span className={`${styles.timelineDot} ${event.done ? styles.timelineDotDone : ""}`} aria-hidden="true">✓</span>
                  <div className={styles.timelineText}>
                    <strong>{event.label}</strong>
                    <span>{event.description}</span>
                  </div>
                  <time>{event.at}</time>
                  <StatusPill tone={event.done ? "success" : "info"}>
                    {event.done ? (isRu ? "Готово" : "Done") : (isRu ? "В работе" : "Running")}
                  </StatusPill>
                </div>
              )) : <p className={styles.infoText}>{isRu ? "После запуска здесь появятся этапы тестовой генерации." : "Pipeline milestones appear here after the test starts."}</p>}
            </div>
          </section>

          <section className={styles.card}>
            <StepHeader number="3" title={isRu ? "Сводка запуска" : "Run summary"} />
            <div className={styles.detailGrid}>
              {runDetails.map((item) => (
                <DetailRow key={item.label} label={item.label} value={item.value} multiline={item.multiline} />
              ))}
            </div>
          </section>
        </div>
      </div>
    </section>
  );
}

type ApiLikeError = {
  message?: string;
  detail?: string;
  code?: string;
  status?: number;
  validationErrors?: string[];
};

function getStartTestErrorMessage(error: unknown, isRu: boolean, isVideoTemplate: boolean): string {
  const apiError = error as ApiLikeError | null;
  if (!apiError) {
    return isRu ? "Не удалось запустить тестовую генерацию." : "Failed to start the test generation.";
  }

  if (Array.isArray(apiError.validationErrors) && apiError.validationErrors.length > 0) {
    return apiError.validationErrors.join(" ");
  }

  if (apiError.code === "templates.invalid_status") {
    return isRu
      ? "Тест недоступен: проверьте статус и обязательные поля шаблона в редакторе."
      : "Test is unavailable. Check template status and required fields in the editor.";
  }

  if (apiError.code === "templates.image_model_required" || apiError.code === "templates.invalid_image_model") {
    return isRu
      ? "Для image-теста нужно выбрать корректную image model в редакторе шаблона."
      : "Image test requires a valid image model in the template editor.";
  }

  if (isVideoTemplate && apiError.code === "templates.reference_motion_required") {
    return isRu
      ? "Для видео-теста нужно загрузить reference motion в редакторе шаблона."
      : "Video test requires a reference motion asset in the template editor.";
  }

  if (isVideoTemplate && apiError.code === "templates.invalid_preprocessing_model") {
    return isRu
      ? "Для видео-теста нужно выбрать preprocessing model в редакторе шаблона."
      : "Video test requires a preprocessing model in the template editor.";
  }

  if (isVideoTemplate && apiError.code === "templates.invalid_kling_model") {
    return isRu
      ? "Для видео-теста нужно выбрать Kling model в редакторе шаблона."
      : "Video test requires a Kling model in the template editor.";
  }

  if (isVideoTemplate && apiError.code === "templates.character_orientation_required") {
    return isRu
      ? "Для видео-теста нужно указать длительность референса, чтобы вычислилась ориентация персонажа."
      : "Video test requires reference duration so character orientation can be resolved.";
  }

  if (typeof apiError.message === "string" && apiError.message.trim().length > 0 && !/^API request failed with status \d+$/i.test(apiError.message)) {
    return apiError.message;
  }

  if (typeof apiError.detail === "string" && apiError.detail.trim().length > 0) {
    return apiError.detail;
  }

  return isRu ? "Не удалось запустить тестовую генерацию." : "Failed to start the test generation.";
}

type DetailItem = {
  label: string;
  value: string;
  multiline?: boolean;
};

function buildRunDetails({
  run,
  locale,
  isRu,
  isVideoTemplate,
  statusText,
  petMagicBillingLabel,
  internalBillingText,
  falProviderCostLabel,
  providerCostText,
}: {
  run: AdminTemplateTestRun | null;
  locale: Locale;
  isRu: boolean;
  isVideoTemplate: boolean;
  statusText: string;
  petMagicBillingLabel: string;
  internalBillingText: string;
  falProviderCostLabel: string;
  providerCostText: string;
}): DetailItem[] {
  const common: DetailItem[] = [
    { label: isRu ? "Попытка" : "Attempt", value: run ? String(run.attemptCount) : "-" },
    { label: isRu ? "Статус" : "Status", value: statusText },
    { label: petMagicBillingLabel, value: internalBillingText },
    { label: falProviderCostLabel, value: providerCostText },
    { label: isRu ? "Создан" : "Created", value: run ? formatDateTime(run.createdAtUtc, locale, true) : "-" },
    { label: isRu ? "Запущен" : "Started", value: formatDateTime(run?.startedAtUtc, locale, true) },
  ];

  if (!isVideoTemplate) {
    return [
      ...common,
      { label: isRu ? "Генерация изображения завершена" : "Image generation completed", value: formatDateTime(run?.preprocessingCompletedAtUtc, locale, true) },
      { label: isRu ? "Fal image request" : "Fal image request", value: run?.preprocessingProviderRequestId ?? "-" },
      { label: isRu ? "Fal image inference" : "Fal image inference", value: formatSeconds(run?.preprocessingInferenceTimeSeconds, isRu) },
      { label: isRu ? "Импорт медиа" : "Media import", value: formatDateTime(run?.mediaImportCompletedAtUtc, locale, true) },
      { label: isRu ? "Ошибка" : "Failure", value: run?.failureMessage ?? "-", multiline: true },
    ];
  }

  return [
    ...common,
    { label: isRu ? "Препроцессинг завершён" : "Preprocessing completed", value: formatDateTime(run?.preprocessingCompletedAtUtc, locale, true) },
    { label: isRu ? "Fal preprocess request" : "Fal preprocess request", value: run?.preprocessingProviderRequestId ?? "-" },
    { label: isRu ? "Fal preprocess inference" : "Fal preprocess inference", value: formatSeconds(run?.preprocessingInferenceTimeSeconds, isRu) },
    { label: isRu ? "Motion завершён" : "Motion completed", value: formatDateTime(run?.motionGenerationCompletedAtUtc, locale, true) },
    { label: isRu ? "Fal motion request" : "Fal motion request", value: run?.motionProviderRequestId ?? "-" },
    { label: isRu ? "Fal motion inference" : "Fal motion inference", value: formatSeconds(run?.motionInferenceTimeSeconds, isRu) },
    { label: isRu ? "Длительность финального видео" : "Final video duration", value: formatSeconds(run?.outputVideoDurationSeconds, isRu) },
    { label: isRu ? "Импорт медиа" : "Media import", value: formatDateTime(run?.mediaImportCompletedAtUtc, locale, true) },
    { label: isRu ? "Ошибка" : "Failure", value: run?.failureMessage ?? "-", multiline: true },
  ];
}

function WorkflowConnector() {
  return (
    <div className={styles.mediaConnector} aria-hidden="true">
      <span className={styles.mediaConnectorLine} />
      <span className={styles.mediaConnectorArrow}>→</span>
    </div>
  );
}

function StepHeader({ number, title, badge }: { number: string; title: string; badge?: string }) {
  const icon = number === "1"
    ? <PlayCircleIcon className={styles.stepIcon} />
    : number === "2"
      ? <RefreshIcon className={styles.stepIcon} />
      : <TableIcon className={styles.stepIcon} />;

  return (
    <div className={styles.stepHeader}>
      <h2>
        <span>{number}.</span>{" "}
        {icon}
        {title}
      </h2>
      {badge ? <StatusPill tone="success">{badge}</StatusPill> : null}
    </div>
  );
}

function StatusPill({ children, tone }: { children: ReactNode; tone: "success" | "warning" | "danger" | "info" | "premium" | "muted" }) {
  return <span className={`${styles.statusPill} ${styles[`statusPill_${tone}`]}`}>{children}</span>;
}

function MetricTile({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.metricTile}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function DetailRow({ label, value, multiline = false }: { label: string; value: string; multiline?: boolean }) {
  const icon = /attempt|попыт/i.test(label)
    ? <RefreshIcon className={styles.detailIcon} />
    : /status|статус/i.test(label)
      ? <ChartIcon className={styles.detailIcon} />
      : /created|создан|started|запущен|completed|заверш|update|обнов/i.test(label)
        ? <CalendarIcon className={styles.detailIcon} />
        : /duration|время|inference|sec|длительность/i.test(label)
          ? <ClockIcon className={styles.detailIcon} />
          : /media|video|motion|preprocess|fal/i.test(label)
            ? <VideoIcon className={styles.detailIcon} />
            : <ImageIcon className={styles.detailIcon} />;

  return (
    <div className={multiline ? styles.detailRowMultiline : styles.detailRow}>
      <span className={styles.detailLabel}><span className={styles.detailLabelIcon}>{icon}</span><span>{label}</span></span>
      <strong>{value}</strong>
    </div>
  );
}

function MediaPreviewCard({
  title,
  accent,
  imageUrl,
  videoUrl,
  placeholderEyebrow,
  placeholderTitle,
  placeholderText,
  openLabel,
  downloadLabel,
  downloadName,
}: {
  title: string;
  accent: "source" | "preprocess" | "result";
  imageUrl?: string;
  videoUrl?: string;
  placeholderEyebrow: string;
  placeholderTitle: string;
  placeholderText: string;
  openLabel?: string;
  downloadLabel?: string;
  downloadName?: string;
}) {
  const previewUrl = videoUrl ?? imageUrl;

  return (
    <section className={`${styles.mediaPreviewCard} ${styles[`mediaPreviewCard_${accent}`]}`}>
      <div className={styles.mediaCardHeader}>
        <strong className={styles.mediaCardTitle}>{videoUrl ? <VideoIcon className={styles.inlineIcon} /> : <ImageIcon className={styles.inlineIcon} />}<span>{title}</span></strong>
        <span>{placeholderEyebrow}</span>
      </div>

      {videoUrl ? (
        <video src={videoUrl} controls className={styles.mediaAsset} />
      ) : imageUrl ? (
        <div role="img" aria-label={title} className={`${styles.mediaAsset} ${styles.mediaAssetImage}`} style={{ backgroundImage: toCssImageUrl(imageUrl) }} />
      ) : (
        <div className={`${styles.mediaAsset} ${styles.mediaPlaceholder}`}>
          <div className={styles.mediaPlaceholderGlow} aria-hidden="true" />
          <div className={styles.mediaPlaceholderBody}>
            <span>{placeholderEyebrow}</span>
            <strong>{placeholderTitle}</strong>
            <p>{placeholderText}</p>
          </div>
        </div>
      )}

      <div className={styles.mediaFooter}>
        {previewUrl ? (
          <div className={styles.mediaActions}>
            <a href={previewUrl} target="_blank" rel="noreferrer" className={styles.mediaActionLink}>
              {videoUrl ? <PlayCircleIcon className={styles.inlineIcon} /> : <ImageIcon className={styles.inlineIcon} />}
              <span>{openLabel ?? "Open"}</span>
            </a>
            <a href={previewUrl} download={downloadName} className={`${styles.mediaActionLink} ${styles.mediaActionLinkPrimary}`}>
              <DownloadIcon className={styles.inlineIcon} />
              <span>{downloadLabel ?? "Download"}</span>
            </a>
          </div>
        ) : null}
      </div>
    </section>
  );
}

function SourceUploadCard({
  isRu,
  imageUrl,
  fileName,
  fileMeta,
  isDragActive,
  onDragActiveChange,
  onFileSelected,
  onReset,
}: {
  isRu: boolean;
  imageUrl?: string;
  fileName: string;
  fileMeta: string;
  isDragActive: boolean;
  onDragActiveChange: (value: boolean) => void;
  onFileSelected: (file: File | null) => void;
  onReset?: () => void;
}) {
  const inputRef = useRef<HTMLInputElement | null>(null);

  function handleInputChange(event: ChangeEvent<HTMLInputElement>) {
    onFileSelected(event.target.files?.[0] ?? null);
    event.target.value = "";
  }

  function handleDragOver(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    onDragActiveChange(true);
  }

  function handleDragLeave(event: DragEvent<HTMLLabelElement>) {
    const relatedTarget = event.relatedTarget;
    if (!(relatedTarget instanceof Node) || !event.currentTarget.contains(relatedTarget)) {
      onDragActiveChange(false);
    }
  }

  function handleDrop(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    onDragActiveChange(false);
    onFileSelected(event.dataTransfer.files?.[0] ?? null);
  }

  function handleKeyDown(event: KeyboardEvent<HTMLLabelElement>) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      inputRef.current?.click();
    }
  }

  return (
    <section className={`${styles.mediaPreviewCard} ${styles.mediaPreviewCard_source}`}>
      <div className={styles.mediaCardHeader}>
        <strong className={styles.mediaCardTitle}><ImageIcon className={styles.inlineIcon} /><span>{isRu ? "Исходник" : "Source"}</span></strong>
        <span>{isRu ? "Input" : "Input"}</span>
      </div>

      <label
        className={`${styles.uploadDropzone} ${isDragActive ? styles.uploadDropzoneActive : ""}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onKeyDown={handleKeyDown}
        tabIndex={0}
      >
        <input ref={inputRef} className={styles.uploadDropzoneInput} type="file" accept="image/*" onChange={handleInputChange} />
        {imageUrl ? (
          <div role="img" aria-label={fileName} className={`${styles.mediaAsset} ${styles.mediaAssetImage}`} style={{ backgroundImage: toCssImageUrl(imageUrl) }} />
        ) : (
          <div className={`${styles.mediaAsset} ${styles.mediaPlaceholder}`}>
            <div className={styles.mediaPlaceholderGlow} aria-hidden="true" />
            <div className={styles.mediaPlaceholderBody}>
              <span>{isRu ? "Dropzone" : "Dropzone"}</span>
              <strong>{isRu ? "Добавьте фото питомца" : "Add pet photo"}</strong>
              <p>{isRu ? "Нажмите на карточку или перетащите сюда изображение." : "Click the card or drag an image here."}</p>
            </div>
          </div>
        )}

        {imageUrl ? <span className={styles.uploadDropzoneBadge}>{isRu ? "Нажмите или перетащите для замены" : "Click or drag to replace"}</span> : null}
      </label>

      <div className={styles.sourceUploadFooter}>
        <div className={styles.sourceUploadMeta}>
          <strong>{imageUrl ? fileName : (isRu ? "Фото не выбрано" : "No photo selected")}</strong>
          <span>{imageUrl ? fileMeta : (isRu ? "Поддерживается image/* и drag-and-drop." : "Supports image/* and drag-and-drop.")}</span>
        </div>
        {onReset ? (
          <button type="button" className={styles.sourceUploadReset} onClick={onReset}>
            <RefreshIcon className={styles.inlineIcon} />
            <span>{isRu ? "Очистить" : "Clear"}</span>
          </button>
        ) : null}
      </div>
    </section>
  );
}

function formatReferenceDuration(value: number | undefined, isRu: boolean) {
  if (!value) {
    return isRu ? "Без референса" : "No reference";
  }

  const rounded = Math.max(0, Math.round(value));
  const minutes = Math.floor(rounded / 60).toString().padStart(2, "0");
  const seconds = (rounded % 60).toString().padStart(2, "0");
  return rounded >= 60 ? `${minutes}:${seconds}` : isRu ? `${rounded} сек` : `${rounded} sec`;
}

function toCssImageUrl(value: string) {
  return `url(${JSON.stringify(value)})`;
}

function formatGenerationDuration(run: AdminTemplateTestRun | null, isRu: boolean) {
  if (!run?.startedAtUtc || !run.completedAtUtc) {
    return isRu ? "В процессе" : "In progress";
  }

  const started = new Date(run.startedAtUtc).getTime();
  const completed = new Date(run.completedAtUtc).getTime();
  if (Number.isNaN(started) || Number.isNaN(completed) || completed < started) {
    return "-";
  }

  const seconds = Math.round((completed - started) / 1000);
  return formatReferenceDuration(seconds, isRu);
}

function formatTokenCost(value: number, isRu: boolean) {
  return `${value} ${isRu ? "токенов" : "tokens"}`;
}

function formatSeconds(value: number | undefined | null, isRu: boolean) {
  if (typeof value !== "number" || Number.isNaN(value) || value <= 0) {
    return "-";
  }

  const formatted = new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", {
    minimumFractionDigits: value % 1 === 0 ? 0 : 1,
    maximumFractionDigits: 2,
  }).format(value);

  return `${formatted} ${isRu ? "сек" : "sec"}`;
}

function formatUsd(value: number, locale: Locale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  }).format(value);
}

function formatProviderCost(run: AdminTemplateTestRun | null, locale: Locale) {
  if (typeof run?.motionProviderCostUsd === "number" && !Number.isNaN(run.motionProviderCostUsd)) {
    return formatUsd(run.motionProviderCostUsd, locale);
  }

  return locale === "ru"
    ? (run ? "После завершения" : "После генерации")
    : (run ? "After completion" : "After generation");
}

function formatProviderInference(run: AdminTemplateTestRun | null, isRu: boolean, isVideoTemplate: boolean) {
  const value = isVideoTemplate ? run?.motionInferenceTimeSeconds : run?.preprocessingInferenceTimeSeconds;
  if (typeof value === "number" && !Number.isNaN(value)) {
    return formatSeconds(value, isRu);
  }

  return isRu ? (run ? "После завершения" : "После генерации") : (run ? "After completion" : "After generation");
}

function formatDateTime(value: string | undefined | null, locale: Locale, withDate = false) {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(
    locale === "ru" ? "ru-RU" : "en-US",
    withDate
      ? {
        day: "2-digit",
        month: "short",
        hour: "2-digit",
        minute: "2-digit",
      }
      : {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      },
  ).format(date);
}

function formatBytes(value: number) {
  if (value < 1024 * 1024) {
    return `${Math.max(1, Math.round(value / 1024))} KB`;
  }

  return `${(value / 1024 / 1024).toFixed(1)} MB`;
}

function buildGeneratedDownloadName(templateTitle: string, generationId: string, extension: ".mp4" | ".png") {
  const safeTitle = templateTitle
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9а-яё]+/gi, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);

  return `${safeTitle || "template-test"}-${generationId}${extension}`;
}

function formatTemplateStatus(status: AdminTemplate["status"], locale: Locale) {
  if (locale !== "ru") {
    return status;
  }

  if (status === "Active") {
    return "Активен";
  }

  if (status === "Draft") {
    return "Черновик";
  }

  return "Архив";
}

function buildTimeline(run: AdminTemplateTestRun | null, locale: Locale, isVideoTemplate: boolean): TimelineItem[] {
  const isRu = locale === "ru";
  if (!run) {
    return [];
  }

  const items: TimelineItem[] = [
    {
      label: isRu ? "Тест поставлен в очередь" : "Test queued",
      at: formatDateTime(run.createdAtUtc, locale),
      description: isRu ? "Создана админская тестовая задача без списания токенов." : "A non-billed admin test job was created.",
      done: true,
    },
  ];

  if (run.sourceImageAsset) {
    items.push({
      label: isRu ? "Фото загружено" : "Photo uploaded",
      at: formatDateTime(run.createdAtUtc, locale),
      description: isRu ? "Исходный файл принят системой и закреплён за запуском." : "The source file was accepted and attached to the run.",
      done: true,
    });
  }

  if (run.startedAtUtc) {
    items.push({
      label: isVideoTemplate ? (isRu ? "Препроцессинг запущен" : "Preprocessing started") : (isRu ? "Генерация изображения запущена" : "Image generation started"),
      at: formatDateTime(run.startedAtUtc, locale),
      description: `${isRu ? "Модель" : "Model"}: ${run.usedPreprocessingModel ?? "-"}`,
      done: Boolean(run.preprocessingCompletedAtUtc),
    });
  }

  if (run.preprocessingCompletedAtUtc) {
    items.push({
      label: isVideoTemplate ? (isRu ? "Препроцессинг завершён" : "Preprocessing completed") : (isRu ? "Изображение получено от провайдера" : "Image received from provider"),
      at: formatDateTime(run.preprocessingCompletedAtUtc, locale),
      description: isVideoTemplate
        ? (isRu ? "Нормализованное изображение готово для генерации движения." : "The normalized image is ready for motion generation.")
        : (isRu ? "Итоговое изображение готово к импорту в media storage." : "The generated image is ready for media storage import."),
      done: true,
    });
  }

  if (isVideoTemplate && (run.preprocessingCompletedAtUtc || run.motionGenerationCompletedAtUtc)) {
    items.push({
      label: isRu ? "Генерация движения" : "Motion generation",
      at: formatDateTime(run.preprocessingCompletedAtUtc ?? run.startedAtUtc, locale),
      description: `${isRu ? "Модель" : "Model"}: ${run.usedKlingModel ?? "-"}`,
      done: Boolean(run.motionGenerationCompletedAtUtc),
    });
  }

  if (isVideoTemplate && run.motionGenerationCompletedAtUtc) {
    items.push({
      label: isRu ? "Видео получено от провайдера" : "Video received from provider",
      at: formatDateTime(run.motionGenerationCompletedAtUtc, locale),
      description: isRu ? "Промежуточный результат готов к импорту в media storage." : "The intermediate video is ready for media storage import.",
      done: Boolean(run.mediaImportCompletedAtUtc || (run.completedAtUtc && run.status === "Completed")),
    });
  }

  if (run.mediaImportCompletedAtUtc) {
    items.push({
      label: isRu ? "Импорт в media storage" : "Media storage import",
      at: formatDateTime(run.mediaImportCompletedAtUtc, locale),
      description: isVideoTemplate
        ? (isRu ? "Финальное видео сохранено и доступно для проверки." : "The final video was saved and is available for review.")
        : (isRu ? "Финальное изображение сохранено и доступно для проверки." : "The final image was saved and is available for review."),
      done: run.status === "Completed",
    });
  }

  if (run.completedAtUtc && run.status === "Completed") {
    items.push({
      label: isRu ? "Тест завершён успешно" : "Test completed successfully",
      at: formatDateTime(run.completedAtUtc, locale),
      description: isRu ? "Все артефакты доступны на этой странице." : "All generated artifacts are available on this page.",
      done: true,
    });
  }

  if (run.completedAtUtc && run.status === "Failed") {
    items.push({
      label: isRu ? "Тест завершён с ошибкой" : "Test failed",
      at: formatDateTime(run.completedAtUtc, locale),
      description: run.failureMessage ?? run.failureCode ?? (isRu ? "Ошибка генерации" : "Generation failed"),
      done: false,
    });
  }

  return items;
}
