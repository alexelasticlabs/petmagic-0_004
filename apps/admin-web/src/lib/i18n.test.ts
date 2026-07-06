import { describe, expect, it } from "vitest";

import { getDictionary, isLocale, locales } from "./i18n";

describe("i18n", () => {
  it("validates supported locales", () => {
    expect(isLocale("ru")).toBe(true);
    expect(isLocale("en")).toBe(true);
    expect(isLocale("de")).toBe(false);
    expect(locales).toEqual(["ru", "en"]);
  });

  it("returns dictionary with required keys", () => {
    const ru = getDictionary("ru");
    const en = getDictionary("en");

    expect(ru.navDashboard.length).toBeGreaterThan(0);
    expect(en.navDashboard.length).toBeGreaterThan(0);
    expect(ru.adminLoadingDescription.length).toBeGreaterThan(0);
    expect(en.adminLoadingDescription.length).toBeGreaterThan(0);
    expect(ru.adminMetadataDescription).not.toBe(en.adminMetadataDescription);
    expect(en.adminMetadataDescription).toBe("PetMagic administrator workspace.");
    expect(ru.promoCodesCodeLabel.length).toBeGreaterThan(0);
    expect(en.promoCodesCodeLabel.length).toBeGreaterThan(0);
  });

  it("keeps Russian admin copy free of English template-editor fallbacks", () => {
    const ru = getDictionary("ru");

    expect(ru.userNoEvents).toBe("Пользовательские события шаблонов пока не записаны.");
    expect(ru.confirmDeleteTemplate).toBe("Удалить шаблон и связанные загруженные медиафайлы?");
    expect(ru.promoBadgeAutoHint).not.toContain("NEW");
    expect(ru.promoBadgeNewHint).not.toContain("NEW");
    expect(ru.promoBadgePopularHint).toBe("Подходит для стабильных популярных шаблонов Premium.");
    expect(ru.editorTipOrientation).toBe(
      "Короткий референс лучше работает как быстрый визуальный ориентир, длинный даёт более выраженное направление движения."
    );
    expect(ru.tagsLabel).toBe("Теги через запятую");
    expect(ru.templateTestImageFileTypeError).toBe("Можно загрузить только файл image/*.");
  });
});
