import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const templateTestPagePath = fileURLToPath(
  new URL("./template-test-page.tsx", import.meta.url)
);
const templateEditorControllerPath = fileURLToPath(
  new URL("./use-template-editor-controller.ts", import.meta.url)
);
const templateEditorPath = fileURLToPath(new URL("../template-editor.tsx", import.meta.url));
const templatePreviewAssetSectionPath = fileURLToPath(
  new URL("./template-preview-asset-section.tsx", import.meta.url)
);
const templateEditorSectionsPath = fileURLToPath(
  new URL("./template-editor-sections.tsx", import.meta.url)
);
const templateEditorStylesPath = fileURLToPath(
  new URL("./template-editor.module.css", import.meta.url)
);

describe("template test media actions", () => {
  it("does not log or attach generated media URLs to action links", () => {
    const source = readFileSync(templateTestPagePath, "utf8");

    expect(source).not.toContain("clientLogger.warn(\"templates.media_preview_origin_check_failed\"");
    expect(source).not.toContain("previewUrl,\n          error");
    expect(source).not.toContain("previewUrl,\r\n          error");
    expect(source).not.toContain("href={previewUrl}");
    expect(source).not.toContain("src={videoUrl}");
    expect(source).not.toContain("src={imageUrl}");
    expect(source).not.toContain("backgroundImage: toCssImageUrl(imageUrl)");
    expect(source).not.toContain("validationErrors.join(\" \")");
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("fetchWithTimeout(previewUrl");
    expect(source).toContain("<TemplateSecureMedia");
    expect(source).toContain("templates.media_preview_fetch_failed");
  });

  it("aborts pending generated media actions and ignores abort failures", () => {
    const source = readFileSync(templateTestPagePath, "utf8");

    expect(source).toContain("mediaActionAbortControllerRef.current?.abort()");
    expect(source).toContain("const controller = new AbortController()");
    expect(source).toContain("canManageTemplates={canManageTemplates}");
    expect(source).toContain("canManageTemplates: boolean;");
    expect(source).toContain("if (!canManageTemplates || !previewUrl || pendingMediaAction)");
    expect(source).toContain("fetchPreviewBlob(\"download\", controller.signal)");
    expect(source).toContain("fetchPreviewBlob(\"open\", controller.signal)");
    expect(source).toContain("if (signal.aborted)");
    expect(source).toContain("disabled={!canManageTemplates || pendingMediaAction !== null}");
  });

  it("guards template test generation against invalid and repeated submits", () => {
    const source = readFileSync(templateTestPagePath, "utf8");

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
      "if (startTestInFlightRef.current || isSubmitting || isTemplateTestRunInFlight(run)) {\n      setRunError(templateTestInFlightMessage);\n      return;\n    }"
    );
    expect(source.indexOf("setRunError(templateTestInFlightMessage)")).toBeLessThan(
      source.indexOf("const objectUrl = URL.createObjectURL(file)")
    );
    expect(source.lastIndexOf("setRunError(templateTestInFlightMessage)")).toBeLessThan(
      source.indexOf("clearSelectedFilePreviewUrl();\n    setSelectedFile(null);")
    );
    expect(source).toContain("if (!selectedFile) {");
    expect(source.match(/if \(!file\.type\.startsWith\("image\/"\)\)/g) ?? []).toHaveLength(1);
    expect(source).toContain("if (file.size > MAX_TEMPLATE_TEST_IMAGE_BYTES) {");
    expect(source.indexOf('if (!file.type.startsWith("image/"))')).toBeLessThan(
      source.indexOf("if (file.size > MAX_TEMPLATE_TEST_IMAGE_BYTES)")
    );
    expect(source.indexOf("if (file.size > MAX_TEMPLATE_TEST_IMAGE_BYTES)")).toBeLessThan(
      source.indexOf("const objectUrl = URL.createObjectURL(file)")
    );
    expect(source).toContain("const isCurrentRunInFlight = isTemplateTestRunInFlight(run);");
    expect(source).toContain("if (!run || !isTemplateTestRunInFlight(run)) {\n      return;\n    }");
    expect(source).toContain("const [loadRetryNonce, setLoadRetryNonce] = useState(0);");
    expect(source).toContain("function handleRetryLoad()");
    expect(source).toContain("setLoadRetryNonce((current) => current + 1);");
    expect(source).toContain("}, [canManageTemplates, isRu, loadRetryNonce, locale, router, templateId]);");
    expect(source).toContain("<Button variant=\"secondary\" onClick={handleRetryLoad}>");
    expect(source).toContain("const [pollRetryNonce, setPollRetryNonce] = useState(0);");
    expect(source).toContain("setPollRetryNonce((current) => current + 1);");
    expect(source).toContain("}, [isRu, pollRetryNonce, run, templateId]);");
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
    expect(source).toContain('"Running..."');
    expect(source).toContain("Supports image/* up to 8 MB and drag-and-drop.");
  });

  it("keeps template test generation admin-only at the handler and UI layer", () => {
    const source = readFileSync(templateTestPagePath, "utf8");

    expect(source).toContain("useAuthSession,");
    expect(source).toContain('const canManageTemplates = session?.user.roles.includes("Admin") ?? false;');
    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" })');
    expect(source).toContain("const templateTestActionsAdminOnly =");
    expect(source).toContain(
      "if (!canManageTemplates) {\n      setRunError(templateTestActionsAdminOnly);\n      return;\n    }"
    );
    expect(source.indexOf("if (!canManageTemplates)")).toBeLessThan(
      source.indexOf("if (startTestInFlightRef.current || isSubmitting || isTemplateTestRunInFlight(run))")
    );
    expect(source).toContain("{canManageTemplates ? (\n              <Link href={editorPath}");
    expect(source).toContain("{canManageTemplates ? (\n            <Link href={editorPath}>{templateTitle}</Link>");
  });

  it("sanitizes visible template test metadata before rendering", () => {
    const source = readFileSync(templateTestPagePath, "utf8");

    expect(source).toContain("function formatTemplateTestDisplayText(");
    expect(source).toContain("const templateTitle = template");
    expect(source).toContain("<Link href={editorPath}>{templateTitle}</Link>");
    expect(source).toContain("<span>{templateTitle}</span>");
    expect(source).toContain("formatTemplateTestDisplayText(\n                      template.imageModel");
    expect(source).toContain("formatTemplateTestDisplayText(item.status, \"-\", 64)");
    expect(source).toContain("const safeValue = formatTemplateTestDisplayText(value");
    expect(source).toContain("const safeFileMeta = sanitizeSensitiveText(fileMeta");
    expect(source).toContain("formatTemplateTestDisplayText(\n        run.usedPreprocessingModel");
    expect(source).toContain("formatTemplateTestDisplayText(\n        run.usedKlingModel");
    expect(source).toContain(
      "value: formatTemplateTestDisplayText(run?.preprocessingProviderRequestId, \"-\", 120)"
    );
    expect(source).toContain(
      "value: formatTemplateTestDisplayText(run?.motionProviderRequestId, \"-\", 120)"
    );
    expect(source).toContain(
      "value: formatTemplateTestDisplayText(run?.failureCode, \"-\", 120)"
    );
    expect(source).toContain("const safeTitle = sanitizeSensitiveText(templateTitle, 96)");
    expect(source).toContain("const safeGenerationId = sanitizeSensitiveText(generationId, 64)");
    expect(source).toContain("description: formatTemplateTestDisplayText(\n        run.failureCode");
    expect(source).toContain(
      "formatTemplateTestDisplayText(selectedFile.name, isRu ? \"Файл\" : \"File\", 120)"
    );
    expect(source).toContain(
      "formatTemplateTestDisplayText(activeRun.sourceImageAsset.fileName, \"-\", 120)"
    );
    expect(source).toContain("formatTemplateTestDisplayText(\n        selectedFile.type || \"image/*\"");
    expect(source).toContain(
      "formatTemplateTestDisplayText(\n          activeRun.sourceImageAsset.contentType"
    );
    expect(source).not.toContain("<Link href={editorPath}>{template.title}</Link>");
    expect(source).not.toContain("run.usedPreprocessingModel ?? \"-\"");
    expect(source).not.toContain("run.usedKlingModel ?? \"-\"");
    expect(source).not.toContain("value: run?.preprocessingProviderRequestId ?? \"-\"");
    expect(source).not.toContain("value: run?.motionProviderRequestId ?? \"-\"");
    expect(source).not.toContain("value: run?.failureCode ?? \"-\"");
    expect(source).not.toContain("selectedFile?.name ??");
    expect(source).not.toContain("${selectedFile.type || \"image/*\"}");
    expect(source).not.toContain("activeRun.sourceImageAsset.contentType}`");
    expect(source).not.toContain("return `${safeTitle || \"template-test\"}-${generationId}${extension}`");
    expect(source).not.toContain("run.failureCode ?? (isRu ? \"Ошибка генерации\"");
    expect(source).not.toContain("? fileMeta\n");
  });

  it("does not log raw template upload filenames", () => {
    const source = readFileSync(templateEditorControllerPath, "utf8");

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("fileName: sanitizeSensitiveText(file.name, 120)");
    expect(source).not.toContain("fileName: file.name");
  });

  it("keeps template editor save and upload actions admin-only at the handler layer", () => {
    const source = readFileSync(templateEditorControllerPath, "utf8");

    expect(source).toContain('const canManageTemplates = session?.user.roles.includes("Admin") ?? false;');
    expect(source).toContain("useAdminTemplateCategories({\n    enabled: canManageTemplates");
    expect(source).toContain("useAdminTemplateOptions({ enabled: canManageTemplates, templateType })");
    expect(source).toContain("function assertCanManageTemplateEditor(): boolean");
    expect(source).toContain("setToast({ type: \"error\", message: templateEditorActionsAdminOnly });");
    expect(source).toContain("if (!assertCanManageTemplateEditor()) {\n      return;\n    }");
    expect(source.indexOf("if (!assertCanManageTemplateEditor())")).toBeLessThan(
      source.indexOf("if (saveTemplateMutation.isPending)")
    );
    expect(source.lastIndexOf("if (!assertCanManageTemplateEditor())")).toBeLessThan(
      source.indexOf("if (uploadTemplateMediaMutation.isPending || uploadingKind !== null)")
    );
  });

  it("shows template editor media selection errors before upload", () => {
    const editorSource = readFileSync(templateEditorPath, "utf8");
    const previewSource = readFileSync(templatePreviewAssetSectionPath, "utf8");
    const sectionsSource = readFileSync(templateEditorSectionsPath, "utf8");
    const stylesSource = readFileSync(templateEditorStylesPath, "utf8");

    expect(editorSource).toContain("<TemplatePreviewAssetSection\n                  locale={locale}");
    expect(editorSource).toContain("<TemplateReferenceAssetSection\n                    locale={locale}");
    expect(previewSource).toContain("const TEMPLATE_PREVIEW_ASSET_MAX_BYTES = 32 * 1024 * 1024;");
    expect(sectionsSource).toContain(
      "const TEMPLATE_REFERENCE_MOTION_MAX_BYTES = 128 * 1024 * 1024;"
    );
    expect(previewSource).toContain("const [selectionError, setSelectionError]");
    expect(sectionsSource).toContain("const [selectionError, setSelectionError]");
    expect(previewSource).toContain("setSelectionError(getPreviewSelectionError(locale, \"type\"));");
    expect(previewSource).toContain("setSelectionError(getPreviewSelectionError(locale, \"size\"));");
    expect(sectionsSource).toContain("setSelectionError(getReferenceSelectionError(locale, \"type\"));");
    expect(sectionsSource).toContain("setSelectionError(getReferenceSelectionError(locale, \"size\"));");
    expect(previewSource.indexOf("file.size > TEMPLATE_PREVIEW_ASSET_MAX_BYTES")).toBeLessThan(
      previewSource.indexOf("setPreviewFile(file)")
    );
    expect(sectionsSource.indexOf("file.size > TEMPLATE_REFERENCE_MOTION_MAX_BYTES")).toBeLessThan(
      sectionsSource.indexOf("setReferenceFile(file)")
    );
    expect(stylesSource).toContain(".assetSelectionError");
  });
});
