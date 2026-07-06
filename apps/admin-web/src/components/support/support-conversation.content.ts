import { type Locale } from "@/lib/i18n";

export type SupportRelativeTimeFormat = "compact" | "verbose";

type SupportConversationCopy = {
  intlLocale: string;
  shared: {
    supportTitle: string;
    operator: string;
    attachment: string;
    deletedUserName: string;
    deletedUserEmail: string;
    photo: string;
    video: string;
    file: string;
    duration: string;
  };
  controller: {
    actionsForbidden: string;
    notificationTitle: string;
    realtimeMessageFallback: string;
    optimisticAttachmentPreview: (fileName?: string | null) => string;
  };
  page: {
    workspaceSubtitle: string;
    closedConversationReadonly: string;
    dragAndDropImage: string;
    loadPreviousMessages: string;
    retryAttachmentUpload: string;
    imageViewer: {
      close: string;
      download: string;
      jump: string;
      openOriginal: string;
      share: string;
      author: string;
      date: string;
      size: string;
      imagePreview: string;
      videoPreview: string;
      supportImageAlt: string;
      supportAttachmentFallback: string;
    };
    queue: {
      title: string;
      all: string;
      waiting: string;
      unassigned: string;
      archive: string;
      status: string;
      priority: string;
      priorityAll: string;
      priorityHigh: string;
      priorityNormal: string;
      priorityLow: string;
      sort: string;
      sortDefault: string;
      sortPriority: string;
      sortWaiting: string;
      sortUpdated: string;
      sortCreated: string;
      previousPage: string;
      nextPage: string;
      newMessagesTitle: (count: number) => string;
      pageCount: (page: number, start: number, end: number, total: number) => string;
      userUnreadTitle: (count: number) => string;
      adminUnreadTitle: (count: number) => string;
      assignedOperator: (name: string) => string;
      unassignedOperator: string;
    };
    message: {
      fileFallback: string;
      openPhoto: string;
      openVideo: string;
      reply: string;
      replyTo: string;
      jump: string;
      cancelReply: string;
      attachFile: string;
      read: string;
      sent: string;
      attachmentGroup: (count: number) => string;
    };
  };
  infoPanel: {
    panelTabsLabel: string;
    ticketInformation: string;
    updated: string;
    attachmentsTitle: (count: number) => string;
    viewAll: string;
    noAttachments: string;
    fileFallback: string;
    operatorTags: string;
    addTag: string;
    removeTag: string;
    tagFallback: string;
    add: string;
    tagHint: string;
    user: string;
    purchases: string;
    noData: string;
    ticketActions: string;
    closeConversationPrompt: string;
    close: string;
    cancel: string;
    allAttachments: string;
    open: string;
    activity: string;
    failures: string;
    occurrences: (count: number) => string;
    recentEvents: string;
    noActivityData: string;
    conversationHistory: string;
    timeline: string;
    timelineEmpty: string;
    walletLabel: string;
    attachmentKinds: {
      photo: string;
      video: string;
      audio: string;
      file: string;
    };
  };
  helpers: {
    justNow: string;
    minutesAgo: (value: number, format: SupportRelativeTimeFormat) => string;
    hoursAgo: (value: number) => string;
    daysAgo: (value: number) => string;
    newUserReply: string;
    waitPrefix: string;
    waitMinutes: (value: number) => string;
    waitHours: (value: number) => string;
    waitHoursMinutes: (hours: number, minutes: number) => string;
    accountNew: string;
    accountDays: (value: number) => string;
    accountMonths: (value: number) => string;
    accountYears: (value: number) => string;
    accountFact: (value: string) => string;
    messageCount: (value: number) => string;
    purchaseCount: (value: number) => string;
    fileSizeUnavailable: string;
    kilobytes: (value: number) => string;
    megabytes: (value: number) => string;
  };
};

function pluralizeRu(value: number, one: string, few: string, many: string) {
  const abs = Math.abs(value) % 100;
  const last = abs % 10;

  if (abs > 10 && abs < 20) {
    return many;
  }

  if (last === 1) {
    return one;
  }

  if (last >= 2 && last <= 4) {
    return few;
  }

  return many;
}

const supportConversationCopy: Record<Locale, SupportConversationCopy> = {
  ru: {
    intlLocale: "ru-RU",
    shared: {
      supportTitle: "Поддержка",
      operator: "Оператор",
      attachment: "Вложение",
      deletedUserName: "Удаленный пользователь",
      deletedUserEmail: "Пользователь удален",
      photo: "Фото",
      video: "Видео",
      file: "Файл",
      duration: "Длительность",
    },
    controller: {
      actionsForbidden: "Действия поддержки доступны только администраторам или модераторам.",
      notificationTitle: "Поддержка",
      realtimeMessageFallback: "Новое сообщение в поддержке",
      optimisticAttachmentPreview: (fileName) =>
        fileName?.trim() ? `Вложение: ${fileName.trim()}` : "Вложение",
    },
    page: {
      workspaceSubtitle: "Единое рабочее пространство для очереди, переписки и действий оператора",
      closedConversationReadonly: "Диалог закрыт. Чтобы продолжить, переоткройте обращение.",
      dragAndDropImage: "Перетащите фото сюда",
      loadPreviousMessages: "Загрузить предыдущие сообщения",
      retryAttachmentUpload: "Повторить",
      imageViewer: {
        close: "Закрыть",
        download: "Скачать",
        jump: "К сообщению",
        openOriginal: "Открыть оригинал",
        share: "Поделиться",
        author: "Автор",
        date: "Дата",
        size: "Размер",
        imagePreview: "Превью изображения",
        videoPreview: "Превью видео",
        supportImageAlt: "Изображение поддержки",
        supportAttachmentFallback: "Вложение поддержки",
      },
      queue: {
        title: "Очередь",
        all: "Все",
        waiting: "Ждут ответа",
        unassigned: "Без ответств.",
        archive: "Архив",
        status: "Статус",
        priority: "Приоритет",
        priorityAll: "Любой",
        priorityHigh: "Высокий",
        priorityNormal: "Обычный",
        priorityLow: "Низкий",
        sort: "Сортировка",
        sortDefault: "По умолч.",
        sortPriority: "Приоритет",
        sortWaiting: "Ожидание",
        sortUpdated: "Обновлено",
        sortCreated: "Создано",
        previousPage: "Предыдущая страница очереди",
        nextPage: "Следующая страница очереди",
        newMessagesTitle: (count) => `Новых сообщений от пользователей: ${count}`,
        pageCount: (page, start, end, total) =>
          `Страница ${page}: показано ${start}-${end} из ${total}`,
        userUnreadTitle: (count) => `Сообщений от пользователя: ${count}`,
        adminUnreadTitle: (count) => `Непрочитанных для админа: ${count}`,
        assignedOperator: (name) => `Оператор: ${name}`,
        unassignedOperator: "Без оператора",
      },
      message: {
        fileFallback: "Файл",
        openPhoto: "Открыть фото",
        openVideo: "Открыть видео",
        reply: "Ответить",
        replyTo: "Ответ на",
        jump: "К сообщению",
        cancelReply: "Отменить ответ",
        attachFile: "Прикрепить файл",
        read: "Прочитано",
        sent: "Отправлено",
        attachmentGroup: (count) => `Вложения (${count})`,
      },
    },
    infoPanel: {
      panelTabsLabel: "Разделы панели",
      ticketInformation: "Информация о тикете",
      updated: "Обновлён",
      attachmentsTitle: (count) => `Вложения (${count})`,
      viewAll: "Смотреть все",
      noAttachments: "Вложений пока нет",
      fileFallback: "Файл",
      operatorTags: "Теги оператора",
      addTag: "Добавить тег",
      removeTag: "Удалить тег",
      tagFallback: "Тег",
      add: "Добавить",
      tagHint: "Теги используются для быстрого поиска в очереди.",
      user: "Пользователь",
      purchases: "Покупки",
      noData: "Нет данных",
      ticketActions: "Действия по тикету",
      closeConversationPrompt: "Закрыть обращение?",
      close: "Закрыть",
      cancel: "Отмена",
      allAttachments: "Все вложения",
      open: "Открыть",
      activity: "Активность",
      failures: "Ошибки",
      occurrences: (count) => `Повторений: ${count}`,
      recentEvents: "Последние события",
      noActivityData: "Нет данных активности",
      conversationHistory: "История диалога",
      timeline: "Таймлайн",
      timelineEmpty: "История пуста",
      walletLabel: "PawSpark",
      attachmentKinds: {
        photo: "ФОТО",
        video: "ВИДЕО",
        audio: "АУДИО",
        file: "ФАЙЛ",
      },
    },
    helpers: {
      justNow: "только что",
      minutesAgo: (value, format) =>
        format === "verbose" ? `${value} мин назад` : `${value} мин назад`,
      hoursAgo: (value) => `${value} ч назад`,
      daysAgo: (value) => `${value} дн назад`,
      newUserReply: "Новый ответ пользователя",
      waitPrefix: "Ожидает",
      waitMinutes: (value) => `${value} мин`,
      waitHours: (value) => `${value} ч`,
      waitHoursMinutes: (hours, minutes) => `${hours} ч ${minutes} мин`,
      accountNew: "новый",
      accountDays: (value) => `${value} дн`,
      accountMonths: (value) => `${value} мес`,
      accountYears: (value) => `${value} г`,
      accountFact: (value) => `Аккаунт ${value}`,
      messageCount: (value) =>
        `${value} ${pluralizeRu(value, "сообщение", "сообщения", "сообщений")}`,
      purchaseCount: (value) => `${value} ${pluralizeRu(value, "покупка", "покупки", "покупок")}`,
      fileSizeUnavailable: "Размер не указан",
      kilobytes: (value) => `${value.toFixed(1)} КБ`,
      megabytes: (value) => `${value.toFixed(1)} МБ`,
    },
  },
  en: {
    intlLocale: "en-US",
    shared: {
      supportTitle: "Support",
      operator: "Operator",
      attachment: "Attachment",
      deletedUserName: "Deleted user",
      deletedUserEmail: "User deleted",
      photo: "Photo",
      video: "Video",
      file: "File",
      duration: "Duration",
    },
    controller: {
      actionsForbidden: "Support actions are available only to Admin or Moderator.",
      notificationTitle: "Support",
      realtimeMessageFallback: "New support message",
      optimisticAttachmentPreview: (fileName) =>
        fileName?.trim() ? `Attachment: ${fileName.trim()}` : "Attachment",
    },
    page: {
      workspaceSubtitle: "Unified workspace for queue, conversation, and operator actions",
      closedConversationReadonly: "Conversation is closed. Reopen it to continue.",
      dragAndDropImage: "Drop image here",
      loadPreviousMessages: "Load previous messages",
      retryAttachmentUpload: "Retry",
      imageViewer: {
        close: "Close",
        download: "Download",
        jump: "Jump to message",
        openOriginal: "Open original",
        share: "Share",
        author: "Author",
        date: "Date",
        size: "Size",
        imagePreview: "Image preview",
        videoPreview: "Video preview",
        supportImageAlt: "Support image",
        supportAttachmentFallback: "Support attachment",
      },
      queue: {
        title: "Queue",
        all: "All",
        waiting: "Waiting",
        unassigned: "Unassigned",
        archive: "Archive",
        status: "Status",
        priority: "Priority",
        priorityAll: "Any",
        priorityHigh: "High",
        priorityNormal: "Normal",
        priorityLow: "Low",
        sort: "Sort",
        sortDefault: "Default",
        sortPriority: "Priority",
        sortWaiting: "Waiting",
        sortUpdated: "Updated",
        sortCreated: "Created",
        previousPage: "Previous queue page",
        nextPage: "Next queue page",
        newMessagesTitle: (count) => `New messages from users: ${count}`,
        pageCount: (page, start, end, total) => `Page ${page}: showing ${start}-${end} of ${total}`,
        userUnreadTitle: (count) => `Messages from user: ${count}`,
        adminUnreadTitle: (count) => `Unread for admin: ${count}`,
        assignedOperator: (name) => `Operator: ${name}`,
        unassignedOperator: "Unassigned",
      },
      message: {
        fileFallback: "File",
        openPhoto: "Open photo",
        openVideo: "Open video",
        reply: "Reply",
        replyTo: "Reply to",
        jump: "Jump",
        cancelReply: "Cancel reply",
        attachFile: "Attach file",
        read: "Read",
        sent: "Sent",
        attachmentGroup: (count) => `Attachments (${count})`,
      },
    },
    infoPanel: {
      panelTabsLabel: "Panel tabs",
      ticketInformation: "Ticket information",
      updated: "Updated",
      attachmentsTitle: (count) => `Attachments (${count})`,
      viewAll: "View all",
      noAttachments: "No attachments yet",
      fileFallback: "File",
      operatorTags: "Operator tags",
      addTag: "Add tag",
      removeTag: "Remove tag",
      tagFallback: "Tag",
      add: "Add",
      tagHint: "Tags are used for fast queue search.",
      user: "User",
      purchases: "Purchases",
      noData: "No data",
      ticketActions: "Ticket actions",
      closeConversationPrompt: "Close conversation?",
      close: "Close",
      cancel: "Cancel",
      allAttachments: "All attachments",
      open: "Open",
      activity: "Activity",
      failures: "Failures",
      occurrences: (count) => `Occurrences: ${count}`,
      recentEvents: "Recent events",
      noActivityData: "No activity data",
      conversationHistory: "Conversation history",
      timeline: "Timeline",
      timelineEmpty: "Timeline is empty",
      walletLabel: "PawSpark",
      attachmentKinds: {
        photo: "PHOTO",
        video: "VIDEO",
        audio: "AUDIO",
        file: "FILE",
      },
    },
    helpers: {
      justNow: "just now",
      minutesAgo: (value, format) => (format === "verbose" ? `${value} min ago` : `${value}m ago`),
      hoursAgo: (value) => `${value}h ago`,
      daysAgo: (value) => `${value}d ago`,
      newUserReply: "New user reply",
      waitPrefix: "Waiting",
      waitMinutes: (value) => `${value} min`,
      waitHours: (value) => `${value} h`,
      waitHoursMinutes: (hours, minutes) => `${hours} h ${minutes} min`,
      accountNew: "new",
      accountDays: (value) => `${value}d`,
      accountMonths: (value) => `${value} mo`,
      accountYears: (value) => `${value} yr`,
      accountFact: (value) => `Account ${value}`,
      messageCount: (value) => `${value} ${value === 1 ? "message" : "messages"}`,
      purchaseCount: (value) => `${value} ${value === 1 ? "purchase" : "purchases"}`,
      fileSizeUnavailable: "Size unavailable",
      kilobytes: (value) => `${value.toFixed(1)} KB`,
      megabytes: (value) => `${value.toFixed(1)} MB`,
    },
  },
};

export function getSupportConversationCopy(locale: Locale): SupportConversationCopy {
  return supportConversationCopy[locale];
}
