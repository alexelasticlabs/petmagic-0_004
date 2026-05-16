"use client";

import { AdminCard, AdminStatusBadge } from "@/components/admin/admin-primitives";
import styles from "@/components/templates/template-test-page.module.css";
import { Button } from "@/components/ui/button";
import {
    fetchAdminTemplate,
    fetchAdminTemplateTest,
    getSession,
    startAdminTemplateTest,
    type AdminTemplate,
    type AdminTemplateTestRun,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

type TemplateTestPageProps = {
  locale: Locale;
  templateId: string;
};

const runStatusColors: Record<AdminTemplateTestRun["status"], string> = {
  Queued: "#94a3b8",
  Processing: "#60a5fa",
  Completed: "#22c55e",
  Failed: "#f87171",
};

export function TemplateTestPage({ locale, templateId }: TemplateTestPageProps) {
  const isRu = locale === "ru";
  const router = useRouter();
  const [template, setTemplate] = useState<AdminTemplate | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [run, setRun] = useState<AdminTemplateTestRun | null>(null);
  const [runError, setRunError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    let isCancelled = false;

    async function loadTemplate() {
      setIsLoading(true);
      setLoadError(null);

      try {
        const session = getSession();
        if (!session) {
          router.replace(`/${locale}`);
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
    } catch {
      setRunError(isRu ? "Не удалось запустить тестовую генерацию." : "Failed to start the test generation.");
    } finally {
      setIsSubmitting(false);
    }
  }

  const timeline = useMemo(() => buildTimeline(run, locale), [locale, run]);
  const catalogPath = `/${locale}/templates/video`;
  const editorPath = `/${locale}/templates/video/editor?templateId=${templateId}`;

  if (isLoading) {
    return <section className={styles.page}><p className={styles.infoText}>{isRu ? "Загрузка тестового стенда..." : "Loading test workspace..."}</p></section>;
  }

  if (loadError || !template) {
    return <section className={styles.page}><p className={styles.errorText}>{loadError ?? (isRu ? "Шаблон не найден." : "Template was not found.")}</p></section>;
  }

  return (
    <section className={styles.page}>
      <div className={styles.header}>
        <div className={styles.headerCopy}>
          <p className={styles.eyebrow}>Template test</p>
          <h1>{template.title}</h1>
          <p>{isRu ? "Запускайте тестовые генерации без списания токенов и проверяйте ключевые артефакты, модели и таймлайн в одном экране." : "Run non-billed test generations and inspect artifacts, models, and the run timeline in one screen."}</p>
        </div>
        <div className={styles.headerActions}>
          <Link href={catalogPath} className={styles.secondaryLink}>{isRu ? "К каталогу" : "Back to catalog"}</Link>
          <Link href={editorPath} className={styles.primaryLink}>{isRu ? "Открыть редактор" : "Open editor"}</Link>
        </div>
      </div>

      <div className={styles.summaryGrid}>
        <AdminCard className={styles.summaryCard} padding="md">
          <div className={styles.summaryHeader}>
            <div>
              <p className={styles.cardEyebrow}>{isRu ? "Template setup" : "Template setup"}</p>
              <h2>{isRu ? "Параметры шаблона" : "Template configuration"}</h2>
            </div>
            <AdminStatusBadge color={template.status === "Active" ? "#22c55e" : template.status === "Draft" ? "#facc15" : "#94a3b8"}>
              {template.status}
            </AdminStatusBadge>
          </div>
          <div className={styles.kpiGrid}>
            <KpiCard label={isRu ? "Препроцессинг" : "Preprocessing"} value={template.preprocessingModel ?? "-"} />
            <KpiCard label={isRu ? "Motion-модель" : "Motion model"} value={template.klingModel ?? "-"} />
            <KpiCard label={isRu ? "Примерная стоимость" : "Estimated cost"} value={`${template.tokenCost}`} />
            <KpiCard label={isRu ? "Референс" : "Reference"} value={formatReferenceDuration(template.referenceVideoDurationSeconds, isRu)} />
          </div>
        </AdminCard>

        <AdminCard className={styles.summaryCard} padding="md">
          <div className={styles.summaryHeader}>
            <div>
              <p className={styles.cardEyebrow}>{isRu ? "Test launch" : "Test launch"}</p>
              <h2>{isRu ? "Запустить новый тест" : "Start a new test"}</h2>
            </div>
          </div>
          <label className={styles.uploadField}>
            <span>{isRu ? "Тестовое фото питомца" : "Test pet photo"}</span>
            <input type="file" accept="image/*" onChange={(event) => setSelectedFile(event.target.files?.[0] ?? null)} />
          </label>
          <p className={styles.infoText}>
            {selectedFile
              ? selectedFile.name
              : isRu
                ? "Поддерживаются image/* файлы. После запуска появятся исходник, препроцессинг и финальный ролик."
                : "Any image/* file is allowed. After launch you will see the source, preprocessing result, and the final video."}
          </p>
          <div className={styles.launchRow}>
            <Button variant="primary" disabled={isSubmitting} onClick={() => void handleStartTest()}>{isSubmitting ? (isRu ? "Запуск..." : "Launching...") : (isRu ? "Сгенерировать тест" : "Generate test")}</Button>
            {run ? <AdminStatusBadge color={runStatusColors[run.status]}>{run.status}</AdminStatusBadge> : null}
          </div>
          {runError ? <p className={styles.errorText}>{runError}</p> : null}
        </AdminCard>
      </div>

      <div className={styles.contentGrid}>
        <AdminCard className={styles.mediaCard} padding="md">
          <div className={styles.summaryHeader}>
            <div>
              <p className={styles.cardEyebrow}>Artifacts</p>
              <h2>{isRu ? "Результаты теста" : "Test outputs"}</h2>
            </div>
          </div>
          <div className={styles.mediaGrid}>
            <MediaPreviewCard title="Original image" imageUrl={run?.sourceImageAsset?.url} emptyLabel={isRu ? "Исходник появится после старта теста." : "The source image appears after the test starts."} />
            <MediaPreviewCard title="Preprocessed image" imageUrl={run?.normalizedImageUrl ?? undefined} emptyLabel={isRu ? "Препроцессинг появится после первого шага pipeline." : "The preprocessing result appears after the first pipeline step."} />
            <MediaPreviewCard title="Final video" videoUrl={run?.outputUrl ?? undefined} emptyLabel={isRu ? "Финальное видео появится после успешного завершения генерации." : "The final video appears after successful generation."} />
          </div>
        </AdminCard>

        <div className={styles.sideStack}>
          <AdminCard className={styles.sideCard} padding="md">
            <div className={styles.summaryHeader}>
              <div>
                <p className={styles.cardEyebrow}>{isRu ? "Run details" : "Run details"}</p>
                <h2>{isRu ? "Детали запуска" : "Run details"}</h2>
              </div>
            </div>
            <DetailRow label={isRu ? "Статус" : "Status"} value={run?.status ?? "-"} />
            <DetailRow label={isRu ? "Попытка" : "Attempt"} value={run ? String(run.attemptCount) : "-"} />
            <DetailRow label={isRu ? "Примерная стоимость" : "Estimated cost"} value={String(run?.tokenCost ?? template.tokenCost)} />
            <DetailRow label={isRu ? "Время генерации" : "Generation time"} value={formatGenerationDuration(run, isRu)} />
            <DetailRow label={isRu ? "Последнее обновление" : "Last update"} value={formatDateTime(run?.updatedAtUtc, locale)} />
            <DetailRow label={isRu ? "Runtime preprocessing" : "Runtime preprocessing"} value={run?.usedPreprocessingModel ?? template.preprocessingModel ?? "-"} hint={isRu ? "Модель, зафиксированная в конкретном запуске." : "Model snapshot used by this run."} />
            <DetailRow label={isRu ? "Runtime motion" : "Runtime motion"} value={run?.usedKlingModel ?? template.klingModel ?? "-"} hint={isRu ? "Motion-модель, зафиксированная в конкретном запуске." : "Motion model snapshot used by this run."} />
            <DetailRow label={isRu ? "Препроцессинг завершён" : "Preprocessing completed"} value={formatDateTime(run?.preprocessingCompletedAtUtc, locale)} />
            <DetailRow label={isRu ? "Motion завершён" : "Motion completed"} value={formatDateTime(run?.motionGenerationCompletedAtUtc, locale)} />
            <DetailRow label={isRu ? "Импорт медиа" : "Media import"} value={formatDateTime(run?.mediaImportCompletedAtUtc, locale)} />
            <DetailRow label={isRu ? "Ошибка" : "Failure"} value={run?.failureMessage ?? "-"} />
          </AdminCard>

          <AdminCard className={styles.sideCard} padding="md">
            <div className={styles.summaryHeader}>
              <div>
                <p className={styles.cardEyebrow}>Timeline</p>
                <h2>{isRu ? "События генерации" : "Generation events"}</h2>
              </div>
            </div>
            <div className={styles.timeline}>
              {timeline.length ? timeline.map((event) => (
                <div key={`${event.label}-${event.at}`} className={styles.timelineItem}>
                  <span className={styles.timelineDot} aria-hidden="true" />
                  <div>
                    <strong>{event.label}</strong>
                    <span>{event.at}</span>
                    {event.description ? <span className={styles.timelineMeta}>{event.description}</span> : null}
                  </div>
                </div>
              )) : <p className={styles.infoText}>{isRu ? "После запуска здесь появятся этапы тестовой генерации." : "Timeline milestones appear here after the test starts."}</p>}
            </div>
          </AdminCard>
        </div>
      </div>
    </section>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.kpiCard}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function DetailRow({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className={styles.detailRow}>
      <span>{label}</span>
      <div className={styles.detailValue}>
        <strong>{value}</strong>
        {hint ? <small>{hint}</small> : null}
      </div>
    </div>
  );
}

function MediaPreviewCard({ title, imageUrl, videoUrl, emptyLabel }: { title: string; imageUrl?: string; videoUrl?: string; emptyLabel: string }) {
  return (
    <section className={styles.mediaPreviewCard}>
      <h3>{title}</h3>
      {videoUrl ? (
        <video src={videoUrl} controls className={styles.mediaAsset} />
      ) : imageUrl ? (
        <img src={imageUrl} alt={title} className={styles.mediaAsset} />
      ) : (
        <div className={styles.mediaPlaceholder}>{emptyLabel}</div>
      )}
    </section>
  );
}

function formatReferenceDuration(value: number | undefined, isRu: boolean) {
  if (!value) {
    return "-";
  }

  const rounded = Math.max(0, Math.round(value));
  const minutes = Math.floor(rounded / 60).toString().padStart(2, "0");
  const seconds = (rounded % 60).toString().padStart(2, "0");
  return rounded >= 60 ? `${minutes}:${seconds}` : isRu ? `${rounded} сек` : `${rounded} sec`;
}

function formatGenerationDuration(run: AdminTemplateTestRun | null, isRu: boolean) {
  if (!run?.startedAtUtc || !run.completedAtUtc) {
    return "-";
  }

  const started = new Date(run.startedAtUtc).getTime();
  const completed = new Date(run.completedAtUtc).getTime();
  if (Number.isNaN(started) || Number.isNaN(completed) || completed < started) {
    return "-";
  }

  const seconds = Math.round((completed - started) / 1000);
  return formatReferenceDuration(seconds, isRu);
}

function formatDateTime(value: string | undefined | null, locale: Locale) {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function buildTimeline(run: AdminTemplateTestRun | null, locale: Locale) {
  const isRu = locale === "ru";
  if (!run) {
    return [];
  }

  const items: Array<{ label: string; at: string; description?: string }> = [
    {
      label: isRu ? "Тест поставлен в очередь" : "Test queued",
      at: formatDateTime(run.createdAtUtc, locale),
      description: isRu ? "Задание создано без списания токенов." : "A non-billed admin job was created.",
    },
  ];

  if (run.startedAtUtc) {
    items.push({
      label: isRu ? "Генерация запущена" : "Generation started",
      at: formatDateTime(run.startedAtUtc, locale),
      description: isRu ? `Worker взял задание, попытка ${run.attemptCount}.` : `Worker claimed the job, attempt ${run.attemptCount}.`,
    });
  }

  if (run.preprocessingCompletedAtUtc) {
    items.push({
      label: isRu ? "Исходник обработан" : "Source preprocessed",
      at: formatDateTime(run.preprocessingCompletedAtUtc, locale),
      description: isRu ? "Normalized image сохранён и доступен в артефактах." : "Normalized image was saved and is visible in artifacts.",
    });
  }

  if (run.motionGenerationCompletedAtUtc) {
    items.push({
      label: isRu ? "Motion сгенерирован" : "Motion generated",
      at: formatDateTime(run.motionGenerationCompletedAtUtc, locale),
      description: isRu ? "Провайдер вернул промежуточное видео." : "The provider returned an intermediate video.",
    });
  }

  if (run.mediaImportCompletedAtUtc) {
    items.push({
      label: isRu ? "Финальное видео импортировано" : "Final video imported",
      at: formatDateTime(run.mediaImportCompletedAtUtc, locale),
      description: isRu ? "Сгенерированное видео сохранено в media storage." : "Generated video was saved in media storage.",
    });
  }

  if (run.completedAtUtc && run.status === "Completed") {
    items.push({
      label: isRu ? "Тест завершён успешно" : "Test completed",
      at: formatDateTime(run.completedAtUtc, locale),
      description: isRu ? "Все артефакты доступны для проверки." : "All artifacts are available for review.",
    });
  }

  if (run.completedAtUtc && run.status === "Failed") {
    items.push({
      label: isRu ? "Тест завершён с ошибкой" : "Test failed",
      at: formatDateTime(run.completedAtUtc, locale),
      description: run.failureMessage ?? run.failureCode ?? undefined,
    });
  }

  return items;
}
