import { afterEach, describe, expect, it, vi } from "vitest";

import { fetchWithTimeout } from "@/lib/fetch-with-timeout";

describe("fetchWithTimeout", () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it("aborts stalled requests after the configured timeout", async () => {
    vi.useFakeTimers();
    const fetchMock = vi.fn(
      (_input: RequestInfo | URL, init?: RequestInit) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => reject(init.signal?.reason), {
            once: true,
          });
        })
    );
    vi.stubGlobal("fetch", fetchMock);

    const request = fetchWithTimeout("/secure-media", { credentials: "include" }, 50);
    const assertion = expect(request).rejects.toMatchObject({ name: "TimeoutError" });

    await vi.advanceTimersByTimeAsync(50);

    await assertion;
    expect(fetchMock).toHaveBeenCalledWith(
      "/secure-media",
      expect.objectContaining({
        credentials: "include",
        signal: expect.any(AbortSignal),
      })
    );
  });

  it("preserves upstream aborts without waiting for timeout", async () => {
    vi.useFakeTimers();
    const upstreamController = new AbortController();
    const fetchMock = vi.fn(
      (_input: RequestInfo | URL, init?: RequestInit) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => reject(init.signal?.reason), {
            once: true,
          });
        })
    );
    vi.stubGlobal("fetch", fetchMock);

    const request = fetchWithTimeout(
      "/secure-media",
      { credentials: "include", signal: upstreamController.signal },
      5_000
    );

    upstreamController.abort(new DOMException("User navigation.", "AbortError"));

    await expect(request).rejects.toMatchObject({ name: "AbortError" });
  });

  it("adds a correlation id header to direct timed fetches", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => new Response("ok"));
    vi.stubGlobal("fetch", fetchMock);

    await fetchWithTimeout("/secure-media", { credentials: "include" }, 5_000);

    const [, init] = fetchMock.mock.calls[0] ?? [];
    const headers = init?.headers as Headers;
    expect(headers.get("X-Correlation-ID")).toBeTruthy();
  });

  it("preserves caller-provided correlation ids", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => new Response("ok"));
    vi.stubGlobal("fetch", fetchMock);

    await fetchWithTimeout(
      "/secure-media",
      {
        credentials: "include",
        headers: {
          "X-Correlation-ID": "caller-correlation-id",
        },
      },
      5_000
    );

    const [, init] = fetchMock.mock.calls[0] ?? [];
    const headers = init?.headers as Headers;
    expect(headers.get("X-Correlation-ID")).toBe("caller-correlation-id");
  });
});
