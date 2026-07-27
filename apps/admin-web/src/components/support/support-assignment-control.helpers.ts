export const SUPPORT_UNASSIGNED_OPERATOR_VALUE = "__unassigned__";

type SupportAssignmentAccess = {
  assignedAdminId?: string | null;
  canManageSupportWorkspace: boolean;
  isAdmin: boolean;
  isModerator: boolean;
  sessionUserId: string | null;
  version: unknown;
};

type SupportAssignmentSubmission = SupportAssignmentAccess & {
  isPending: boolean;
  reason: string;
  selectedOperatorId: string;
};

export function hasSupportAssignmentVersion(version: unknown): version is number {
  return typeof version === "number" && Number.isSafeInteger(version) && version >= 0;
}

export function canOpenSupportAssignmentEditor({
  assignedAdminId,
  canManageSupportWorkspace,
  isAdmin,
  isModerator,
  sessionUserId,
  version,
}: SupportAssignmentAccess) {
  if (
    !canManageSupportWorkspace ||
    !sessionUserId ||
    (!isAdmin && !isModerator) ||
    !hasSupportAssignmentVersion(version)
  ) {
    return false;
  }

  if (!assignedAdminId) {
    return true;
  }

  return isAdmin || (isModerator && assignedAdminId === sessionUserId);
}

export function canSubmitSupportAssignment({
  assignedAdminId,
  canManageSupportWorkspace,
  isAdmin,
  isModerator,
  isPending,
  reason,
  selectedOperatorId,
  sessionUserId,
  version,
}: SupportAssignmentSubmission) {
  if (
    isPending ||
    reason.trim().length < 3 ||
    reason.trim().length > 500 ||
    !canOpenSupportAssignmentEditor({
      assignedAdminId,
      canManageSupportWorkspace,
      isAdmin,
      isModerator,
      sessionUserId,
      version,
    })
  ) {
    return false;
  }

  const currentOperatorId = assignedAdminId ?? SUPPORT_UNASSIGNED_OPERATOR_VALUE;
  if (!selectedOperatorId || selectedOperatorId === currentOperatorId) {
    return false;
  }

  if (isAdmin) {
    return true;
  }

  if (!isModerator || !sessionUserId) {
    return false;
  }

  if (!assignedAdminId) {
    return selectedOperatorId === sessionUserId;
  }

  return (
    assignedAdminId === sessionUserId && selectedOperatorId === SUPPORT_UNASSIGNED_OPERATOR_VALUE
  );
}
