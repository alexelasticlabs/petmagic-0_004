import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readTemplateTestPageLibrarySource } from "@/components/templates/template-test-page.test-source";

const templateTestPageContentPath = fileURLToPath(
  new URL("./template-test-page.content.ts", import.meta.url)
);
const templateEditorControllerPath = fileURLToPath(
  new URL("./use-template-editor-controller.ts", import.meta.url)
);
const templateEditorContentPath = fileURLToPath(
  new URL("./template-editor.content.ts", import.meta.url)
);
const templateEditorPath = fileURLToPath(new URL("../template-editor.tsx", import.meta.url));
const templatePreviewAssetSectionPath = fileURLToPath(
  new URL("./template-preview-asset-section.tsx", import.meta.url)
);
const templateTestPageStylesPath = fileURLToPath(
  new URL("./template-test-page.module.css", import.meta.url)
);
const templateEditorSectionsPath = fileURLToPath(
  new URL("./template-editor-sections.tsx", import.meta.url)
);
const templateEditorAssetStylesPath = fileURLToPath(
  new URL("./template-editor-assets.module.css", import.meta.url)
);

describe("template test media actions", () => {
  it("does not log or attach generated media URLs to action links", () => {
    const source = readTemplateTestPageLibrarySource();

    expect(source).not.toContain('clientLogger.warn("templates.media_preview_origin_check_failed"');
    expect(source).not.toContain("previewUrl,\n          error");
    expect(source).not.toContain("previewUrl,\r\n          error");
    expect(source).not.toContain("href={previewUrl}");
    expect(source).not.toContain("src={videoUrl}");
    expect(source).not.toContain("src={imageUrl}");
    expect(source).not.toContain("backgroundImage: toCssImageUrl(imageUrl)");
    expect(source).not.toContain('validationErrors.join(" ")');
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("fetchWithTimeout(previewUrl");
    expect(source).toContain("isUnsafeTemplateMediaUrl(previewUrl)");
    expect(source).toContain("templates.media_preview_fetch_blocked");
    expect(source).toContain("getBlockedUnsafeTemplateMediaUrlDetails(previewUrl)");
    expect(source).toContain("<TemplateSecureMedia");
    expect(source).toContain("templates.media_preview_fetch_failed");
    expect(source).toContain("function getTemplateTestErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("templateId: sanitizeSensitiveText(templateId, 80)");
    expect(source).toContain("generationId: sanitizeSensitiveText(activeRun.generationId, 80)");
    expect(source).toContain("...getTemplateTestErrorDetails(error)");
    expect(source).toContain("function downloadPreviewBlobUrl(objectUrl: string): void");
    expect(source).toContain("function revokePreviewBlobUrlOnFailure(");
    expect(source).toContain("URL.revokeObjectURL(objectUrl);");
    expect(source).toContain("schedulePreviewBlobUrlRevoke(objectUrl, 1000);");
    expect(source).toContain("schedulePreviewBlobUrlRevoke(objectUrl, 60_000);");
    expect(source).toContain(
      'anchor.download = downloadName ?? (videoUrl ? "template-test.mp4" : "template-test.png");'
    );
    expect(source).not.toContain("templateId,\n            error");
    expect(source).not.toContain("templateId,\n          error");
    expect(source).not.toContain("generationId: activeRun.generationId,\n          error");
    expect(source).not.toContain("mediaType,\n        error");
    expect(source).not.toContain('templates.media_preview_fetch_blocked", { url');
  });

  it("aborts pending generated media actions and ignores abort failures", () => {
    const source = readTemplateTestPageLibrarySource();

    expect(source).toContain("mediaActionAbortControllerRef.current?.abort()");
    expect(source).toContain("const controller = new AbortController()");
    expect(source).toContain("canManageTemplates={canManageTemplates}");
    expect(source).toContain("canManageTemplates: boolean;");
    expect(source).toContain("if (!canManageTemplates || !previewUrl || pendingMediaAction)");
    expect(source).toContain('fetchPreviewBlob("download", controller.signal)');
    expect(source).toContain('fetchPreviewBlob("open", controller.signal)');
    expect(source).toContain("if (signal.aborted)");
    expect(source).toContain("disabled={!canManageTemplates || pendingMediaAction !== null}");
  });

  it("falls back to a generated media download when opening a preview is blocked", () => {
    const source = readTemplateTestPageLibrarySource();

    expect(source).toContain(
      'const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");'
    );
    expect(source).toContain("if (!opened) {");
    expect(source).toContain("downloadPreviewBlobUrl(objectUrl);");
    expect(source).toContain("schedulePreviewBlobUrlRevoke(objectUrl, 1000);");
    expect(source).not.toContain(
      "if (!opened) {\n        URL.revokeObjectURL(objectUrl);\n        return;\n      }"
    );
  });

  it("revokes generated media blob URLs immediately if action handoff throws", () => {
    const source = readTemplateTestPageLibrarySource();

    expect(source).toContain("function revokePreviewBlobUrlOnFailure(objectUrl: string");
    expect(source).toContain("} catch (error) {\n      URL.revokeObjectURL(objectUrl);");
    expect(source).toContain("revokePreviewBlobUrlOnFailure(objectUrl, () => {");
  });

  it("guards template test generation against invalid and repeated submits", () => {
    const source = readTemplateTestPageLibrarySource();
    const contentSource = readFileSync(templateTestPageContentPath, "utf8");
    const ruContentSource = contentSource.slice(
      contentSource.indexOf("  ru: {"),
      contentSource.indexOf("  en: {")
    );

    expect(source).toContain("const MAX_TEMPLATE_TEST_IMAGE_BYTES = 8 * 1024 * 1024;");
    expect(source).toContain("function isTemplateTestRunInFlight(");
    expect(source).toContain('run?.status === "Queued"');
    expect(source).toContain('run?.status === "Processing"');
    expect(source).toContain('run?.status === "Retrying"');
    expect(source).toContain("const startTestInFlightRef = useRef(false);");
    expect(source).toContain(
      "if (startTestInFlightRef.current || isSubmitting || isTemplateTestRunInFlight(run)) {\n      return;\n    }"
    );
    expect(source).toContain("startTestInFlightRef.current = true;");
    expect(source).toContain("startTestInFlightRef.current = false;");
    expect(source).toContain("const templateTestInFlightMessage =");
    expect(source).toContain(
      "const templateTestActionsAdminOnly = text.templateTestActionsAdminOnly;"
    );
    expect(source).toContain(
      "const templateTestInFlightMessage = text.templateTestInFlightMessage;"
    );
    expect(source).toContain(
      "if (startTestInFlightRef.current || isSubmitting || isTemplateTestRunInFlight(run)) {\n      setRunError(templateTestInFlightMessage);\n      return;\n    }"
    );
    expect(source.indexOf("setRunError(templateTestInFlightMessage)")).toBeLessThan(
      source.indexOf("const objectUrl = URL.createObjectURL(file)")
    );
    expect(source.lastIndexOf("setRunError(templateTestInFlightMessage)")).toBeLessThan(
      source.indexOf("clearSelectedFilePreviewUrl();\n    setSelectedFile(null);")
    );
    expect(source).toContain("if (!selectedFile) {");
    expect(source).toContain("setRunError(text.templateTestChoosePhotoFirst);");
    expect(source.match(/if \(!file\.type\.startsWith\("image\/"\)\)/g) ?? []).toHaveLength(1);
    expect(source).toContain("setRunError(text.templateTestImageFileTypeError);");
    expect(source).toContain("if (file.size > MAX_TEMPLATE_TEST_IMAGE_BYTES) {");
    expect(source).toContain("setRunError(text.templateTestImageFileTooLarge);");
    expect(source.indexOf('if (!file.type.startsWith("image/"))')).toBeLessThan(
      source.indexOf("if (file.size > MAX_TEMPLATE_TEST_IMAGE_BYTES)")
    );
    expect(source.indexOf("if (file.size > MAX_TEMPLATE_TEST_IMAGE_BYTES)")).toBeLessThan(
      source.indexOf("const objectUrl = URL.createObjectURL(file)")
    );
    expect(source).toContain(
      "} catch (error) {\n      if (selectedFilePreviewObjectUrlRef.current === objectUrl)"
    );
    expect(source).toContain("URL.revokeObjectURL(objectUrl);");
    expect(source).toContain("throw error;");
    expect(source).toContain("const isCurrentRunInFlight = isTemplateTestRunInFlight(run);");
    expect(source).toContain("const [loadRetryNonce, setLoadRetryNonce] = useState(0);");
    expect(source).toContain("function handleRetryLoad()");
    expect(source).toContain("setLoadRetryNonce((current) => current + 1);");
    expect(source).toContain(
      "}, [canManageTemplates, loadRetryNonce, locale, pageText.loadTemplateError, router, templateId]);"
    );
    expect(source).toContain('<Button variant="secondary" onClick={handleRetryLoad}>');
    expect(source).toContain("const [pollRetryNonce, setPollRetryNonce] = useState(0);");
    expect(source).toContain(
      'const [isTemplateTestPageVisible, setIsTemplateTestPageVisible] = useState(\n    () => typeof document === "undefined" || !document.hidden\n  );'
    );
    expect(source).toContain(
      'document.addEventListener("visibilitychange", handleVisibilityChange);'
    );
    expect(source).toContain(
      'return () => document.removeEventListener("visibilitychange", handleVisibilityChange);'
    );
    expect(source).toContain(
      "if (!run || !isTemplateTestRunInFlight(run) || !isTemplateTestPageVisible) {\n      return;\n    }"
    );
    expect(source).toContain("setPollRetryNonce((current) => current + 1);");
    expect(source).toContain(
      "}, [isTemplateTestPageVisible, pageText.refreshStatusError, pollRetryNonce, run, templateId]);"
    );
    expect(source).toContain("setRunError(null);");
    expect(source).not.toContain(
      'if (!run || (run.status !== "Queued" && run.status !== "Processing"))'
    );
    expect(source).toContain(
      "disabled={\n                    !canManageTemplates || isSubmitting || isCurrentRunInFlight || !selectedFile\n                  }"
    );
    expect(source).toContain(
      "isDisabled={!canManageTemplates || isSubmitting || isCurrentRunInFlight}"
    );
    expect(source).toContain("disabled={isDisabled}");
    expect(source).toContain("aria-disabled={isDisabled}");
    expect(source).toContain(
      'import {\n  getTemplateTestPageText,\n  type TemplateTestPageText,\n} from "@/components/templates/template-test-page.content";'
    );
    expect(source).toContain(
      "const pageText = useMemo(() => getTemplateTestPageText(locale), [locale]);"
    );
    expect(source).not.toContain('const isRu = locale === "ru";');
    expect(contentSource).toContain('running: "В работе..."');
    expect(contentSource).toContain('running: "Running..."');
    expect(contentSource).toContain('chooseImageFile: "Выберите изображение"');
    expect(contentSource).toContain(
      'uploadSupport: "Поддерживаются изображения до 8 МБ и перетаскивание файла."'
    );
    expect(ruContentSource).toContain('falInference: "Время инференса Fal"');
    expect(ruContentSource).toContain('falImageInference: "Инференс изображения Fal"');
    expect(ruContentSource).toContain('falPreprocessInference: "Инференс препроцессинга Fal"');
    expect(ruContentSource).toContain('falMotionInferenceDetail: "Инференс движения Fal"');
    expect(ruContentSource).toContain(
      'timelineIntermediateVideoReady: "Промежуточный результат готов к импорту в медиахранилище."'
    );
    expect(ruContentSource).toContain('imageModelFallback: "Модель изображения"');
    expect(ruContentSource).toContain('result: "Результат"');
    expect(ruContentSource).toContain('sourceInputLabel: "Входные данные"');
    expect(ruContentSource).toContain('dropzoneTitle: "Зона загрузки"');
    expect(ruContentSource).not.toContain("Fal inference");
    expect(ruContentSource).not.toContain("media storage");
    expect(ruContentSource).not.toContain('imageModelFallback: "Image model",');
    expect(ruContentSource).not.toContain('result: "Result",');
    expect(ruContentSource).not.toContain('sourceInputLabel: "Input"');
    expect(ruContentSource).not.toContain('dropzoneTitle: "Dropzone"');
    expect(ruContentSource).not.toContain('drag-and-drop."');
    expect(ruContentSource).not.toContain("Выберите файл image/*");
    expect(ruContentSource).not.toContain("Поддерживается image/*");
    expect(contentSource).toContain(
      'uploadSupport: "Supports image/* up to 8 MB and drag-and-drop."'
    );
    expect(source).toContain("{text.templateTestHistoryEmpty}");
    expect(source).toContain("return text.templateTestStartFailed;");
    expect(source).toContain("return text.templateTestInvalidStatus;");
    expect(source).toContain("return text.templateTestImageModelRequired;");
    expect(source).toContain("return text.templateTestReferenceMotionRequired;");
    expect(source).toContain("return text.templateTestPreprocessingModelRequired;");
    expect(source).toContain("return text.templateTestKlingModelRequired;");
    expect(source).toContain("return text.templateTestCharacterOrientationRequired;");
    expect(source).toContain('clientLogger.warn("templates.test_start_failed", {');
    expect(source).toContain(
      'fileContentType: sanitizeSensitiveText(selectedFile.type || "image/*", 64)'
    );
    expect(source).toContain("fileSizeBytes: selectedFile.size");
    expect(source).toContain("...getTemplateTestErrorDetails(error)");
    expect(source).not.toContain("fileName: selectedFile.name");
    expect(source).not.toContain('clientLogger.warn("templates.test_start_failed", { error });');
    expect(source).not.toContain("Choose a test pet photo first.");
    expect(source).not.toContain("Only image/* files are supported.");
    expect(source).not.toContain("File is too large. The maximum test photo size is 8 MB.");
  });

  it("keeps template test generation admin-only at the handler and UI layer", () => {
    const source = readTemplateTestPageLibrarySource();

    expect(source).toContain("useAuthSession,");
    expect(source).toContain(
      'const canManageTemplates = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" })');
    expect(source).toContain("const templateTestActionsAdminOnly =");
    expect(source).toContain(
      "if (!canManageTemplates) {\n      setRunError(templateTestActionsAdminOnly);\n      return;\n    }"
    );
    expect(source.indexOf("if (!canManageTemplates)")).toBeLessThan(
      source.indexOf(
        "if (startTestInFlightRef.current || isSubmitting || isTemplateTestRunInFlight(run))"
      )
    );
    expect(source).toContain("{canManageTemplates ? (");
    expect(source).toContain("<Link href={editorPath}>{templateTitle}</Link>");
    expect(source).toContain("<Link href={editorPath} className={styles.primaryLink}>");
  });

  it("sanitizes visible template test metadata before rendering", () => {
    const source = readTemplateTestPageLibrarySource();

    expect(source).toContain("function formatTemplateTestDisplayText(");
    expect(source).toContain("const templateTitle = template");
    expect(source).toContain("<Link href={editorPath}>{templateTitle}</Link>");
    expect(source).toContain("<span>{templateTitle}</span>");
    expect(source).toContain(
      "formatTemplateTestDisplayText(template.imageModel, pageText.imageModelFallback, 80)"
    );
    expect(source).toContain('formatTemplateTestDisplayText(item.status, "-", 64)');
    expect(source).toContain("const safeValue = formatTemplateTestDisplayText(value");
    expect(source).toContain("const safeFileMeta = sanitizeSensitiveText(fileMeta");
    expect(source).toContain("formatTemplateTestDisplayText(\n        run.usedPreprocessingModel");
    expect(source).toContain("formatTemplateTestDisplayText(\n        run.usedKlingModel");
    expect(source).toContain(
      'value: formatTemplateTestDisplayText(run?.preprocessingProviderRequestId, "-", 120)'
    );
    expect(source).toContain(
      'value: formatTemplateTestDisplayText(run?.motionProviderRequestId, "-", 120)'
    );
    expect(source).toContain('value: formatTemplateTestDisplayText(run?.failureCode, "-", 120)');
    expect(source).toContain("const safeTitle = sanitizeSensitiveText(templateTitle, 96)");
    expect(source).toContain("const safeGenerationId = sanitizeSensitiveText(generationId, 64)");
    expect(source).toContain("description: formatTemplateTestDisplayText(run.failureCode");
    expect(source).toContain(
      "formatTemplateTestDisplayText(selectedFile.name, pageText.fileFallback, 120)"
    );
    expect(source).toContain(
      'formatTemplateTestDisplayText(activeRun.sourceImageAsset.fileName, "-", 120)'
    );
    expect(source).toContain(
      'formatTemplateTestDisplayText(\n        selectedFile.type || "image/*"'
    );
    expect(source).toContain(
      "formatTemplateTestDisplayText(\n          activeRun.sourceImageAsset.contentType"
    );
    expect(source).not.toContain("<Link href={editorPath}>{template.title}</Link>");
    expect(source).not.toContain('run.usedPreprocessingModel ?? "-"');
    expect(source).not.toContain('run.usedKlingModel ?? "-"');
    expect(source).not.toContain('value: run?.preprocessingProviderRequestId ?? "-"');
    expect(source).not.toContain('value: run?.motionProviderRequestId ?? "-"');
    expect(source).not.toContain('value: run?.failureCode ?? "-"');
    expect(source).not.toContain("selectedFile?.name ??");
    expect(source).not.toContain('${selectedFile.type || "image/*"}');
    expect(source).not.toContain("activeRun.sourceImageAsset.contentType}`");
    expect(source).not.toContain(
      'return `${safeTitle || "template-test"}-${generationId}${extension}`'
    );
    expect(source).not.toContain('run.failureCode ?? (isRu ? "Ошибка генерации"');
    expect(source).not.toContain("? fileMeta\n");
  });

  it("localizes template test stage placeholder labels", () => {
    const source = readTemplateTestPageLibrarySource();
    const contentSource = readFileSync(templateTestPageContentPath, "utf8");

    expect(contentSource).toContain('stageOne: "Этап 01"');
    expect(contentSource).toContain('stageOne: "Stage 01"');
    expect(contentSource).toContain('stageTwo: "Этап 02"');
    expect(contentSource).toContain('stageTwo: "Stage 02"');
    expect(source).toContain("const stageOneLabel = pageText.stageOne;");
    expect(source).toContain("const stageTwoLabel = pageText.stageTwo;");
    expect(source).toContain("placeholderEyebrow: stageOneLabel");
    expect(source).toContain("? stageTwoLabel");
    expect(source).toContain("openLabel: pageText.open");
    expect(source).toContain("downloadLabel: pageText.download");
    expect(source).not.toContain('const isRu = locale === "ru";');
    expect(source).not.toContain('stageOne: isRu ? "Этап 01" : "Stage 01"');
    expect(source).not.toContain('stageTwo: isRu ? "Этап 02" : "Stage 02"');
    expect(source).not.toContain('const stageOneLabel = isRu ? "Этап 01" : "Stage 01";');
    expect(source).not.toContain('const stageTwoLabel = isRu ? "Этап 02" : "Stage 02";');
  });

  it("keeps template test monetization labels centralized", () => {
    const source = readTemplateTestPageLibrarySource();

    expect(source).toContain("label: formatTokenCost(template.tokenCost)");
    expect(source).toContain("{pageText.petMagicBilling}: {formatTokenCost(item.tokenCost)}");
    expect(source).not.toContain("label: `${template.tokenCost} PawSpark`");
    expect(source).not.toContain("<span>PawSpark: {item.tokenCost}</span>");
  });

  it("keeps selected history media previews bound to the active run", () => {
    const source = readTemplateTestPageLibrarySource();

    expect(source).toContain(
      "const historyGenerationIds = useMemo(\n    () => new Set(history.map((item) => item.generationId)),"
    );
    expect(source).toContain(
      "if (!selectedHistoryGenerationId || historyGenerationIds.has(selectedHistoryGenerationId))"
    );
    expect(source).toContain("let isActive = true;");
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("if (isActive) {\n        setSelectedHistoryGenerationId(null);");
    expect(source).toContain("return () => {\n      isActive = false;\n    };");
    expect(source).toContain("}, [historyGenerationIds, selectedHistoryGenerationId]);");
    expect(source).toContain(
      "return history.find((item) => item.generationId === selectedHistoryGenerationId) ?? run;"
    );
    expect(source).toContain(
      "const sourceImageUrl = selectedFilePreviewUrl ?? activeRun?.sourceImageAsset?.url ?? undefined;"
    );
    expect(source).toContain("imageUrl: activeRun?.normalizedImageUrl ?? undefined");
    expect(source).toContain("selectedFile || activeRun?.sourceImageAsset");
    expect(source).toContain(
      "imageUrl: isVideoTemplate ? undefined : (activeRun?.outputUrl ?? undefined)"
    );
    expect(source).toContain(
      "videoUrl: isVideoTemplate ? (activeRun?.outputUrl ?? undefined) : undefined"
    );
    expect(source).toContain('activeRun?.status === "Processing"');
    expect(source).not.toContain("imageUrl: run?.normalizedImageUrl ?? undefined");
    expect(source).not.toContain("imageUrl: isVideoTemplate ? undefined : (run?.outputUrl");
    expect(source).not.toContain("videoUrl: isVideoTemplate ? (run?.outputUrl");
    expect(source).not.toContain('run?.status === "Processing"\n        ? isVideoTemplate');
  });

  it("keeps template test page visuals on semantic tokens without decorative tracking", () => {
    const stylesSource = readFileSync(templateTestPageStylesPath, "utf8");
    const nonZeroLetterSpacingRules = [...stylesSource.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1]?.trim())
      .filter((value) => value !== "0");

    expect(stylesSource).toContain("letter-spacing: 0;");
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toContain("radial-gradient");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(stylesSource).toContain(".historyItemHeader {");
    expect(stylesSource).toContain("flex-wrap: wrap;");
    expect(stylesSource).toContain(".historyItemHeader {\n    flex-direction: column;");
    expect(stylesSource).toContain("align-items: stretch;");
    expect(nonZeroLetterSpacingRules).toEqual([]);
  });

  it("does not log raw template upload filenames", () => {
    const source = readFileSync(templateEditorControllerPath, "utf8");

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("fileSizeBytes: file.size");
    expect(source).not.toContain("fileName:");
    expect(source).not.toContain("fileName: file.name");
  });

  it("defers preview duration detection to the authoritative server upload path", () => {
    const source = readFileSync(templateEditorControllerPath, "utf8");

    expect(source).not.toContain("readVideoDurationSeconds");
    // Local display URLs do not probe metadata or override server-measured duration.
    expect(source).not.toContain('document.createElement("video")');
    expect(source).toContain("uploadTemplateMedia(file, assetKind)");
    expect(source).not.toContain("uploadTemplateMedia(file, assetKind, { durationSeconds })");
  });

  it("keeps server-generated preview variants in the template form after upload", () => {
    const source = readFileSync(templateEditorControllerPath, "utf8");

    expect(source).toContain("asset: TemplateMediaUploadResponse");
    expect(source).toContain("thumbnailAsset: cloneTemplateAsset(asset.thumbnailAsset)");
    expect(source).toContain(
      "animatedPreviewAsset: cloneTemplateAsset(asset.animatedPreviewAsset)"
    );
    expect(source).toContain("feedLoopLowAsset: cloneTemplateAsset(asset.feedLoopLowAsset)");
    expect(source).toContain("feedLoopMediumAsset: cloneTemplateAsset(asset.feedLoopMediumAsset)");
    expect(source).toContain("detailPreviewAsset: cloneTemplateAsset(asset.detailPreviewAsset)");
    expect(source).toContain(
      "function cloneTemplateAsset(asset: TemplateAsset | null | undefined)"
    );
  });

  it("keeps template editor save and upload actions admin-only at the handler layer", () => {
    const source = readFileSync(templateEditorControllerPath, "utf8");
    const contentSource = readFileSync(templateEditorContentPath, "utf8");

    expect(source).toContain(
      'const canManageTemplates = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(source).toContain(
      'import { getTemplateEditorRuntimeText } from "@/components/templates/template-editor.content";'
    );
    expect(source).toContain("const runtimeText = getTemplateEditorRuntimeText(locale);");
    expect(source).toContain(
      "const templateEditorActionsAdminOnly = runtimeText.actionsAdminOnly;"
    );
    expect(source).toContain(
      "const notificationTitle = isVideo ? text.videoTemplatesTitle : text.imageTemplatesTitle;"
    );
    expect(source).toContain("title: notificationTitle,");
    expect(contentSource).toContain(
      'actionsAdminOnly: "Управление шаблонами доступно только администратору."'
    );
    expect(contentSource.slice(0, contentSource.indexOf("  en: {"))).not.toContain("только Admin");
    expect(contentSource).toContain(
      'actionsAdminOnly: "Template management actions are available to Admin only."'
    );
    expect(source).toContain("useAdminTemplateCategories({\n    enabled: canManageTemplates");
    expect(source).not.toContain("useAdminTemplateOptions(");
    expect(source).toContain("function assertCanManageTemplateEditor(): boolean");
    expect(source).toContain(
      'setToast({ type: "error", message: templateEditorActionsAdminOnly });'
    );
    expect(source).toContain("if (!assertCanManageTemplateEditor()) {\n      return;\n    }");
    expect(source).toContain("saveTemplateMutation.isPending");
    expect(source).toContain("uploadTemplateMediaMutation.isPending");
    expect(source).toContain("uploadingKind !== null");
    expect(source.indexOf("if (!assertCanManageTemplateEditor())")).toBeLessThan(
      source.indexOf("saveTemplateMutation.isPending")
    );
    expect(source.lastIndexOf("if (!assertCanManageTemplateEditor())")).toBeLessThan(
      source.lastIndexOf("uploadTemplateMediaMutation.isPending")
    );
  });

  it("keeps failed edit-template initialization recoverable without showing a blank create form", () => {
    const controllerSource = readFileSync(templateEditorControllerPath, "utf8");
    const editorSource = readFileSync(templateEditorPath, "utf8");

    expect(controllerSource).toContain("const [initializationError, setInitializationError]");
    expect(controllerSource).toContain("const [initializationRetryKey, setInitializationRetryKey]");
    expect(controllerSource).toContain("setInitializationError(null);");
    expect(controllerSource).toContain(
      "const message = getAdminErrorMessage(error, text.errorLoadingTemplates);"
    );
    expect(controllerSource).toContain("setInitializationError(message);");
    expect(controllerSource).toContain("function retryInitialization()");
    expect(controllerSource).toContain("setInitializationRetryKey((current) => current + 1);");
    expect(controllerSource).toContain("initializationError,");
    expect(controllerSource).toContain("retryInitialization,");
    expect(editorSource).toContain("if (initializationError) {");
    expect(editorSource).toContain("title={initializationError}");
    expect(editorSource).toContain("onClick={retryInitialization}");
    expect(editorSource).toContain("{text.adminRetryAction}");
    expect(editorSource).not.toContain('{locale === "ru" ? "Повторить" : "Retry"}');
    expect(editorSource.indexOf("if (initializationError)")).toBeLessThan(
      editorSource.indexOf("<form className={styles.editorForm}")
    );
  });

  it("resets edit-template forms back to the loaded template instead of create mode", () => {
    const controllerSource = readFileSync(templateEditorControllerPath, "utf8");

    expect(controllerSource).toContain("function resetForm()");
    expect(controllerSource).toContain("if (selectedTemplate) {");
    expect(controllerSource).toContain("setForm(createFormFromTemplate(selectedTemplate));");
    expect(controllerSource).toContain(
      "setEditorStatus(resolveEditorVisibilityStatus(selectedTemplate.status));"
    );
    expect(controllerSource).toContain(
      "} else {\n      setForm(createInitialTemplateForm(templateType));"
    );
    expect(controllerSource).toContain("setPreviewFile(null);");
    expect(controllerSource).toContain("setReferenceFile(null);");
    expect(controllerSource).not.toContain(
      "function resetForm() {\n    setSelectedTemplate(null);"
    );
  });

  it("shows template editor media selection errors before upload", () => {
    const editorSource = readFileSync(templateEditorPath, "utf8");
    const previewSource = readFileSync(templatePreviewAssetSectionPath, "utf8");
    const sectionsSource = readFileSync(templateEditorSectionsPath, "utf8");
    const stylesSource = readFileSync(templateEditorAssetStylesPath, "utf8");

    expect(editorSource).toMatch(/<TemplatePreviewAssetSection\s+text=\{text\}/);
    expect(editorSource).toMatch(/<TemplateReferenceAssetSection\s+text=\{text\}/);
    expect(previewSource).toContain("const TEMPLATE_PREVIEW_ASSET_MAX_BYTES = 25 * 1024 * 1024;");
    expect(sectionsSource).toContain(
      "const TEMPLATE_REFERENCE_MOTION_MAX_BYTES = 100 * 1024 * 1024;"
    );
    expect(previewSource).toContain("const supportedPreviewContentTypes = new Set([");
    expect(previewSource).toContain("const supportedPreviewFileNamePattern =");
    expect(previewSource).toContain("if (!isSupportedPreviewFile(file))");
    expect(previewSource).toContain("accept={templatePreviewAccept}");
    expect(previewSource).toContain('normalizedType !== "application/octet-stream"');
    expect(previewSource).toContain("const [selectionError, setSelectionError]");
    expect(sectionsSource).toContain("const [selectionError, setSelectionError]");
    expect(previewSource).toContain('setSelectionError(getPreviewSelectionError(text, "type"));');
    expect(previewSource).toContain('setSelectionError(getPreviewSelectionError(text, "size"));');
    expect(sectionsSource).toContain(
      'setSelectionError(getReferenceSelectionError(text, "type"));'
    );
    expect(sectionsSource).toContain(
      'setSelectionError(getReferenceSelectionError(text, "size"));'
    );
    expect(previewSource).toContain("text.previewAssetVideoBadge");
    expect(previewSource).toContain("text.previewAssetCoverBadge");
    expect(previewSource).toContain("return text.previewAssetFileTooLarge;");
    expect(previewSource).toContain("return text.previewAssetFileTypeError;");
    expect(sectionsSource).toContain("{text.referenceMotionSourceBadge}");
    expect(sectionsSource).toContain("return text.referenceMotionFileTooLarge;");
    expect(sectionsSource).toContain("return text.referenceMotionFileTypeError;");
    expect(previewSource).not.toContain(">Video preview<");
    expect(previewSource).not.toContain(">Cover asset<");
    expect(previewSource).not.toContain("File is too large. The maximum preview size is 25 MB.");
    expect(previewSource).not.toContain("Only image/* or video/* files are supported.");
    expect(sectionsSource).not.toContain(">Motion source<");
    expect(sectionsSource).not.toContain(
      "File is too large. The maximum reference motion size is 100 MB."
    );
    expect(sectionsSource).not.toContain("Only MP4 video files are supported.");
    expect(previewSource.indexOf("file.size > TEMPLATE_PREVIEW_ASSET_MAX_BYTES")).toBeLessThan(
      previewSource.indexOf("setPreviewFile(file)")
    );
    expect(sectionsSource.indexOf("file.size > TEMPLATE_REFERENCE_MOTION_MAX_BYTES")).toBeLessThan(
      sectionsSource.indexOf("setReferenceFile(file)")
    );
    expect(previewSource).toContain("thumbnailAsset: null");
    expect(previewSource).toContain("animatedPreviewAsset: null");
    expect(previewSource).toContain("feedLoopLowAsset: null");
    expect(previewSource).toContain("feedLoopMediumAsset: null");
    expect(previewSource).toContain("detailPreviewAsset: null");
    expect(stylesSource).toContain(".assetSelectionError");
  });
});
