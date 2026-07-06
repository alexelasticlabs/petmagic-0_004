import { type Locale } from "@/lib/i18n";

export type AdminRouteFallbackText = {
  brandTitle: string;
  notFoundTitle: string;
  notFoundDescription: string;
  adminNotFoundActionTitle: string;
  adminNotFoundActionDescription: string;
  rootNotFoundActionDescription: string;
  signInActionLabel: string;
  globalErrorTitle: string;
  globalErrorDescription: string;
  retryActionLabel: string;
};

const adminRouteFallbackText: Record<Locale, AdminRouteFallbackText> = {
  ru: {
    brandTitle: "PetMagic Admin",
    notFoundTitle: "Страница не найдена",
    notFoundDescription: "Такого раздела в админ-панели нет или ссылка устарела.",
    adminNotFoundActionTitle: "Проверьте адрес страницы",
    adminNotFoundActionDescription:
      "Вернитесь в доступный раздел или выберите другой пункт в меню.",
    rootNotFoundActionDescription:
      "Вернитесь на страницу входа и откройте доступный раздел после проверки сессии.",
    signInActionLabel: "К входу",
    globalErrorTitle: "Не удалось открыть админ-панель",
    globalErrorDescription:
      "Произошла критическая ошибка интерфейса. Повторите попытку или вернитесь на страницу входа.",
    retryActionLabel: "Повторить",
  },
  en: {
    brandTitle: "PetMagic Admin",
    notFoundTitle: "Page not found",
    notFoundDescription: "This admin section does not exist or the link is no longer valid.",
    adminNotFoundActionTitle: "Check the page address",
    adminNotFoundActionDescription:
      "Return to an available section or choose another item from the menu.",
    rootNotFoundActionDescription:
      "Return to sign in and open an available section after the session check.",
    signInActionLabel: "Go to sign in",
    globalErrorTitle: "Unable to open the admin panel",
    globalErrorDescription:
      "A critical interface error occurred. Try again or return to the sign-in page.",
    retryActionLabel: "Retry",
  },
};

export function getAdminRouteFallbackText(locale: Locale): AdminRouteFallbackText {
  return adminRouteFallbackText[locale];
}
