import type { Locale } from "@/lib/i18n";

const content = {
  ru: {
    title: "Новая рассылка",
    back: "К истории",
    recipients: "Получатели",
    audienceHint: "Кому отправить письмо",
    content: "Содержание письма",
    contentHint: "Тема и сообщение, которые увидят получатели",
    preview: "Предпросмотр текста",
    desktop: "Компьютер",
    mobile: "Телефон",
    previewHint:
      "Тема и текст обновляются по мере ввода. Оформление зависит от почтового приложения получателя.",
    subjectEmpty: "Здесь появится тема письма",
    bodyEmpty: "Начните писать сообщение — его текст появится здесь.",
    to: "Кому",
    review: "Проверить письмо",
    letter: "Письмо",
    check: "Проверка",
    ready: "Готово к проверке",
    incomplete: "Заполните тему, текст и подтвердите аудиторию",
    eligible: "Только активные пользователи с подтверждённым email",
    discardTitle: "Закрыть новую рассылку?",
    discardDescription: "Введённые тема, текст и выбор получателей в редакторе не будут сохранены.",
    discard: "Закрыть без сохранения",
    keepEditing: "Продолжить редактирование",
  },
  en: {
    title: "New campaign",
    back: "Back to history",
    recipients: "Recipients",
    audienceHint: "Choose who receives this message",
    content: "Message content",
    contentHint: "The subject and message your recipients will see",
    preview: "Message preview",
    desktop: "Desktop",
    mobile: "Phone",
    previewHint:
      "Subject and text update as you type. Appearance depends on the recipient’s email app.",
    subjectEmpty: "Your subject will appear here",
    bodyEmpty: "Start writing — your message will appear here.",
    to: "To",
    review: "Review message",
    letter: "Message",
    check: "Review",
    ready: "Ready to review",
    incomplete: "Add a subject and message, then confirm the audience",
    eligible: "Active users with confirmed email only",
    discardTitle: "Close this new campaign?",
    discardDescription:
      "The subject, message, and recipient changes in this editor will not be saved.",
    discard: "Close without saving",
    keepEditing: "Keep editing",
  },
};
export function getEmailBroadcastComposerText(locale: Locale) {
  return content[locale];
}
