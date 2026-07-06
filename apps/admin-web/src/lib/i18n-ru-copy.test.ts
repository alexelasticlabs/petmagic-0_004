import { describe, expect, it } from "vitest";

import { ruDictionary } from "./i18n.ru";

describe("Russian admin dictionary", () => {
  it("does not expose unresolved English UI fragments in common admin copy", () => {
    const unresolvedFragments = [
      "Template events",
      "Audit events",
      "Feedback",
      "Image model",
      "preview",
      "Admin.",
      "Free",
      "production feed",
      "non-production QA mode",
      "editor flow",
      "preview video",
      "reference motion",
      "metadata",
      "motion prompt",
      "MP4 video",
      "Mobile Chat",
      "Mobile Support Assistant",
      "workflow",
      "audit log",
      "image model",
      "preprocessing model",
      "Kling model",
      "motion control",
      "readiness",
      "production.",
    ];
    const dictionaryText = Object.values(ruDictionary).join("\n");

    for (const fragment of unresolvedFragments) {
      expect(dictionaryText).not.toContain(fragment);
    }
  });
});
