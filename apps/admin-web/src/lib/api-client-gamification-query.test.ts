import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  fetchAdminGamificationAchievements,
  fetchAdminGamificationChallenges,
  fetchAdminGamificationDashboardMetrics,
  fetchAdminUserGamificationOverview,
  resetAdminUserGamificationStreak,
} from "@/lib/api-client.gamification";

describe("api-client.gamification", () => {
  const originalPublicApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
  const originalInternalApiBaseUrl = process.env.INTERNAL_API_BASE_URL;

  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    process.env.INTERNAL_API_BASE_URL = "https://api.example.com";
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    process.env.NEXT_PUBLIC_API_BASE_URL = originalPublicApiBaseUrl;
    process.env.INTERNAL_API_BASE_URL = originalInternalApiBaseUrl;
  });

  it("uses the AdminOnly read contracts and propagates AbortSignal", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);

      if (url.endsWith("/dashboard/metrics")) {
        return Response.json({
          totalUsersWithProgress: 12,
          totalPetsTracked: 18,
          totalAchievementDefinitions: 7,
          totalAchievementsUnlocked: 32,
          usersWithActiveStreak: 9,
          currentWeekChallenges: 3,
          currentWeekChallengeParticipants: 11,
          currentWeekChallengeCompletions: 5,
          generatedAtUtc: "2026-07-25T00:00:00Z",
        });
      }

      if (url.endsWith("/achievements")) {
        return Response.json([]);
      }

      return Response.json([]);
    });
    const controller = new AbortController();
    vi.stubGlobal("fetch", fetchMock);

    const metrics = await fetchAdminGamificationDashboardMetrics(controller.signal);
    await fetchAdminGamificationAchievements(controller.signal);
    await fetchAdminGamificationChallenges(controller.signal);

    expect(metrics.totalUsersWithProgress).toBe(12);
    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/gamification/dashboard/metrics",
      "https://api.example.com/api/admin/gamification/achievements",
      "https://api.example.com/api/admin/gamification/challenges/current",
    ]);
    const requestSignals = fetchMock.mock.calls.map(([, init]) => init?.signal);
    for (const [, init] of fetchMock.mock.calls) {
      expect(init?.method).toBe("GET");
      expect(init?.signal).toBeInstanceOf(AbortSignal);
      expect(init?.body).toBeUndefined();
    }

    for (const signal of requestSignals) {
      expect(signal?.aborted).toBe(false);
    }

    const abortFetchMock = vi.fn<typeof fetch>(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener(
            "abort",
            () => reject(new DOMException("Aborted", "AbortError")),
            { once: true }
          );
        })
    );
    const abortController = new AbortController();
    vi.stubGlobal("fetch", abortFetchMock);

    const pendingRequest = fetchAdminGamificationDashboardMetrics(abortController.signal);
    abortController.abort();

    await expect(pendingRequest).rejects.toMatchObject({ name: "AbortError" });
    expect(abortFetchMock.mock.calls[0]?.[1]?.signal?.aborted).toBe(true);
  });

  it("encodes user ids before placing them in Gamification paths", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        userId: "user/one two",
        streak: null,
        pets: [],
        achievements: [],
        currentChallenges: [],
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminUserGamificationOverview("user/one two?x");

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/gamification/users/user%2Fone%20two%3Fx"
    );
    expect(fetchMock.mock.calls[0]?.[1]?.method).toBe("GET");
  });

  it("sends a trimmed audited reason to the destructive streak reset contract", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => new Response(null, { status: 204 }));
    vi.stubGlobal("fetch", fetchMock);

    await resetAdminUserGamificationStreak(
      "123e4567-e89b-12d3-a456-426614174000",
      "  Verified support incident  "
    );

    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(url)).toBe(
      "https://api.example.com/api/admin/gamification/users/123e4567-e89b-12d3-a456-426614174000/streak/reset"
    );
    expect(init?.method).toBe("POST");
    expect(JSON.parse(String(init?.body))).toEqual({
      reason: "Verified support incident",
    });
  });
});
