import { createAdminCorrelationId } from "@/lib/admin-correlation-id";

const DEFAULT_FETCH_TIMEOUT_MS = 15_000;

export async function fetchWithTimeout(
  input: RequestInfo | URL,
  init: RequestInit = {},
  timeoutMs = DEFAULT_FETCH_TIMEOUT_MS
): Promise<Response> {
  const controller = new AbortController();
  const upstreamSignal = init.signal;
  const headers = new Headers(init.headers);
  const abortFromUpstream = () => controller.abort(upstreamSignal?.reason);
  const timeoutId = globalThis.setTimeout(() => {
    controller.abort(new DOMException("Request timed out.", "TimeoutError"));
  }, timeoutMs);

  if (upstreamSignal?.aborted) {
    abortFromUpstream();
  } else {
    upstreamSignal?.addEventListener("abort", abortFromUpstream, { once: true });
  }

  if (!headers.has("X-Correlation-ID")) {
    headers.set("X-Correlation-ID", createAdminCorrelationId());
  }

  try {
    return await fetch(input, { ...init, headers, signal: controller.signal });
  } finally {
    globalThis.clearTimeout(timeoutId);
    upstreamSignal?.removeEventListener("abort", abortFromUpstream);
  }
}
