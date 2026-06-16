"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type ChangeEvent,
  type DragEvent,
  type KeyboardEvent,
  type ReactNode,
} from "react";

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
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import styles from "@/components/templates/template-test-page.module.css";
import { Button } from "@/components/ui/button";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import {
  fetchAdminTemplate,
  fetchAdminTemplateTest,
  fetchAdminTemplateTestHistory,
  startAdminTemplateTest,
  useAuthSession,
  type AdminTemplate,
  type AdminTemplateTestRun,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

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

const MAX_TEMPLATE_TEST_IMAGE_BYTES = 8 * 1024 * 1024;

function formatTemplateTestDisplayText(
  value: string | null | undefined,
  fallback = "-",
  maxLength = 160
) {
  const trimmed = value?.trim();
  return sanitizeSensitiveText(trimmed || fallback, maxLength);
}

function getTemplateTestErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function isTemplateTestRunInFlight(run: AdminTemplateTestRun | null | undefined): boolean {
  return run?.status === "Queued" || run?.status === "Processing" || run?.status === "Retrying";
}

export function TemplateTestPage({ locale, templateId }: TemplateTestPageProps) {
  const isRu = locale === "ru";
  const text = useMemo(() => getDictionary(locale), [locale]);
  const pageText = useMemo(
    () => ({
      fileFallback: isRu ? "Файл" : "File",
      noPhotoSelected: isRu ? "Фото не выбрано" : "No photo selected",
      chooseImageFile: isRu ? "Выберите image/* файл" : "Choose an image/* file",
      petMagicBilling: isRu ? "Стоимость PetMagic" : "PetMagic billing",
      falMotionCost: isRu ? "Стоимость Fal" : "Fal motion cost",
      falImageCost: isRu ? "Стоимость Fal" : "Fal image cost",
      falInference: isRu ? "Fal inference" : "Fal inference time",
      falImageInference: isRu ? "Fal inference" : "Fal image inference",
      waitingToStart: isRu ? "Ожидает запуска" : "Waiting to start",
      templateFallback: isRu ? "Шаблон" : "Template",
      stageOne: isRu ? "Этап 01" : "Stage 01",
      stageTwo: isRu ? "Этап 02" : "Stage 02",
      preprocessing: isRu ? "Препроцессинг" : "Preprocessing",
      normalizedPhoto: isRu ? "Нормализованное фото" : "Normalized photo",
      preprocessingPending: isRu
        ? "Карточка заполнится сразу после завершения препроцессинга."
        : "This frame will fill in as soon as preprocessing finishes.",
      preprocessingEmpty: isRu
        ? "Загрузите фото питомца, чтобы подготовить кадр для генерации движения."
        : "Upload a pet photo to prepare the frame for motion generation.",
      finalVideo: isRu ? "Финальное видео" : "Final video",
      finalImage: isRu ? "Финальное изображение" : "Final image",
      result: "Result",
      readyVideo: isRu ? "Готовый ролик" : "Ready video",
      readyImage: isRu ? "Готовое изображение" : "Ready image",
      videoProcessing: isRu
        ? "Видео собирается. После завершения здесь появятся просмотр и скачивание."
        : "The video is being assembled. Preview and download will appear here after completion.",
      imageProcessing: isRu
        ? "Изображение генерируется. После завершения здесь появятся просмотр и скачивание."
        : "The image is being generated. Preview and download will appear here after completion.",
      videoReadyEmpty: isRu
        ? "После генерации здесь всегда будут доступны просмотр и скачивание финального видео."
        : "After generation, preview and download for the final video will always appear here.",
      imageReadyEmpty: isRu
        ? "После генерации здесь будут доступны просмотр и скачивание итогового изображения."
        : "After generation, preview and download for the final image will appear here.",
      open: isRu ? "Открыть" : "Open",
      download: isRu ? "Скачать" : "Download",
      loadingWorkspace: isRu ? "Загрузка тестового стенда..." : "Loading test workspace...",
      templateNotFound: isRu ? "Шаблон не найден." : "Template was not found.",
      retry: isRu ? "Повторить" : "Retry",
      videoTemplates: isRu ? "Видео шаблоны" : "Video templates",
      imageTemplates: isRu ? "Шаблоны изображений" : "Image templates",
      templateTest: isRu ? "Тест шаблона" : "Template test",
      backToCatalog: isRu ? "К каталогу" : "Back to catalog",
      openEditor: isRu ? "Открыть редактор" : "Open editor",
      generationResult: isRu ? "Результат генерации" : "Generation result",
      launching: isRu ? "Запуск..." : "Launching...",
      running: isRu ? "В работе..." : "Running...",
      generateTest: isRu ? "Сгенерировать тест" : "Generate test",
      generationTime: isRu ? "Время генерации" : "Generation time",
      lastUpdate: isRu ? "Последнее обновление" : "Last update",
      generationEvents: isRu ? "События генерации" : "Generation events",
      done: isRu ? "Готово" : "Done",
      runningShort: isRu ? "В работе" : "Running",
      timelineEmpty: isRu
        ? "После запуска здесь появятся этапы тестовой генерации."
        : "Pipeline milestones appear here after the test starts.",
      runSummary: isRu ? "Сводка запуска" : "Run summary",
      testHistory: isRu ? "История тестов" : "Test history",
      attempt: isRu ? "Попытка" : "Attempt",
      started: isRu ? "Старт" : "Started",
      completed: isRu ? "Завершён" : "Completed",
      loadTemplateError: isRu
        ? "Не удалось загрузить шаблон для теста."
        : "Failed to load the template for testing.",
      refreshStatusError: isRu
        ? "Не удалось обновить статус теста."
        : "Failed to refresh test status.",
    }),
    [isRu]
  );
  const router = useRouter();
  const session = useAuthSession();
  const canManageTemplates = session?.user.roles.includes("Admin") ?? false;
  const templateTestActionsAdminOnly = text.templateTestActionsAdminOnly;
  const templateTestInFlightMessage = text.templateTestInFlightMessage;
  const [template, setTemplate] = useState<AdminTemplate | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [selectedFilePreviewUrl, setSelectedFilePreviewUrl] = useState<string | null>(null);
  const selectedFilePreviewObjectUrlRef = useRef<string | null>(null);
  const [run, setRun] = useState<AdminTemplateTestRun | null>(null);
  const [history, setHistory] = useState<AdminTemplateTestRun[]>([]);
  const [selectedHistoryGenerationId, setSelectedHistoryGenerationId] = useState<string | null>(
    null
  );
  const [runError, setRunError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const startTestInFlightRef = useRef(false);
  const [isSourceDragActive, setIsSourceDragActive] = useState(false);
  const [loadRetryNonce, setLoadRetryNonce] = useState(0);
  const [pollRetryNonce, setPollRetryNonce] = useState(0);

  useEffect(() => {
    let isCancelled = false;
    const controller = new AbortController();

    async function loadTemplate() {
      setIsLoading(true);
      setLoadError(null);

      try {
        if (!ensureAdminSession(locale, router, { requiredRole: "Admin" })) {
          return;
        }

        const response = await fetchAdminTemplate(templateId, controller.signal);
        if (!isCancelled) {
          setTemplate(response);
        }

        try {
          const historyResponse = await fetchAdminTemplateTestHistory(
            templateId,
            12,
            controller.signal
          );
          if (!isCancelled) {
            setHistory(historyResponse);
            setRun(historyResponse[0] ?? null);
            setSelectedHistoryGenerationId(null);
          }
        } catch (error) {
          if (controller.signal.aborted || isCancelled) {
            return;
          }

          clientLogger.warn("templates.test_history_load_failed", {
            templateId: sanitizeSensitiveText(templateId, 80),
            ...getTemplateTestErrorDetails(error),
          });
          if (!isCancelled) {
            setHistory([]);
          }
        }
      } catch (error) {
        if (controller.signal.aborted || isCancelled) {
          return;
        }

        clientLogger.error("templates.test_template_load_failed", {
          templateId: sanitizeSensitiveText(templateId, 80),
          ...getTemplateTestErrorDetails(error),
        });
        if (!isCancelled) {
          setLoadError(pageText.loadTemplateError);
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
      controller.abort();
    };
  }, [canManageTemplates, loadRetryNonce, locale, pageText.loadTemplateError, router, templateId]);

  useEffect(() => {
    if (!run || !isTemplateTestRunInFlight(run)) {
      return;
    }

    const activeRun = run;
    const controller = new AbortController();
    const timer = window.setTimeout(async () => {
      try {
        const latest = await fetchAdminTemplateTest(activeRun.generationId, controller.signal);
        if (controller.signal.aborted) {
          return;
        }

        setRun(latest);
        setRunError(null);
        setHistory((current) =>
          [latest, ...current.filter((item) => item.generationId !== latest.generationId)].slice(
            0,
            12
          )
        );
      } catch (error) {
        if (controller.signal.aborted) {
          return;
        }

        clientLogger.warn("templates.test_polling_failed", {
          templateId: sanitizeSensitiveText(templateId, 80),
          generationId: sanitizeSensitiveText(activeRun.generationId, 80),
          ...getTemplateTestErrorDetails(error),
        });
        setRunError(pageText.refreshStatusError);
        setPollRetryNonce((current) => current + 1);
      }
    }, 2500);

    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [pageText.refreshStatusError, pollRetryNonce, run, templateId]);

  useEffect(
    () => () => {
      if (selectedFilePreviewObjectUrlRef.current) {
        URL.revokeObjectURL(selectedFilePreviewObjectUrlRef.current);
      }
    },
    []
  );

  const historyGenerationIds = useMemo(
    () => new Set(history.map((item) => item.generationId)),
    [history]
  );

  useEffect(() => {
    if (!selectedHistoryGenerationId || historyGenerationIds.has(selectedHistoryGenerationId)) {
      return;
    }

    queueMicrotask(() => setSelectedHistoryGenerationId(null));
  }, [historyGenerationIds, selectedHistoryGenerationId]);

  async function handleStartTest() {
    if (!canManageTemplates) {
      setRunError(templateTestActionsAdminOnly);
      return;
    }

    if (startTestInFlightRef.current || isSubmitting || isTemplateTestRunInFlight(run)) {
      return;
    }

    if (!selectedFile) {
      setRunError(text.templateTestChoosePhotoFirst);
      return;
    }

    startTestInFlightRef.current = true;
    setIsSubmitting(true);
    setRunError(null);

    try {
      const started = await startAdminTemplateTest(templateId, selectedFile);
      setRun(started);
      setSelectedHistoryGenerationId(null);
      setHistory((current) =>
        [started, ...current.filter((item) => item.generationId !== started.generationId)].slice(
          0,
          12
        )
      );
    } catch (error) {
      clientLogger.warn("templates.test_start_failed", {
        templateId: sanitizeSensitiveText(templateId, 80),
        fileContentType: sanitizeSensitiveText(selectedFile.type || "image/*", 64),
        fileSizeBytes: selectedFile.size,
        ...getTemplateTestErrorDetails(error),
      });
      setRunError(getStartTestErrorMessage(error, text, template?.templateType === "Video"));
    } finally {
      startTestInFlightRef.current = false;
      setIsSubmitting(false);
    }
  }

  function handleSourceFileSelected(file: File | null) {
    if (!file) {
      return;
    }

    if (!canManageTemplates) {
      setRunError(templateTestActionsAdminOnly);
      return;
    }

    if (startTestInFlightRef.current || isSubmitting || isTemplateTestRunInFlight(run)) {
      setRunError(templateTestInFlightMessage);
      return;
    }

    if (!file.type.startsWith("image/")) {
      setRunError(text.templateTestImageFileTypeError);
      return;
    }

    if (file.size > MAX_TEMPLATE_TEST_IMAGE_BYTES) {
      setRunError(text.templateTestImageFileTooLarge);
      return;
    }

    clearSelectedFilePreviewUrl();
    const objectUrl = URL.createObjectURL(file);
    selectedFilePreviewObjectUrlRef.current = objectUrl;
    setSelectedFile(file);
    setSelectedFilePreviewUrl(objectUrl);
    setRun(null);
    setSelectedHistoryGenerationId(null);
    setRunError(null);
  }

  function handleResetTest() {
    if (startTestInFlightRef.current || isSubmitting || isTemplateTestRunInFlight(run)) {
      setRunError(templateTestInFlightMessage);
      return;
    }

    clearSelectedFilePreviewUrl();
    setSelectedFile(null);
    setRun(null);
    setSelectedHistoryGenerationId(null);
    setRunError(null);
  }

  function handleRetryLoad() {
    setLoadRetryNonce((current) => current + 1);
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
  const activeRun = useMemo(() => {
    if (!selectedHistoryGenerationId) {
      return run;
    }

    return history.find((item) => item.generationId === selectedHistoryGenerationId) ?? run;
  }, [history, run, selectedHistoryGenerationId]);
  const isCurrentRunInFlight = isTemplateTestRunInFlight(run);
  const timeline = useMemo(
    () => buildTimeline(activeRun, locale, isVideoTemplate),
    [activeRun, isVideoTemplate, locale]
  );
  const catalogPath = `/${locale}/templates/${templateSlug}`;
  const editorPath = `/${locale}/templates/${templateSlug}/editor?templateId=${encodeURIComponent(templateId)}`;
  const sourceImageUrl = selectedFilePreviewUrl ?? activeRun?.sourceImageAsset?.url ?? undefined;
  const selectedFileName =
    selectedFile
      ? formatTemplateTestDisplayText(selectedFile.name, pageText.fileFallback, 120)
      : activeRun?.sourceImageAsset?.fileName
        ? formatTemplateTestDisplayText(activeRun.sourceImageAsset.fileName, "-", 120)
        : pageText.noPhotoSelected;
  const selectedFileMeta = selectedFile
    ? `${formatBytes(selectedFile.size)} • ${formatTemplateTestDisplayText(
        selectedFile.type || "image/*",
        "image/*",
        64
      )}`
    : activeRun?.sourceImageAsset?.fileSizeBytes
      ? `${formatBytes(activeRun.sourceImageAsset.fileSizeBytes)} • ${formatTemplateTestDisplayText(
          activeRun.sourceImageAsset.contentType,
          "image/*",
          64
        )}`
      : pageText.chooseImageFile;
  const generationDuration = formatGenerationDuration(activeRun, isRu);
  const petMagicBillingLabel = pageText.petMagicBilling;
  const falProviderCostLabel = isVideoTemplate ? pageText.falMotionCost : pageText.falImageCost;
  const falInferenceLabel = isVideoTemplate ? pageText.falInference : pageText.falImageInference;
  const internalTokenCost = activeRun?.tokenCost ?? template?.tokenCost ?? 0;
  const internalBillingText = formatTokenCost(internalTokenCost);
  const providerCostText = formatProviderCost(activeRun, locale);
  const providerInferenceText = formatProviderInference(activeRun, isRu, isVideoTemplate);
  const statusText = formatTemplateTestDisplayText(
    activeRun?.status,
    pageText.waitingToStart,
    64
  );
  const lastUpdateText = activeRun ? formatDateTime(activeRun.updatedAtUtc, locale, true) : "-";
  const templateTitle = template
    ? formatTemplateTestDisplayText(template.title, pageText.templateFallback, 120)
    : pageText.templateFallback;
  const finalDownloadName =
    activeRun && template
      ? buildGeneratedDownloadName(
          template.title,
          activeRun.generationId,
          isVideoTemplate ? ".mp4" : ".png"
        )
      : undefined;
  const runDetails = buildRunDetails({
    run: activeRun,
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
  const stageOneLabel = pageText.stageOne;
  const stageTwoLabel = pageText.stageTwo;
  const middleArtifact: ArtifactItem | null = isVideoTemplate
    ? {
        key: "normalized",
        title: pageText.preprocessing,
        accent: "preprocess",
        imageUrl: activeRun?.normalizedImageUrl ?? undefined,
        placeholderEyebrow: stageOneLabel,
        placeholderTitle: pageText.normalizedPhoto,
        placeholderText:
          selectedFile || activeRun?.sourceImageAsset
            ? pageText.preprocessingPending
            : pageText.preprocessingEmpty,
        openLabel: pageText.open,
        downloadLabel: pageText.download,
      }
    : null;
  const resultArtifact: ArtifactItem = {
    key: "output",
    title: isVideoTemplate ? pageText.finalVideo : pageText.finalImage,
    accent: "result",
    imageUrl: isVideoTemplate ? undefined : (activeRun?.outputUrl ?? undefined),
    videoUrl: isVideoTemplate ? (activeRun?.outputUrl ?? undefined) : undefined,
    placeholderEyebrow: isVideoTemplate ? stageTwoLabel : pageText.result,
    placeholderTitle: isVideoTemplate ? pageText.readyVideo : pageText.readyImage,
    placeholderText:
      activeRun?.status === "Processing"
        ? isVideoTemplate
          ? pageText.videoProcessing
          : pageText.imageProcessing
        : isVideoTemplate
          ? pageText.videoReadyEmpty
          : pageText.imageReadyEmpty,
    openLabel: pageText.open,
    downloadLabel: pageText.download,
    downloadName: finalDownloadName,
  };

  if (isLoading) {
    return (
      <section className={styles.page}>
        <p className={styles.infoText}>{pageText.loadingWorkspace}</p>
      </section>
    );
  }

  if (loadError || !template) {
    return (
      <section className={styles.page}>
        <p className={styles.errorText}>{loadError ?? pageText.templateNotFound}</p>
        <Button variant="secondary" onClick={handleRetryLoad}>
          <RefreshIcon className={styles.inlineIcon} />
          {pageText.retry}
        </Button>
      </section>
    );
  }

  return (
    <section className={styles.page}>
      <div className={styles.pageHeader}>
        <div className={styles.breadcrumbs}>
          <Link href={catalogPath}>
            {isVideoTemplate ? pageText.videoTemplates : pageText.imageTemplates}
          </Link>
          <span aria-hidden="true">/</span>
          {canManageTemplates ? (
            <Link href={editorPath}>{templateTitle}</Link>
          ) : (
            <span>{templateTitle}</span>
          )}
          <span aria-hidden="true">/</span>
          <span>{pageText.templateTest}</span>
        </div>

        <div className={styles.headerGrid}>
          <div className={styles.headerMeta}>
            <div className={styles.pillRow}>
              <StatusPill
                tone={
                  template.status === "Active"
                    ? "success"
                    : template.status === "Draft"
                      ? "warning"
                      : "muted"
                }
              >
                {formatTemplateStatus(template.status, locale)}
              </StatusPill>
              <StatusPill tone={template.isPremium ? "premium" : "success"}>
                {template.isPremium ? text.premiumLabel : text.freeLabel}
              </StatusPill>
              <StatusPill tone="muted">{template.tokenCost} PawSpark</StatusPill>
              <StatusPill tone="muted">
                {isVideoTemplate
                  ? formatReferenceDuration(template.referenceVideoDurationSeconds, isRu)
                  : formatTemplateTestDisplayText(
                      template.imageModel,
                      isRu ? "Image model" : "Image model",
                      80
                    )}
              </StatusPill>
            </div>
          </div>

          <div className={styles.headerActions}>
            <Link href={catalogPath} className={styles.secondaryLink}>
              <TableIcon className={styles.inlineIcon} />
              <span>{pageText.backToCatalog}</span>
            </Link>
            {canManageTemplates ? (
              <Link href={editorPath} className={styles.primaryLink}>
                <ChartIcon className={styles.inlineIcon} />
                <span>{pageText.openEditor}</span>
              </Link>
            ) : null}
          </div>
        </div>
      </div>

      <div className={styles.workflowGrid}>
        <div className={styles.resultsColumn}>
          <section className={styles.card}>
            <div className={styles.sectionHeaderRow}>
              <StepHeader number="1" title={pageText.generationResult} />
              <div className={styles.resultHeaderActions}>
                <StatusPill
                  tone={
                    activeRun?.status === "Completed"
                      ? "success"
                      : activeRun?.status === "Failed"
                        ? "danger"
                        : activeRun
                          ? "info"
                          : "muted"
                  }
                >
                  {statusText}
                </StatusPill>
                <Button
                  variant="primary"
                  disabled={
                    !canManageTemplates || isSubmitting || isCurrentRunInFlight || !selectedFile
                  }
                  onClick={() => void handleStartTest()}
                >
                  <PlayCircleIcon className={styles.inlineIcon} />
                  {isSubmitting
                    ? pageText.launching
                    : isCurrentRunInFlight
                      ? pageText.running
                      : pageText.generateTest}
                </Button>
              </div>
            </div>

            {runError ? <p className={styles.errorText}>{runError}</p> : null}

            <div
              className={`${styles.mediaGrid} ${isVideoTemplate ? "" : styles.mediaGridImage}`.trim()}
            >
              <SourceUploadCard
                isRu={isRu}
                imageUrl={sourceImageUrl}
                fileName={selectedFileName}
                fileMeta={selectedFileMeta}
                isDragActive={isSourceDragActive}
                isDisabled={!canManageTemplates || isSubmitting || isCurrentRunInFlight}
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
                    canManageTemplates={canManageTemplates}
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
                canManageTemplates={canManageTemplates}
              />
            </div>

            <div className={styles.resultMetrics}>
              <MetricTile label={petMagicBillingLabel} value={internalBillingText} />
              <MetricTile label={falProviderCostLabel} value={providerCostText} />
              <MetricTile label={falInferenceLabel} value={providerInferenceText} />
              <MetricTile
                label={pageText.generationTime}
                value={generationDuration}
              />
              <MetricTile
                label={pageText.lastUpdate}
                value={lastUpdateText}
              />
            </div>
          </section>

          <section className={styles.card}>
            <StepHeader number="2" title={pageText.generationEvents} />
            <div className={styles.timeline}>
              {timeline.length ? (
                timeline.map((event) => (
                  <div key={`${event.label}-${event.at}`} className={styles.timelineItem}>
                    <span
                      className={`${styles.timelineDot} ${event.done ? styles.timelineDotDone : ""}`}
                      aria-hidden="true"
                    >
                      ✓
                    </span>
                    <div className={styles.timelineText}>
                      <strong>{event.label}</strong>
                      <span>{event.description}</span>
                    </div>
                    <time>{event.at}</time>
                    <StatusPill tone={event.done ? "success" : "info"}>
                      {event.done ? pageText.done : pageText.runningShort}
                    </StatusPill>
                  </div>
                ))
              ) : (
                <p className={styles.infoText}>{pageText.timelineEmpty}</p>
              )}
            </div>
          </section>

          <section className={styles.card}>
            <StepHeader number="3" title={pageText.runSummary} />
            <div className={styles.detailGrid}>
              {runDetails.map((item) => (
                <DetailRow
                  key={item.label}
                  label={item.label}
                  value={item.value}
                  multiline={item.multiline}
                />
              ))}
            </div>
          </section>

          <section className={styles.card}>
            <StepHeader
              number="4"
              title={pageText.testHistory}
              badge={history.length ? String(history.length) : undefined}
            />
            {history.length ? (
              <div className={styles.historyList}>
                {history.map((item) => {
                  const isCurrent = activeRun?.generationId === item.generationId;
                  const sourceLabel = sanitizeSensitiveText(
                    item.sourceImageAsset?.fileName ?? pageText.noPhotoSelected,
                    120
                  );

                  return (
                    <button
                      key={item.generationId}
                      type="button"
                      className={`${styles.historyItem} ${isCurrent ? styles.historyItemCurrent : ""}`}
                      onClick={() => {
                        setSelectedHistoryGenerationId(item.generationId);
                        setRunError(null);
                      }}
                    >
                      <div className={styles.historyItemHeader}>
                        <div className={styles.historyItemTitleBlock}>
                          <strong>{formatDateTime(item.createdAtUtc, locale, true)}</strong>
                          <span>{sourceLabel}</span>
                        </div>
                        <StatusPill
                          tone={
                            item.status === "Completed"
                              ? "success"
                              : item.status === "Failed"
                                ? "danger"
                                : item.status === "Queued"
                                  ? "info"
                                  : "muted"
                          }
                        >
                          {formatTemplateTestDisplayText(item.status, "-", 64)}
                        </StatusPill>
                      </div>
                      <div className={styles.historyItemMeta}>
                        <span>
                          {pageText.attempt}: {item.attemptCount}
                        </span>
                        <span>
                          {isRu ? "PawSpark" : "PawSpark"}: {item.tokenCost}
                        </span>
                        <span>
                          {pageText.started}:{" "}
                          {formatDateTime(item.startedAtUtc, locale, true)}
                        </span>
                        <span>
                          {pageText.completed}:{" "}
                          {formatDateTime(item.completedAtUtc, locale, true)}
                        </span>
                      </div>
                    </button>
                  );
                })}
              </div>
            ) : (
              <p className={styles.infoText}>{text.templateTestHistoryEmpty}</p>
            )}
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

function getStartTestErrorMessage(
  error: unknown,
  text: Dictionary,
  isVideoTemplate: boolean
): string {
  const apiError = error as ApiLikeError | null;
  if (!apiError) {
    return text.templateTestStartFailed;
  }

  if (Array.isArray(apiError.validationErrors) && apiError.validationErrors.length > 0) {
    return getAdminErrorMessage({ validationErrors: apiError.validationErrors }, text.templateTestStartFailed);
  }

  if (apiError.code === "templates.invalid_status") {
    return text.templateTestInvalidStatus;
  }

  if (
    apiError.code === "templates.image_model_required" ||
    apiError.code === "templates.invalid_image_model"
  ) {
    return text.templateTestImageModelRequired;
  }

  if (isVideoTemplate && apiError.code === "templates.reference_motion_required") {
    return text.templateTestReferenceMotionRequired;
  }

  if (isVideoTemplate && apiError.code === "templates.invalid_preprocessing_model") {
    return text.templateTestPreprocessingModelRequired;
  }

  if (isVideoTemplate && apiError.code === "templates.invalid_kling_model") {
    return text.templateTestKlingModelRequired;
  }

  if (isVideoTemplate && apiError.code === "templates.character_orientation_required") {
    return text.templateTestCharacterOrientationRequired;
  }

  return getAdminErrorMessage(error, text.templateTestStartFailed);
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
    {
      label: isRu ? "Создан" : "Created",
      value: run ? formatDateTime(run.createdAtUtc, locale, true) : "-",
    },
    { label: isRu ? "Запущен" : "Started", value: formatDateTime(run?.startedAtUtc, locale, true) },
  ];

  if (!isVideoTemplate) {
    return [
      ...common,
      {
        label: isRu ? "Генерация изображения завершена" : "Image generation completed",
        value: formatDateTime(run?.preprocessingCompletedAtUtc, locale, true),
      },
      {
        label: isRu ? "Fal image request" : "Fal image request",
        value: formatTemplateTestDisplayText(run?.preprocessingProviderRequestId, "-", 120),
      },
      {
        label: isRu ? "Fal image inference" : "Fal image inference",
        value: formatSeconds(run?.preprocessingInferenceTimeSeconds, isRu),
      },
      {
        label: isRu ? "Импорт медиа" : "Media import",
        value: formatDateTime(run?.mediaImportCompletedAtUtc, locale, true),
      },
      {
        label: isRu ? "Код ошибки" : "Failure code",
        value: formatTemplateTestDisplayText(run?.failureCode, "-", 120),
      },
    ];
  }

  return [
    ...common,
    {
      label: isRu ? "Препроцессинг завершён" : "Preprocessing completed",
      value: formatDateTime(run?.preprocessingCompletedAtUtc, locale, true),
    },
    {
      label: isRu ? "Fal preprocess request" : "Fal preprocess request",
      value: formatTemplateTestDisplayText(run?.preprocessingProviderRequestId, "-", 120),
    },
    {
      label: isRu ? "Fal preprocess inference" : "Fal preprocess inference",
      value: formatSeconds(run?.preprocessingInferenceTimeSeconds, isRu),
    },
    {
      label: isRu ? "Motion завершён" : "Motion completed",
      value: formatDateTime(run?.motionGenerationCompletedAtUtc, locale, true),
    },
    {
      label: isRu ? "Fal motion request" : "Fal motion request",
      value: formatTemplateTestDisplayText(run?.motionProviderRequestId, "-", 120),
    },
    {
      label: isRu ? "Fal motion inference" : "Fal motion inference",
      value: formatSeconds(run?.motionInferenceTimeSeconds, isRu),
    },
    {
      label: isRu ? "Длительность финального видео" : "Final video duration",
      value: formatSeconds(run?.outputVideoDurationSeconds, isRu),
    },
    {
      label: isRu ? "Импорт медиа" : "Media import",
      value: formatDateTime(run?.mediaImportCompletedAtUtc, locale, true),
    },
    {
      label: isRu ? "Код ошибки" : "Failure code",
      value: formatTemplateTestDisplayText(run?.failureCode, "-", 120),
    },
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
  const icon =
    number === "1" ? (
      <PlayCircleIcon className={styles.stepIcon} />
    ) : number === "2" ? (
      <RefreshIcon className={styles.stepIcon} />
    ) : (
      <TableIcon className={styles.stepIcon} />
    );

  return (
    <div className={styles.stepHeader}>
      <h2>
        <span>{number}.</span> {icon}
        {title}
      </h2>
      {badge ? <StatusPill tone="success">{badge}</StatusPill> : null}
    </div>
  );
}

function StatusPill({
  children,
  tone,
}: {
  children: ReactNode;
  tone: "success" | "warning" | "danger" | "info" | "premium" | "muted";
}) {
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

function DetailRow({
  label,
  value,
  multiline = false,
}: {
  label: string;
  value: string;
  multiline?: boolean;
}) {
  const icon = /attempt|попыт/i.test(label) ? (
    <RefreshIcon className={styles.detailIcon} />
  ) : /status|статус/i.test(label) ? (
    <ChartIcon className={styles.detailIcon} />
  ) : /created|создан|started|запущен|completed|заверш|update|обнов/i.test(label) ? (
    <CalendarIcon className={styles.detailIcon} />
  ) : /duration|время|inference|sec|длительность/i.test(label) ? (
    <ClockIcon className={styles.detailIcon} />
  ) : /media|video|motion|preprocess|fal/i.test(label) ? (
    <VideoIcon className={styles.detailIcon} />
  ) : (
    <ImageIcon className={styles.detailIcon} />
  );
  const safeValue = formatTemplateTestDisplayText(value, "-", multiline ? 320 : 180);

  return (
    <div className={multiline ? styles.detailRowMultiline : styles.detailRow}>
      <span className={styles.detailLabel}>
        <span className={styles.detailLabelIcon}>{icon}</span>
        <span>{label}</span>
      </span>
      <strong>{safeValue}</strong>
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
  canManageTemplates,
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
  canManageTemplates: boolean;
}) {
  const previewUrl = videoUrl ?? imageUrl;
  const mediaType = videoUrl ? "video" : "image";
  const [pendingMediaAction, setPendingMediaAction] = useState<"download" | "open" | null>(
    null
  );
  const mediaActionAbortControllerRef = useRef<AbortController | null>(null);

  useEffect(
    () => () => {
      mediaActionAbortControllerRef.current?.abort();
    },
    []
  );

  async function fetchPreviewBlob(
    action: "download" | "open",
    signal: AbortSignal
  ): Promise<Blob | null> {
    if (!previewUrl) {
      return null;
    }

    try {
      const response = await fetchWithTimeout(previewUrl, { credentials: "include", signal });
      if (!response.ok) {
        clientLogger.warn("templates.media_preview_fetch_failed", {
          action,
          mediaType,
          status: response.status,
        });
        return null;
      }

      return response.blob();
    } catch (error) {
      if (signal.aborted) {
        return null;
      }

      clientLogger.warn("templates.media_preview_fetch_failed", {
        action,
        mediaType,
        ...getTemplateTestErrorDetails(error),
      });
      return null;
    }
  }

  function downloadPreviewBlobUrl(objectUrl: string): void {
    const anchor = document.createElement("a");
    anchor.href = objectUrl;
    anchor.download = downloadName ?? (videoUrl ? "template-test.mp4" : "template-test.png");
    anchor.rel = "noreferrer";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  async function handleDownload() {
    if (!canManageTemplates || !previewUrl || pendingMediaAction) {
      return;
    }

    mediaActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    mediaActionAbortControllerRef.current = controller;
    setPendingMediaAction("download");
    try {
      const blob = await fetchPreviewBlob("download", controller.signal);
      if (!blob || controller.signal.aborted) {
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      downloadPreviewBlobUrl(objectUrl);
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
    } finally {
      if (mediaActionAbortControllerRef.current === controller) {
        mediaActionAbortControllerRef.current = null;
        setPendingMediaAction(null);
      }
    }
  }

  async function handleOpen() {
    if (!canManageTemplates || !previewUrl || pendingMediaAction) {
      return;
    }

    mediaActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    mediaActionAbortControllerRef.current = controller;
    setPendingMediaAction("open");
    try {
      const blob = await fetchPreviewBlob("open", controller.signal);
      if (!blob || controller.signal.aborted) {
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");
      if (!opened) {
        downloadPreviewBlobUrl(objectUrl);
        window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
        return;
      }

      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    } finally {
      if (mediaActionAbortControllerRef.current === controller) {
        mediaActionAbortControllerRef.current = null;
        setPendingMediaAction(null);
      }
    }
  }

  return (
    <section className={`${styles.mediaPreviewCard} ${styles[`mediaPreviewCard_${accent}`]}`}>
      <div className={styles.mediaCardHeader}>
        <strong className={styles.mediaCardTitle}>
          {videoUrl ? (
            <VideoIcon className={styles.inlineIcon} />
          ) : (
            <ImageIcon className={styles.inlineIcon} />
          )}
          <span>{title}</span>
        </strong>
        <span>{placeholderEyebrow}</span>
      </div>

      {videoUrl ? (
        <TemplateSecureMedia
          url={videoUrl}
          kind="video"
          controls
          muted
          playsInline
          preload="metadata"
          className={styles.mediaAsset}
          ariaLabel={title}
          logContext={{ surface: "template_test_result" }}
        />
      ) : imageUrl ? (
        <TemplateSecureMedia
          url={imageUrl}
          kind="image"
          alt={title}
          width={720}
          height={420}
          className={`${styles.mediaAsset} ${styles.mediaAssetImage}`}
          logContext={{ surface: "template_test_result" }}
        />
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
            <button
              type="button"
              onClick={() => void handleOpen()}
              disabled={!canManageTemplates || pendingMediaAction !== null}
              className={styles.mediaActionLink}
            >
              {videoUrl ? (
                <PlayCircleIcon className={styles.inlineIcon} />
              ) : (
                <ImageIcon className={styles.inlineIcon} />
              )}
              <span>{openLabel ?? "Open"}</span>
            </button>
            <button
              type="button"
              onClick={() => void handleDownload()}
              disabled={!canManageTemplates || pendingMediaAction !== null}
              className={`${styles.mediaActionLink} ${styles.mediaActionLinkPrimary}`}
            >
              <DownloadIcon className={styles.inlineIcon} />
              <span>{downloadLabel ?? "Download"}</span>
            </button>
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
  isDisabled,
  onDragActiveChange,
  onFileSelected,
  onReset,
}: {
  isRu: boolean;
  imageUrl?: string;
  fileName: string;
  fileMeta: string;
  isDragActive: boolean;
  isDisabled: boolean;
  onDragActiveChange: (value: boolean) => void;
  onFileSelected: (file: File | null) => void;
  onReset?: () => void;
}) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const safeFileName = sanitizeSensitiveText(fileName, 120);
  const safeFileMeta = sanitizeSensitiveText(fileMeta, 120);

  function handleInputChange(event: ChangeEvent<HTMLInputElement>) {
    if (isDisabled) {
      event.target.value = "";
      return;
    }

    onFileSelected(event.target.files?.[0] ?? null);
    event.target.value = "";
  }

  function handleDragOver(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    if (isDisabled) {
      return;
    }

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
    if (isDisabled) {
      return;
    }

    onFileSelected(event.dataTransfer.files?.[0] ?? null);
  }

  function handleKeyDown(event: KeyboardEvent<HTMLLabelElement>) {
    if (isDisabled) {
      return;
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      inputRef.current?.click();
    }
  }

  return (
    <section className={`${styles.mediaPreviewCard} ${styles.mediaPreviewCard_source}`}>
      <div className={styles.mediaCardHeader}>
        <strong className={styles.mediaCardTitle}>
          <ImageIcon className={styles.inlineIcon} />
          <span>{isRu ? "Исходник" : "Source"}</span>
        </strong>
        <span>{isRu ? "Input" : "Input"}</span>
      </div>

      <label
        className={`${styles.uploadDropzone} ${isDragActive ? styles.uploadDropzoneActive : ""}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onKeyDown={handleKeyDown}
        aria-disabled={isDisabled}
        tabIndex={isDisabled ? -1 : 0}
      >
        <input
          ref={inputRef}
          className={styles.uploadDropzoneInput}
          type="file"
          accept="image/*"
          disabled={isDisabled}
          onChange={handleInputChange}
        />
        {imageUrl ? (
          <TemplateSecureMedia
            url={imageUrl}
            kind="image"
            alt={safeFileName}
            width={720}
            height={420}
            className={`${styles.mediaAsset} ${styles.mediaAssetImage}`}
            logContext={{ surface: "template_test_source" }}
          />
        ) : (
          <div className={`${styles.mediaAsset} ${styles.mediaPlaceholder}`}>
            <div className={styles.mediaPlaceholderGlow} aria-hidden="true" />
            <div className={styles.mediaPlaceholderBody}>
              <span>{isRu ? "Dropzone" : "Dropzone"}</span>
              <strong>{isRu ? "Добавьте фото питомца" : "Add pet photo"}</strong>
              <p>
                {isRu
                  ? "Нажмите на карточку или перетащите сюда изображение."
                  : "Click the card or drag an image here."}
              </p>
            </div>
          </div>
        )}

        {imageUrl ? (
          <span className={styles.uploadDropzoneBadge}>
            {isRu ? "Нажмите или перетащите для замены" : "Click or drag to replace"}
          </span>
        ) : null}
      </label>

      <div className={styles.sourceUploadFooter}>
        <div className={styles.sourceUploadMeta}>
          <strong>
            {imageUrl ? safeFileName : isRu ? "Фото не выбрано" : "No photo selected"}
          </strong>
          <span>
            {imageUrl
              ? safeFileMeta
              : isRu
                ? "Поддерживается image/* до 8 MB и drag-and-drop."
                : "Supports image/* up to 8 MB and drag-and-drop."}
          </span>
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
  const minutes = Math.floor(rounded / 60)
    .toString()
    .padStart(2, "0");
  const seconds = (rounded % 60).toString().padStart(2, "0");
  return rounded >= 60 ? `${minutes}:${seconds}` : isRu ? `${rounded} сек` : `${rounded} sec`;
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

function formatTokenCost(value: number) {
  return `${value} PawSpark`;
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
    ? run
      ? "После завершения"
      : "После генерации"
    : run
      ? "After completion"
      : "After generation";
}

function formatProviderInference(
  run: AdminTemplateTestRun | null,
  isRu: boolean,
  isVideoTemplate: boolean
) {
  const value = isVideoTemplate
    ? run?.motionInferenceTimeSeconds
    : run?.preprocessingInferenceTimeSeconds;
  if (typeof value === "number" && !Number.isNaN(value)) {
    return formatSeconds(value, isRu);
  }

  return isRu
    ? run
      ? "После завершения"
      : "После генерации"
    : run
      ? "After completion"
      : "After generation";
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
        }
  ).format(date);
}

function formatBytes(value: number) {
  if (value < 1024 * 1024) {
    return `${Math.max(1, Math.round(value / 1024))} KB`;
  }

  return `${(value / 1024 / 1024).toFixed(1)} MB`;
}

function buildGeneratedDownloadName(
  templateTitle: string,
  generationId: string,
  extension: ".mp4" | ".png"
) {
  const safeTitle = sanitizeSensitiveText(templateTitle, 96)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9а-яё]+/gi, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
  const safeGenerationId = sanitizeSensitiveText(generationId, 64)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]+/gi, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);

  return `${safeTitle || "template-test"}-${safeGenerationId || "run"}${extension}`;
}

function formatTemplateStatus(status: AdminTemplate["status"], locale: Locale) {
  if (locale !== "ru") {
    return formatTemplateTestDisplayText(status, "-", 48);
  }

  if (status === "Active") {
    return "Активен";
  }

  if (status === "Draft") {
    return "Черновик";
  }

  return status === "Archived" ? "Архив" : formatTemplateTestDisplayText(status, "Архив", 48);
}

function buildTimeline(
  run: AdminTemplateTestRun | null,
  locale: Locale,
  isVideoTemplate: boolean
): TimelineItem[] {
  const isRu = locale === "ru";
  if (!run) {
    return [];
  }

  const items: TimelineItem[] = [
    {
      label: isRu ? "Тест поставлен в очередь" : "Test queued",
      at: formatDateTime(run.createdAtUtc, locale),
      description: isRu
        ? "Создана админская тестовая задача без списания PawSpark."
        : "A non-billed admin test job was created.",
      done: true,
    },
  ];

  if (run.sourceImageAsset) {
    items.push({
      label: isRu ? "Фото загружено" : "Photo uploaded",
      at: formatDateTime(run.createdAtUtc, locale),
      description: isRu
        ? "Исходный файл принят системой и закреплён за запуском."
        : "The source file was accepted and attached to the run.",
      done: true,
    });
  }

  if (run.startedAtUtc) {
    items.push({
      label: isVideoTemplate
        ? isRu
          ? "Препроцессинг запущен"
          : "Preprocessing started"
        : isRu
          ? "Генерация изображения запущена"
          : "Image generation started",
      at: formatDateTime(run.startedAtUtc, locale),
      description: `${isRu ? "Модель" : "Model"}: ${formatTemplateTestDisplayText(
        run.usedPreprocessingModel,
        "-",
        80
      )}`,
      done: Boolean(run.preprocessingCompletedAtUtc),
    });
  }

  if (run.preprocessingCompletedAtUtc) {
    items.push({
      label: isVideoTemplate
        ? isRu
          ? "Препроцессинг завершён"
          : "Preprocessing completed"
        : isRu
          ? "Изображение получено от провайдера"
          : "Image received from provider",
      at: formatDateTime(run.preprocessingCompletedAtUtc, locale),
      description: isVideoTemplate
        ? isRu
          ? "Нормализованное изображение готово для генерации движения."
          : "The normalized image is ready for motion generation."
        : isRu
          ? "Итоговое изображение готово к импорту в media storage."
          : "The generated image is ready for media storage import.",
      done: true,
    });
  }

  if (isVideoTemplate && (run.preprocessingCompletedAtUtc || run.motionGenerationCompletedAtUtc)) {
    items.push({
      label: isRu ? "Генерация движения" : "Motion generation",
      at: formatDateTime(run.preprocessingCompletedAtUtc ?? run.startedAtUtc, locale),
      description: `${isRu ? "Модель" : "Model"}: ${formatTemplateTestDisplayText(
        run.usedKlingModel,
        "-",
        80
      )}`,
      done: Boolean(run.motionGenerationCompletedAtUtc),
    });
  }

  if (isVideoTemplate && run.motionGenerationCompletedAtUtc) {
    items.push({
      label: isRu ? "Видео получено от провайдера" : "Video received from provider",
      at: formatDateTime(run.motionGenerationCompletedAtUtc, locale),
      description: isRu
        ? "Промежуточный результат готов к импорту в media storage."
        : "The intermediate video is ready for media storage import.",
      done: Boolean(
        run.mediaImportCompletedAtUtc || (run.completedAtUtc && run.status === "Completed")
      ),
    });
  }

  if (run.mediaImportCompletedAtUtc) {
    items.push({
      label: isRu ? "Импорт в media storage" : "Media storage import",
      at: formatDateTime(run.mediaImportCompletedAtUtc, locale),
      description: isVideoTemplate
        ? isRu
          ? "Финальное видео сохранено и доступно для проверки."
          : "The final video was saved and is available for review."
        : isRu
          ? "Финальное изображение сохранено и доступно для проверки."
          : "The final image was saved and is available for review.",
      done: run.status === "Completed",
    });
  }

  if (run.completedAtUtc && run.status === "Completed") {
    items.push({
      label: isRu ? "Тест завершён успешно" : "Test completed successfully",
      at: formatDateTime(run.completedAtUtc, locale),
      description: isRu
        ? "Все артефакты доступны на этой странице."
        : "All generated artifacts are available on this page.",
      done: true,
    });
  }

  if (run.completedAtUtc && run.status === "Failed") {
    items.push({
      label: isRu ? "Тест завершён с ошибкой" : "Test failed",
      at: formatDateTime(run.completedAtUtc, locale),
      description: formatTemplateTestDisplayText(
        run.failureCode,
        isRu ? "Ошибка генерации" : "Generation failed",
        120
      ),
      done: false,
    });
  }

  return items;
}
