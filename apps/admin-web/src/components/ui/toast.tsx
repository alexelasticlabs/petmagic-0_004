type ToastType = "success" | "error";

type ToastProps = {
  message: string;
  type: ToastType;
};

export function Toast({ message, type }: ToastProps) {
  const isError = type === "error";

  return (
    <div
      className={`ui-toast ui-toast--${type}`}
      role={isError ? "alert" : "status"}
      aria-live={isError ? "assertive" : "polite"}
      aria-atomic="true"
      aria-relevant="additions text"
    >
      {message}
    </div>
  );
}
