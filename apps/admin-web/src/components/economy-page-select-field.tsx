import styles from "@/components/economy-page.module.css";
import { Select, type SelectOption } from "@/components/ui/select";

type EconomySelectFieldProps = {
  label: string;
  value: string;
  options: readonly SelectOption[];
  onChange: (value: string) => void;
  disabled?: boolean;
  className?: string;
};

export function EconomySelectField({
  label,
  value,
  options,
  onChange,
  disabled = false,
  className,
}: EconomySelectFieldProps) {
  const classNames = [styles.filterField, className].filter(Boolean).join(" ");

  return (
    <div className={classNames}>
      <span>{label}</span>
      <Select
        value={value}
        options={options}
        onChange={onChange}
        ariaLabel={label}
        showSelectedDescription={false}
        disabled={disabled}
      />
    </div>
  );
}
