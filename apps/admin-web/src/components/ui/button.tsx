import { forwardRef, type ButtonHTMLAttributes } from "react";

type ButtonVariant = "primary" | "secondary" | "ghost" | "danger";
type ButtonSize = "sm" | "md";

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
};

const variantClassMap: Record<ButtonVariant, string> = {
  primary: "ui-button ui-button--primary",
  secondary: "ui-button ui-button--secondary",
  ghost: "ui-button ui-button--ghost",
  danger: "ui-button ui-button--danger",
};

const sizeClassMap: Record<ButtonSize, string> = {
  sm: "ui-button--sm",
  md: "ui-button--md",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = "secondary", size = "md", className, type = "button", ...rest },
  ref
) {
  const classes = [variantClassMap[variant], sizeClassMap[size], className]
    .filter(Boolean)
    .join(" ");

  return <button ref={ref} type={type} className={classes} {...rest} />;
});
