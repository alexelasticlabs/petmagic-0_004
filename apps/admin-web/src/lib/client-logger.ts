type ClientLogLevel = "error" | "warn" | "info" | "debug";
type ClientLogContext = Record<string, unknown>;

const isProduction = process.env.NODE_ENV === "production";

function normalizeError(value: unknown): unknown {
  if (!(value instanceof Error)) {
    return value;
  }

  return {
    name: value.name,
    message: value.message,
    stack: isProduction ? undefined : value.stack,
  };
}

function normalizeContext(context?: ClientLogContext): ClientLogContext | undefined {
  if (!context) {
    return undefined;
  }

  const entries = Object.entries(context).map(([key, value]) => [key, normalizeError(value)]);
  return Object.fromEntries(entries);
}

function emit(level: ClientLogLevel, event: string, context?: ClientLogContext): void {
  if (isProduction && (level === "debug" || level === "info")) {
    return;
  }

  const payload = {
    level,
    event,
    timestamp: new Date().toISOString(),
    context: normalizeContext(context),
  };

  if (level === "error") {
    console.error(`[client:${event}]`, payload);
    return;
  }

  if (level === "warn") {
    console.warn(`[client:${event}]`, payload);
    return;
  }

  if (level === "info") {
    console.info(`[client:${event}]`, payload);
    return;
  }

  console.debug(`[client:${event}]`, payload);
}

export const clientLogger = {
  error(event: string, context?: ClientLogContext): void {
    emit("error", event, context);
  },
  warn(event: string, context?: ClientLogContext): void {
    emit("warn", event, context);
  },
  info(event: string, context?: ClientLogContext): void {
    emit("info", event, context);
  },
  debug(event: string, context?: ClientLogContext): void {
    emit("debug", event, context);
  },
};
