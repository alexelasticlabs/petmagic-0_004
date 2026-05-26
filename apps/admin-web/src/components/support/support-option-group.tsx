import styles from "@/components/support/support-page.module.css";

type SupportOption = {
  value: string;
  label: string;
};

type SupportOptionGroupProps = {
  label?: string;
  value: string;
  options: readonly SupportOption[];
  onChange: (value: string) => void;
  compact?: boolean;
  className?: string;
};

function joinClassNames(...classes: Array<string | null | undefined | false>) {
  return classes.filter(Boolean).join(" ");
}

export function SupportOptionGroup({
  label,
  value,
  options,
  onChange,
  compact = false,
  className,
}: SupportOptionGroupProps) {
  return (
    <div
      className={joinClassNames(
        styles.optionGroup,
        compact ? styles.optionGroupCompact : "",
        className
      )}
    >
      {label ? <span className={styles.optionGroupLabel}>{label}</span> : null}
      <div className={styles.optionGroupRail}>
        {options.map((option) => (
          <button
            key={option.value}
            type="button"
            className={joinClassNames(
              styles.optionChip,
              value === option.value ? styles.optionChipActive : ""
            )}
            onClick={() => {
              if (option.value !== value) {
                onChange(option.value);
              }
            }}
            aria-pressed={value === option.value}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}
