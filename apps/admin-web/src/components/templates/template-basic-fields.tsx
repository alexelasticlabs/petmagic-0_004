import styles from "@/components/templates/template-editor.module.css";
import {
  TEMPLATE_TOKEN_COST_MAX_LENGTH,
  normalizeTemplateIntegerInput,
} from "@/components/templates/template-form-mappers";
import type { SetTemplateFormState, TemplateFormState } from "@/components/templates/types";
import { Select, type SelectOption } from "@/components/ui/select";
import type { Dictionary } from "@/lib/i18n";
import { joinClassNames } from "@/lib/join-class-names";

type TemplateBasicFieldsProps = {
  text: Dictionary;
  form: TemplateFormState;
  setForm: SetTemplateFormState;
  categorySuggestions?: string[];
  showMusicDescription?: boolean;
};

const TITLE_LIMIT = 60;
const SHORT_DESCRIPTION_LIMIT = 120;
const PET_PHOTO_REQUIREMENTS_LIMIT = 1000;

export function TemplateBasicFields({
  text,
  form,
  setForm,
  categorySuggestions = [],
  showMusicDescription = false,
}: TemplateBasicFieldsProps) {
  const categoryValues = Array.from(
    new Set([...categorySuggestions, form.category].map((value) => value.trim()).filter(Boolean))
  );
  const categoryOptions: SelectOption[] = [
    {
      value: "",
      label: text.editorMissing,
      description: text.categoryLabel,
      tone: "neutral",
    },
    ...categoryValues.map((category) => ({
      value: category,
      label: category,
      description: text.categoryLabel,
      tone: "neutral" as const,
    })),
  ];
  const promoBadgeOptions: SelectOption[] = [
    {
      value: "Auto",
      label: text.promoBadgeAutoLabel,
      description: text.promoBadgeAutoHint,
      badge: "Auto",
      tone: "neutral",
    },
    {
      value: "New",
      label: "NEW",
      description: text.promoBadgeNewHint,
      badge: "Fresh",
      tone: "recommended",
    },
    {
      value: "Trending",
      label: "TRENDING",
      description: text.promoBadgeTrendingHint,
      badge: "Hot",
      tone: "premium",
    },
    {
      value: "Popular",
      label: "POPULAR",
      description: text.promoBadgePopularHint,
      badge: "Core",
      tone: "fast",
    },
    {
      value: "Funny",
      label: "FUNNY",
      description: text.promoBadgeFunnyHint,
      badge: "Mood",
      tone: "recommended",
    },
  ];

  return (
    <div className={styles.formGrid}>
      <label className={styles.fieldBlock}>
        <span className={styles.fieldHeader}>
          <span>{text.titleLabel}</span>
          <span className={styles.fieldCounter}>
            {form.title.length}/{TITLE_LIMIT}
          </span>
        </span>
        <input
          value={form.title}
          maxLength={TITLE_LIMIT}
          onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))}
          required
        />
      </label>

      <label className={styles.fieldBlock}>
        <span className={styles.fieldHeader}>
          <span>{text.shortDescriptionLabel}</span>
          <span className={styles.fieldCounter}>
            {form.shortDescription.length}/{SHORT_DESCRIPTION_LIMIT}
          </span>
        </span>
        <textarea
          value={form.shortDescription}
          maxLength={SHORT_DESCRIPTION_LIMIT}
          onChange={(event) =>
            setForm((current) => ({ ...current, shortDescription: event.target.value }))
          }
          rows={3}
          required
        />
      </label>

      <label className={styles.fieldBlock}>
        <span className={styles.fieldHeader}>
          <span>{text.petPhotoRequirementsLabel}</span>
          <span className={styles.fieldCounter}>
            {form.petPhotoRequirements.length}/{PET_PHOTO_REQUIREMENTS_LIMIT}
          </span>
        </span>
        <textarea
          value={form.petPhotoRequirements}
          maxLength={PET_PHOTO_REQUIREMENTS_LIMIT}
          onChange={(event) =>
            setForm((current) => ({ ...current, petPhotoRequirements: event.target.value }))
          }
          rows={4}
          placeholder={text.petPhotoRequirementsHint}
        />
      </label>

      <div className={styles.split}>
        <label className={styles.fieldBlock}>
          <span className={styles.fieldHeader}>
            <span>{text.categoryLabel}</span>
          </span>
          <Select
            value={form.category}
            options={categoryOptions}
            ariaLabel={text.categoryLabel}
            onChange={(value) => setForm((current) => ({ ...current, category: value }))}
          />
        </label>

        <label className={styles.fieldBlock}>
          <span className={styles.fieldHeader}>
            <span>{text.tagsLabel}</span>
          </span>
          <input
            value={form.tags}
            onChange={(event) => setForm((current) => ({ ...current, tags: event.target.value }))}
          />
        </label>
      </div>

      <label className={styles.fieldBlock}>
        <span className={styles.fieldHeader}>
          <span>{text.promoBadgeLabel}</span>
        </span>
        <Select
          value={form.promoBadgeMode}
          options={promoBadgeOptions}
          ariaLabel={text.promoBadgeLabel}
          onChange={(value) => setForm((current) => ({ ...current, promoBadgeMode: value }))}
        />
      </label>

      <div className={styles.accessGroup}>
        <span className={styles.accessLabel}>{text.accessLabel}</span>
        <div className={styles.accessOptions}>
          <button
            type="button"
            className={joinClassNames(
              styles.accessOption,
              styles.accessOptionFree,
              !form.isPremium ? styles.accessOptionActive : null,
              !form.isPremium ? styles.accessOptionActiveFree : null
            )}
            onClick={() => setForm((current) => ({ ...current, isPremium: false }))}
          >
            <span className={styles.accessOptionTitle}>{text.freeLabel}</span>
            <span className={styles.accessOptionHint}>{text.editorAccessFreeHint}</span>
          </button>

          <button
            type="button"
            className={joinClassNames(
              styles.accessOption,
              styles.accessOptionPremium,
              form.isPremium ? styles.accessOptionActive : null,
              form.isPremium ? styles.accessOptionActivePremium : null
            )}
            onClick={() => setForm((current) => ({ ...current, isPremium: true }))}
          >
            <span className={styles.accessOptionTitle}>{text.premiumLabel}</span>
            <span className={styles.accessOptionHint}>{text.editorAccessPremiumHint}</span>
          </button>
        </div>
      </div>

      <div className={styles.split}>
        <label className={styles.fieldBlock}>
          <span className={styles.fieldHeader}>
            <span>{text.tokenCostLabel}</span>
          </span>
          <input
            value={form.tokenCost}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                tokenCost: normalizeTemplateIntegerInput(event.target.value),
              }))
            }
            onBlur={(event) =>
              setForm((current) => ({
                ...current,
                tokenCost: normalizeTemplateIntegerInput(event.target.value),
              }))
            }
            inputMode="numeric"
            pattern="[0-9]*"
            maxLength={TEMPLATE_TOKEN_COST_MAX_LENGTH}
            min="1"
            step="1"
            required
          />
        </label>

        {showMusicDescription ? (
          <label className={styles.fieldBlock}>
            <span className={styles.fieldHeader}>
              <span>{text.musicDescriptionLabel}</span>
            </span>
            <input
              value={form.musicDescription}
              onChange={(event) =>
                setForm((current) => ({ ...current, musicDescription: event.target.value }))
              }
            />
          </label>
        ) : null}
      </div>
    </div>
  );
}
