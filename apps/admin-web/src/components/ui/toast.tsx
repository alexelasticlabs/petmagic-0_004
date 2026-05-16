type ToastType = "success" | "error";

type ToastProps = {
  message: string;
  type: ToastType;
};

export function Toast({ message, type }: ToastProps) {
  return (
    <div className={`ui-toast ui-toast--${type}`} role="status" aria-live="polite">
      {message}
    </div>
  );
}
