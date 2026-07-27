import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  canOpenSupportAssignmentEditor,
  canSubmitSupportAssignment,
  SUPPORT_UNASSIGNED_OPERATOR_VALUE,
} from "@/components/support/support-assignment-control.helpers";

const adminUserId = "11111111-1111-1111-1111-111111111111";
const moderatorUserId = "22222222-2222-2222-2222-222222222222";
const otherOperatorId = "33333333-3333-3333-3333-333333333333";

describe("support assignment authorization", () => {
  it("opens an unassigned ticket editor for Admin and Moderator with a current version", () => {
    const common = {
      assignedAdminId: null,
      canManageSupportWorkspace: true,
      sessionUserId: adminUserId,
      version: 7,
    };

    expect(canOpenSupportAssignmentEditor({ ...common, isAdmin: true, isModerator: false })).toBe(
      true
    );
    expect(canOpenSupportAssignmentEditor({ ...common, isAdmin: false, isModerator: true })).toBe(
      true
    );
  });

  it("allows Moderator to edit only an unassigned or self-owned ticket", () => {
    const common = {
      canManageSupportWorkspace: true,
      isAdmin: false,
      isModerator: true,
      sessionUserId: moderatorUserId,
      version: 3,
    };

    expect(canOpenSupportAssignmentEditor({ ...common, assignedAdminId: null })).toBe(true);
    expect(canOpenSupportAssignmentEditor({ ...common, assignedAdminId: moderatorUserId })).toBe(
      true
    );
    expect(canOpenSupportAssignmentEditor({ ...common, assignedAdminId: otherOperatorId })).toBe(
      false
    );
  });

  it.each([undefined, null, Number.NaN, -1, 1.5])(
    "requires a usable conversation version before opening the editor (%s)",
    (version) => {
      expect(
        canOpenSupportAssignmentEditor({
          assignedAdminId: null,
          canManageSupportWorkspace: true,
          isAdmin: true,
          isModerator: false,
          sessionUserId: adminUserId,
          version,
        })
      ).toBe(false);
    }
  );

  it("requires a three-character reason and blocks Moderator handoff to another operator", () => {
    const common = {
      assignedAdminId: null,
      canManageSupportWorkspace: true,
      isAdmin: false,
      isModerator: true,
      isPending: false,
      selectedOperatorId: moderatorUserId,
      sessionUserId: moderatorUserId,
      version: 4,
    };

    expect(canSubmitSupportAssignment({ ...common, reason: "ok" })).toBe(false);
    expect(canSubmitSupportAssignment({ ...common, reason: "claim for triage" })).toBe(true);
    expect(
      canSubmitSupportAssignment({
        ...common,
        reason: "handoff",
        selectedOperatorId: otherOperatorId,
      })
    ).toBe(false);
  });

  it("allows Moderator to unassign only a self-owned ticket", () => {
    const common = {
      canManageSupportWorkspace: true,
      isAdmin: false,
      isModerator: true,
      isPending: false,
      reason: "return to queue",
      selectedOperatorId: SUPPORT_UNASSIGNED_OPERATOR_VALUE,
      sessionUserId: moderatorUserId,
      version: 5,
    };

    expect(canSubmitSupportAssignment({ ...common, assignedAdminId: moderatorUserId })).toBe(true);
    expect(canSubmitSupportAssignment({ ...common, assignedAdminId: otherOperatorId })).toBe(false);
    expect(canSubmitSupportAssignment({ ...common, assignedAdminId: null })).toBe(false);
  });
});

describe("support assignment UI contract", () => {
  const control = readFileSync(
    fileURLToPath(new URL("./support-assignment-control.tsx", import.meta.url)),
    "utf8"
  );
  const controller = readFileSync(
    fileURLToPath(new URL("./use-support-conversation-controller.ts", import.meta.url)),
    "utf8"
  );
  const controllerMutations = readFileSync(
    fileURLToPath(new URL("./support-conversation-controller.mutations.ts", import.meta.url)),
    "utf8"
  );
  const infoPanel = readFileSync(
    fileURLToPath(new URL("./support-info-panel.tsx", import.meta.url)),
    "utf8"
  );
  const infoPanelUserTab = readFileSync(
    fileURLToPath(new URL("./support-info-panel-user-tab.tsx", import.meta.url)),
    "utf8"
  );
  const apiClient = readFileSync(
    fileURLToPath(new URL("../../lib/api-client.support.ts", import.meta.url)),
    "utf8"
  );

  it("routes claim through the versioned assignment editor", () => {
    expect(control).toContain("setSelectedOperatorId(sessionUserId)");
    expect(control).toContain("expectedVersion: conversation.version");
    expect(control).toContain("reason: reason.trim()");
    expect(control).not.toContain("onClaim");
    expect(control).not.toContain("claimPending");
    expect(infoPanelUserTab).toContain("key={conversation.conversationId}");
  });

  it("removes the legacy controller mutation and endpoint clients", () => {
    expect(controller).not.toContain("assignmentMutation");
    expect(controllerMutations).not.toContain("assignmentMutation");
    expect(controllerMutations).not.toContain("assignSupportConversationToMe");
    expect(controllerMutations).not.toContain("unassignSupportConversation");
    expect(infoPanel).not.toContain("assignmentMutation");
    expect(infoPanelUserTab).not.toContain("assignmentMutation");
    expect(apiClient).not.toContain("/assign-to-me");
    expect(apiClient).not.toContain("/unassign");
  });
});
