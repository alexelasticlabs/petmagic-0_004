import styles from "@/components/templates/template-editor.module.css";
import {
  TEMPLATE_MUSIC_DESCRIPTION_MAX_LENGTH,
  TEMPLATE_REQUIREMENT_MAX_LENGTH,
  TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH,
  TEMPLATE_TAG_MAX_COUNT,
  TEMPLATE_TAG_MAX_LENGTH,
  TEMPLATE_TITLE_MAX_LENGTH,
  TEMPLATE_TOKEN_COST_MAX_LENGTH,
  normalizeTemplateIntegerInput,
  normalizeTemplateTextInput,
} from "@/components/templates/template-form-mappers";
import type { SetTemplateFormState, TemplateFormState } from "@/components/templates/types";
import { Select, type SelectOption } from "@/components/ui/select";
import type { Dictionary } from "@/lib/i18n";
import { joinClassNames } from "@/lib/join-class-names";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplateBasicFieldsProps = {
  text: Dictionary;
  form: TemplateFormState;
  setForm: SetTemplateFormState;
  categorySuggestions?: string[];
  requireCompleteDetails?: boolean;
  showMusicDescription?: boolean;
};

const PET_PHOTO_REQUIREMENTS_INPUT_MAX_LENGTH = TEMPLATE_REQUIREMENT_MAX_LENGTH * 6;
const TAGS_INPUT_MAX_LENGTH = TEMPLATE_TAG_MAX_LENGTH * TEMPLATE_TAG_MAX_COUNT;
const TEMPLATE_CATEGORY_SELECT_LABEL_MAX_LENGTH = 80;

export function TemplateBasicFields({
  text,
  form,
  setForm,
  categorySuggestions = [],
  requireCompleteDetails = false,
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
      label: sanitizeSensitiveText(category, TEMPLATE_CATEGORY_SELECT_LABEL_MAX_LENGTH),
      description: text.categoryLabel,
      tone: "neutral" as const,
    })),
  ];
  const promoBadgeOptions: SelectOption[] = [
    {
      value: "Auto",
      label: text.promoBadgeAutoLabel,
      description: text.promoBadgeAutoHint,
      badge: text.promoBadgeAutoBadge,
      tone: "neutral",
    },
    {
      value: "New",
      label: text.promoBadgeNewLabel,
      description: text.promoBadgeNewHint,
      badge: text.promoBadgeNewBadge,
      tone: "recommended",
    },
    {
      value: "Trending",
      label: text.promoBadgeTrendingLabel,
      description: text.promoBadgeTrendingHint,
      badge: text.promoBadgeTrendingBadge,
      tone: "premium",
    },
    {
      value: "Popular",
      label: text.promoBadgePopularLabel,
      description: text.promoBadgePopularHint,
      badge: text.promoBadgePopularBadge,
      tone: "fast",
    },
    {
      value: "Funny",
      label: text.promoBadgeFunnyLabel,
      description: text.promoBadgeFunnyHint,
      badge: text.promoBadgeFunnyBadge,
      tone: "recommended",
    },
  ];
  const inputMediaTypeOptions: SelectOption[] = [
    {
      value: "Image",
      label: text.editorInputMediaTypeImageLabel,
      description: text.editorInputMediaTypeImageHint,
      tone: "recommended",
    },
    {
      value: "Video",
      label: text.editorInputMediaTypeVideoLabel,
      description: text.editorInputMediaTypeVideoHint,
      tone: "neutral",
    },
  ];

  return (
    <div className={styles.formGrid}>
      <label className={styles.fieldBlock}>
        <span className={styles.fieldHeader}>
          <span>{text.titleLabel}</span>
          <span className={styles.fieldCounter}>
            {form.title.length}/{TEMPLATE_TITLE_MAX_LENGTH}
          </span>
        </span>
        <input
          value={form.title}
          maxLength={TEMPLATE_TITLE_MAX_LENGTH}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              title: normalizeTemplateTextInput(event.target.value, TEMPLATE_TITLE_MAX_LENGTH),
            }))
          }
          required
        />
      </label>

      <label className={styles.fieldBlock}>
        <span className={styles.fieldHeader}>
          <span>{text.shortDescriptionLabel}</span>
          <span className={styles.fieldCounter}>
            {form.shortDescription.length}/{TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH}
          </span>
        </span>
        <textarea
          value={form.shortDescription}
          maxLength={TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              shortDescription: normalizeTemplateTextInput(
                event.target.value,
                TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH
              ),
            }))
          }
          rows={3}
          required={requireCompleteDetails}
        />
      </label>

      <label className={styles.fieldBlock}>
        <span className={styles.fieldHeader}>
          <span>{text.petPhotoRequirementsLabel}</span>
          <span className={styles.fieldCounter}>
            {form.petPhotoRequirements.length}/{PET_PHOTO_REQUIREMENTS_INPUT_MAX_LENGTH}
          </span>
        </span>
        <textarea
          value={form.petPhotoRequirements}
          maxLength={PET_PHOTO_REQUIREMENTS_INPUT_MAX_LENGTH}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              petPhotoRequirements: normalizeTemplateTextInput(
                event.target.value,
                PET_PHOTO_REQUIREMENTS_INPUT_MAX_LENGTH
              ),
            }))
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
            maxLength={TAGS_INPUT_MAX_LENGTH}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                tags: normalizeTemplateTextInput(event.target.value, TAGS_INPUT_MAX_LENGTH),
              }))
            }
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

      <div className={styles.accessGroup} role="group" aria-label={text.accessLabel}>
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
            aria-pressed={!form.isPremium}
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
            aria-pressed={form.isPremium}
            onClick={() => setForm((current) => ({ ...current, isPremium: true }))}
          >
            <span className={styles.accessOptionTitle}>{text.premiumLabel}</span>
            <span className={styles.accessOptionHint}>{text.editorAccessPremiumHint}</span>
          </button>
        </div>
      </div>

      <div className={styles.accessGroup} role="group" aria-label={text.qaOnlyLabel}>
        <span className={styles.accessLabel}>{text.qaOnlyLabel}</span>
        <div className={styles.accessOptions}>
          <button
            type="button"
            className={joinClassNames(
              styles.accessOption,
              form.isQaOnly ? styles.accessOptionActive : null
            )}
            aria-pressed={form.isQaOnly}
            onClick={() => setForm((current) => ({ ...current, isQaOnly: !current.isQaOnly }))}
          >
            <span className={styles.accessOptionTitle}>
              {form.isQaOnly ? text.qaOnlyLabel : text.editorVisibleToUsersHint}
            </span>
            <span className={styles.accessOptionHint}>{text.editorQaOnlyHint}</span>
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
            required={requireCompleteDetails}
          />
        </label>

        {showMusicDescription ? (
          <label className={styles.fieldBlock}>
            <span className={styles.fieldHeader}>
              <span>{text.musicDescriptionLabel}</span>
            </span>
            <input
              value={form.musicDescription}
              maxLength={TEMPLATE_MUSIC_DESCRIPTION_MAX_LENGTH}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  musicDescription: normalizeTemplateTextInput(
                    event.target.value,
                    TEMPLATE_MUSIC_DESCRIPTION_MAX_LENGTH
                  ),
                }))
              }
            />
          </label>
        ) : null}
      </div>

      <div
        className={styles.accessGroup}
        role="group"
        aria-label={text.editorGenerationResultInputTitle}
      >
        <span className={styles.accessLabel}>{text.editorGenerationResultInputTitle}</span>
        <div className={styles.accessOptions}>
          <button
            type="button"
            className={joinClassNames(
              styles.accessOption,
              form.supportsGenerationResultInput ? styles.accessOptionActive : null
            )}
            aria-pressed={form.supportsGenerationResultInput}
            onClick={() =>
              setForm((current) => ({
                ...current,
                supportsGenerationResultInput: !current.supportsGenerationResultInput,
              }))
            }
          >
            <span className={styles.accessOptionTitle}>
              {form.supportsGenerationResultInput
                ? text.editorGenerationResultSupported
                : text.editorGenerationResultUnsupported}
            </span>
            <span className={styles.accessOptionHint}>{text.editorGenerationResultInputHint}</span>
          </button>
        </div>
      </div>

      <label className={styles.fieldBlock}>
        <span className={styles.fieldHeader}>
          <span>{text.editorRequiredInputMediaTypeLabel}</span>
        </span>
        <Select
          value={form.requiredInputMediaType}
          options={inputMediaTypeOptions}
          ariaLabel={text.editorRequiredInputMediaTypeLabel}
          onChange={(value) =>
            setForm((current) => ({
              ...current,
              requiredInputMediaType: value === "Video" ? "Video" : "Image",
            }))
          }
        />
      </label>
    </div>
  );
}
