import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const controllerPath = fileURLToPath(
  new URL("./use-template-editor-controller.ts", import.meta.url)
);
const contentPath = fileURLToPath(new URL("./template-editor.content.ts", import.meta.url));

describe("template editor route type guard", () => {
  it("rejects a mismatched template before hydrating or submitting the editor", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const contentSource = readFileSync(contentPath, "utf8");

    const responseGuardIndex = controllerSource.indexOf(
      "if (templateResponse.templateType !== templateType)"
    );
    const hydrateTemplateIndex = controllerSource.indexOf("setSelectedTemplate(templateResponse);");
    const saveGuardIndex = controllerSource.indexOf("if (!assertTemplateMatchesEditorRoute())");
    const uploadOnSaveIndex = controllerSource.indexOf("let formToSave = form;");
    const submitIndex = controllerSource.indexOf("await saveTemplateMutation.mutateAsync");

    expect(responseGuardIndex).toBeGreaterThanOrEqual(0);
    expect(responseGuardIndex).toBeLessThan(hydrateTemplateIndex);
    expect(controllerSource).toContain(
      'clientLogger.warn("templates.editor_template_type_mismatch"'
    );
    expect(controllerSource).toContain("setSelectedTemplate(null);");
    expect(controllerSource).toContain("setInitializationError(templateEditorTypeMismatch);");

    expect(saveGuardIndex).toBeGreaterThanOrEqual(0);
    expect(saveGuardIndex).toBeLessThan(uploadOnSaveIndex);
    expect(saveGuardIndex).toBeLessThan(submitIndex);
    expect(controllerSource).toContain(
      "if (!isTemplateRouteTypeCompatible(initialTemplateId, selectedTemplate, templateType))"
    );
    expect(contentSource).toContain(
      'templateTypeMismatch:\n      "Этот шаблон имеет другой тип и не может быть открыт в выбранном редакторе."'
    );
    expect(contentSource).toContain(
      'templateTypeMismatch:\n      "This template has a different type and cannot be opened in the selected editor."'
    );
  });
});
