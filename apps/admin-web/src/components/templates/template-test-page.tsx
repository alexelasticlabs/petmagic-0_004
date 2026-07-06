"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

import { PlayCircleIcon, RefreshIcon } from "@/components/admin/admin-icons";
import { ensureAdminSession } from "@/components/admin/admin-session";
import {
  MediaPreviewCard,
  MetricTile,
  SourceUploadCard,
  StatusPill,
  StepHeader,
  WorkflowConnector,
} from "@/components/templates/template-test-page.components";
import { getTemplateTestPageText } from "@/components/templates/template-test-page.content";
import {
  buildGeneratedDownloadName,
  buildRunDetails,
  buildTimeline,
  formatBytes,
  formatDateTime,
  formatGenerationDuration,
  formatProviderCost,
  formatProviderInference,
  formatReferenceDuration,
  formatTemplateStatus,
  formatTemplateTestDisplayText,
  formatTokenCost,
  getStartTestErrorMessage,
  getTemplateTestErrorDetails,
  isTemplateTestRunInFlight,
  MAX_TEMPLATE_TEST_IMAGE_BYTES,
} from "@/components/templates/template-test-page.helpers";
import styles from "@/components/templates/template-test-page.module.css";
import {
  TemplateTestHistorySection,
  TemplateTestPageHeader,
  TemplateTestRunSummarySection,
  TemplateTestTimelineSection,
} from "@/components/templates/template-test-page.sections";
import type {
  ArtifactItem,
  TemplateTestPageProps,
} from "@/components/templates/template-test-page.types";
import { Button } from "@/components/ui/button";
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
import { getDictionary } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export function TemplateTestPage({ locale, templateId }: TemplateTestPageProps) {
  const text = useMemo(() => getDictionary(locale), [locale]);
  const pageText = useMemo(() => getTemplateTestPageText(locale), [locale]);
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
  const [isTemplateTestPageVisible, setIsTemplateTestPageVisible] = useState(
    () => typeof document === "undefined" || !document.hidden
  );

  useEffect(() => {
    function handleVisibilityChange() {
      const isVisible = !document.hidden;
      setIsTemplateTestPageVisible(isVisible);
      if (isVisible) {
        setPollRetryNonce((current) => current + 1);
      }
    }

    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () => document.removeEventListener("visibilitychange", handleVisibilityChange);
  }, []);

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
    if (!run || !isTemplateTestRunInFlight(run) || !isTemplateTestPageVisible) {
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
  }, [isTemplateTestPageVisible, pageText.refreshStatusError, pollRetryNonce, run, templateId]);

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
    let isActive = true;
    if (!selectedHistoryGenerationId || historyGenerationIds.has(selectedHistoryGenerationId)) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setSelectedHistoryGenerationId(null);
      }
    });

    return () => {
      isActive = false;
    };
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
    try {
      selectedFilePreviewObjectUrlRef.current = objectUrl;
      setSelectedFile(file);
      setSelectedFilePreviewUrl(objectUrl);
      setRun(null);
      setSelectedHistoryGenerationId(null);
      setRunError(null);
    } catch (error) {
      if (selectedFilePreviewObjectUrlRef.current === objectUrl) {
        selectedFilePreviewObjectUrlRef.current = null;
      }
      URL.revokeObjectURL(objectUrl);
      throw error;
    }
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
    () => buildTimeline(activeRun, locale, pageText, isVideoTemplate),
    [activeRun, isVideoTemplate, locale, pageText]
  );
  const catalogPath = `/${locale}/templates/${templateSlug}`;
  const editorPath = `/${locale}/templates/${templateSlug}/editor?templateId=${encodeURIComponent(templateId)}`;
  const sourceImageUrl = selectedFilePreviewUrl ?? activeRun?.sourceImageAsset?.url ?? undefined;
  const selectedFileName = selectedFile
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
  const generationDuration = formatGenerationDuration(activeRun, pageText);
  const petMagicBillingLabel = pageText.petMagicBilling;
  const falProviderCostLabel = isVideoTemplate ? pageText.falMotionCost : pageText.falImageCost;
  const falInferenceLabel = isVideoTemplate ? pageText.falInference : pageText.falImageInference;
  const internalTokenCost = activeRun?.tokenCost ?? template?.tokenCost ?? 0;
  const internalBillingText = formatTokenCost(internalTokenCost);
  const providerCostText = formatProviderCost(activeRun, pageText);
  const providerInferenceText = formatProviderInference(activeRun, pageText, isVideoTemplate);
  const statusText = formatTemplateTestDisplayText(activeRun?.status, pageText.waitingToStart, 64);
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
    pageText,
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

  const headerPills = [
    {
      tone:
        template.status === "Active"
          ? ("success" as const)
          : template.status === "Draft"
            ? ("warning" as const)
            : ("muted" as const),
      label: formatTemplateStatus(template.status, locale),
    },
    {
      tone: template.isPremium ? ("premium" as const) : ("success" as const),
      label: template.isPremium ? text.premiumLabel : text.freeLabel,
    },
    {
      tone: "muted" as const,
      label: formatTokenCost(template.tokenCost),
    },
    {
      tone: "muted" as const,
      label: isVideoTemplate
        ? formatReferenceDuration(template.referenceVideoDurationSeconds, pageText)
        : formatTemplateTestDisplayText(template.imageModel, pageText.imageModelFallback, 80),
    },
  ];

  return (
    <section className={styles.page}>
      <TemplateTestPageHeader
        canManageTemplates={canManageTemplates}
        catalogPath={catalogPath}
        editorPath={editorPath}
        headerPills={headerPills}
        isVideoTemplate={isVideoTemplate}
        pageText={pageText}
        templateTitle={templateTitle}
      />

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
                text={pageText}
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
              <MetricTile label={pageText.generationTime} value={generationDuration} />
              <MetricTile label={pageText.lastUpdate} value={lastUpdateText} />
            </div>
          </section>

          <TemplateTestTimelineSection pageText={pageText} timeline={timeline} />

          <TemplateTestRunSummarySection pageText={pageText} runDetails={runDetails} />

          <TemplateTestHistorySection
            activeRun={activeRun}
            emptyText={text.templateTestHistoryEmpty}
            history={history}
            locale={locale}
            pageText={pageText}
            setRunError={setRunError}
            setSelectedHistoryGenerationId={setSelectedHistoryGenerationId}
          />
        </div>
      </div>
    </section>
  );
}
