import { describe, expect, it } from "vitest";

import {
  GAMIFICATION_RESET_REASON_MAX_LENGTH,
  calculateGamificationCompletionRate,
  isValidGamificationUserId,
  validateGamificationResetReason,
} from "@/components/gamification-page.helpers";

describe("isValidGamificationUserId", () => {
  it("accepts trimmed canonical GUID values case-insensitively", () => {
    expect(isValidGamificationUserId("  123e4567-e89b-12d3-a456-426614174000  ")).toBe(true);
    expect(isValidGamificationUserId("123E4567-E89B-12D3-A456-426614174000")).toBe(true);
  });

  it("rejects non-canonical and malformed GUID values", () => {
    expect(isValidGamificationUserId("123e4567e89b12d3a456426614174000")).toBe(false);
    expect(isValidGamificationUserId("{123e4567-e89b-12d3-a456-426614174000}")).toBe(false);
    expect(isValidGamificationUserId("123e4567-e89b-12d3-a456-42661417400z")).toBe(false);
    expect(isValidGamificationUserId("")).toBe(false);
  });
});

describe("calculateGamificationCompletionRate", () => {
  it("returns a rounded integer percentage", () => {
    expect(calculateGamificationCompletionRate(1, 3)).toBe(33);
    expect(calculateGamificationCompletionRate(2, 3)).toBe(67);
    expect(calculateGamificationCompletionRate(1, 2)).toBe(50);
  });

  it("returns zero when there are no valid participants", () => {
    expect(calculateGamificationCompletionRate(5, 0)).toBe(0);
    expect(calculateGamificationCompletionRate(5, -1)).toBe(0);
    expect(calculateGamificationCompletionRate(5, Number.NaN)).toBe(0);
  });

  it("clamps invalid or out-of-range completion values to 0..100", () => {
    expect(calculateGamificationCompletionRate(-1, 10)).toBe(0);
    expect(calculateGamificationCompletionRate(Number.POSITIVE_INFINITY, 10)).toBe(0);
    expect(calculateGamificationCompletionRate(12, 10)).toBe(100);
  });
});

describe("validateGamificationResetReason", () => {
  it("normalizes and accepts a reason from 1 to 500 characters", () => {
    expect(validateGamificationResetReason("  Verified support incident  ")).toEqual({
      normalizedReason: "Verified support incident",
      error: null,
    });

    const boundaryReason = "x".repeat(GAMIFICATION_RESET_REASON_MAX_LENGTH);
    expect(validateGamificationResetReason(`  ${boundaryReason}  `)).toEqual({
      normalizedReason: boundaryReason,
      error: null,
    });
  });

  it("requires a non-whitespace reason", () => {
    expect(validateGamificationResetReason("   ")).toEqual({
      normalizedReason: "",
      error: "required",
    });
  });

  it("rejects a normalized reason longer than 500 characters", () => {
    const longReason = "x".repeat(GAMIFICATION_RESET_REASON_MAX_LENGTH + 1);
    expect(validateGamificationResetReason(longReason)).toEqual({
      normalizedReason: longReason,
      error: "too_long",
    });
  });
});
