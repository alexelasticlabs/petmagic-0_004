import { useMutation, type QueryClient } from "@tanstack/react-query";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type Dispatch,
  type SetStateAction,
} from "react";

import {
  type SendOptimisticContext,
  type ToastState,
} from "@/components/support/support-conversation-controller.helpers";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  assignSupportConversationToMe,
  sendSupportAttachment,
  sendSupportMessage,
  unassignSupportConversation,
  updateSupportConversationMetadata,
  updateSupportConversationStatus,
  type AdminSupportConversation,
  type SupportConversationPriority,
  type SupportConversationStatus,
} from "@/lib/api-client";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type SupportControllerSessionIdentity = {
  userId?: string | null;
  displayName?: string | null;
  email?: string | null;
};

type UseSupportConversationMutationsParams = {
  conversationId: string;
  canMutateConversation: boolean;
  supportActionsForbidden: string;
  supportOwnershipRequired: string;
  assertCanManageSupportWorkspace: () => boolean;
  reply: string;
  selectedAttachment: File | null;
  replyToMessageId: string | null;
  replyToPreview: string | null;
  sessionUser: SupportControllerSessionIdentity | null | undefined;
  queryClient: QueryClient;
  optimisticAttachmentPreview: (fileName?: string | null) => string;
  operatorLabel: string;
  supportReplySent: string;
  supportStatusSaved: string;
  supportAssignmentSaved: string;
  pushSupportNotification: (type: ToastState["type"], message: string) => void;
  pushSupportError: (error: unknown, action?: string) => void;
  setToast: Dispatch<SetStateAction<ToastState | null>>;
  resetSelectedAttachment: () => void;
  refreshConversationData: () => Promise<void>;
  setReply: Dispatch<SetStateAction<string>>;
  setReplyToMessageId: Dispatch<SetStateAction<string | null>>;
  setReplyToPreview: Dispatch<SetStateAction<string | null>>;
};

export function useSupportConversationMutations({
  conversationId,
  canMutateConversation,
  supportActionsForbidden,
  supportOwnershipRequired,
  assertCanManageSupportWorkspace,
  reply,
  selectedAttachment,
  replyToMessageId,
  replyToPreview,
  sessionUser,
  queryClient,
  optimisticAttachmentPreview,
  operatorLabel,
  supportReplySent,
  supportStatusSaved,
  supportAssignmentSaved,
  pushSupportNotification,
  pushSupportError,
  setToast,
  resetSelectedAttachment,
  refreshConversationData,
  setReply,
  setReplyToMessageId,
  setReplyToPreview,
}: UseSupportConversationMutationsParams) {
  const [isSendReplyInFlight, setIsSendReplyInFlight] = useState(false);
  const sendReplyInFlightRef = useRef(false);
  const optimisticAttachmentObjectUrlsRef = useRef(new Map<string, string>());
  const optimisticMessageCounterRef = useRef(0);

  useEffect(
    () => () => {
      for (const url of optimisticAttachmentObjectUrlsRef.current.values()) {
        URL.revokeObjectURL(url);
      }
      optimisticAttachmentObjectUrlsRef.current.clear();
    },
    []
  );

  const sendMutation = useMutation({
    mutationFn: async () => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }
      if (!canMutateConversation) {
        throw new Error(supportOwnershipRequired);
      }

      return selectedAttachment
        ? sendSupportAttachment(conversationId, selectedAttachment, reply.trim(), replyToMessageId)
        : sendSupportMessage(conversationId, reply.trim(), replyToMessageId);
    },
    onMutate: async (): Promise<SendOptimisticContext> => {
      if (!canMutateConversation) {
        return {};
      }

      const trimmedReply = reply.trim();
      const hasAttachment = Boolean(selectedAttachment);
      const canApplyOptimisticMessage = hasAttachment || trimmedReply.length > 0;
      if (!canApplyOptimisticMessage) {
        return {};
      }

      const queryKey = adminQueryKeys.supportConversation(conversationId);
      await queryClient.cancelQueries({ queryKey });
      const previousConversation = queryClient.getQueryData<AdminSupportConversation>(queryKey);
      if (!previousConversation) {
        return {};
      }

      optimisticMessageCounterRef.current += 1;
      const optimisticMessageId = `optimistic-${conversationId}-${optimisticMessageCounterRef.current}`;
      const nowUtc = new Date().toISOString();
      const optimisticAttachmentObjectUrl = selectedAttachment
        ? URL.createObjectURL(selectedAttachment)
        : undefined;
      try {
        if (optimisticAttachmentObjectUrl) {
          optimisticAttachmentObjectUrlsRef.current.set(
            optimisticMessageId,
            optimisticAttachmentObjectUrl
          );
        }

        const safeSelectedAttachmentName = selectedAttachment
          ? sanitizeSensitiveText(selectedAttachment.name, 120)
          : undefined;
        const optimisticLastMessagePreview =
          trimmedReply || optimisticAttachmentPreview(safeSelectedAttachmentName);
        const optimisticMessage = {
          messageId: optimisticMessageId,
          conversationId,
          senderUserId: sessionUser?.userId ?? "admin",
          senderDisplayName:
            sessionUser?.displayName?.trim() ||
            (sessionUser?.email ? maskEmail(sessionUser.email) : null) ||
            operatorLabel,
          isFromAdmin: true,
          senderType: "Admin",
          body: trimmedReply,
          replyToMessageId: replyToMessageId?.trim() || null,
          replyToPreview: replyToPreview?.trim() || null,
          attachmentUrl: optimisticAttachmentObjectUrl ?? null,
          attachmentFileName: safeSelectedAttachmentName ?? null,
          attachmentContentType:
            selectedAttachment?.type?.trim() ||
            (selectedAttachment ? "application/octet-stream" : null),
          attachmentFileSizeBytes: selectedAttachment?.size ?? null,
          attachmentUploadStatus: selectedAttachment ? "uploading" : null,
          attachmentUploadErrorCode: null,
          attachments: selectedAttachment
            ? [
                {
                  fileUrl: optimisticAttachmentObjectUrl!,
                  type: selectedAttachment.type,
                  mimeType: selectedAttachment.type || "application/octet-stream",
                  fileName: safeSelectedAttachmentName ?? "attachment",
                  sizeBytes: selectedAttachment.size,
                  isDeleted: false,
                  expiresAtUtc: null,
                  deletedAtUtc: null,
                  durationSeconds: null,
                  width: null,
                  height: null,
                },
              ]
            : null,
          isRead: false,
          readAtUtc: null,
          deliveredAtUtc: null,
          isInternalNote: false,
          createdAtUtc: nowUtc,
        };

        queryClient.setQueryData<AdminSupportConversation>(queryKey, {
          ...previousConversation,
          messages: [...previousConversation.messages, optimisticMessage],
          lastMessageAtUtc: nowUtc,
          lastMessagePreview: optimisticLastMessagePreview,
          lastMessageSenderType: "Admin",
          updatedAtUtc: nowUtc,
        });

        return { previousConversation, optimisticMessageId, optimisticAttachmentObjectUrl };
      } catch (error) {
        if (optimisticAttachmentObjectUrl) {
          optimisticAttachmentObjectUrlsRef.current.delete(optimisticMessageId);
          URL.revokeObjectURL(optimisticAttachmentObjectUrl);
        }
        throw error;
      }
    },
    onSuccess: async (_data, _variables, context) => {
      if (context?.optimisticMessageId) {
        const optimisticObjectUrl = optimisticAttachmentObjectUrlsRef.current.get(
          context.optimisticMessageId
        );
        if (optimisticObjectUrl) {
          URL.revokeObjectURL(optimisticObjectUrl);
          optimisticAttachmentObjectUrlsRef.current.delete(context.optimisticMessageId);
        }
      }

      const queryKey = adminQueryKeys.supportConversation(conversationId);
      queryClient.setQueryData<AdminSupportConversation>(queryKey, (currentConversation) => {
        if (!currentConversation) {
          return currentConversation;
        }

        return {
          ...currentConversation,
          messages: currentConversation.messages.filter(
            (message) => !message.messageId.startsWith("optimistic-")
          ),
        };
      });

      setReply("");
      setReplyToMessageId(null);
      setReplyToPreview(null);
      resetSelectedAttachment();
      setToast({ type: "success", message: supportReplySent });
      pushSupportNotification("success", supportReplySent);
      await refreshConversationData();
    },
    onError: (error, _variables, context) => {
      if (context?.optimisticMessageId) {
        const optimisticObjectUrl = optimisticAttachmentObjectUrlsRef.current.get(
          context.optimisticMessageId
        );
        if (optimisticObjectUrl) {
          URL.revokeObjectURL(optimisticObjectUrl);
          optimisticAttachmentObjectUrlsRef.current.delete(context.optimisticMessageId);
        }
      }

      if (context?.previousConversation) {
        queryClient.setQueryData(
          adminQueryKeys.supportConversation(conversationId),
          context.previousConversation
        );
      }

      pushSupportError(error, "send_reply");
    },
    onSettled: () => {
      sendReplyInFlightRef.current = false;
      setIsSendReplyInFlight(false);
    },
  });

  const requestSendReply = useCallback(() => {
    if (
      !canMutateConversation ||
      sendReplyInFlightRef.current ||
      sendMutation.isPending ||
      (!reply.trim() && !selectedAttachment)
    ) {
      return false;
    }

    sendReplyInFlightRef.current = true;
    setIsSendReplyInFlight(true);
    sendMutation.mutate();
    return true;
  }, [canMutateConversation, reply, selectedAttachment, sendMutation]);

  const statusMutation = useMutation({
    mutationFn: async (status: SupportConversationStatus) => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }
      if (!canMutateConversation) {
        throw new Error(supportOwnershipRequired);
      }

      return updateSupportConversationStatus(conversationId, status);
    },
    onSuccess: async () => {
      setToast({ type: "success", message: supportStatusSaved });
      pushSupportNotification("success", supportStatusSaved);
      await refreshConversationData();
    },
    onError: (error) => {
      pushSupportError(error, "update_status");
    },
  });

  const assignmentMutation = useMutation({
    mutationFn: async (action: "claim" | "unassign") => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }

      return action === "claim"
        ? assignSupportConversationToMe(conversationId)
        : unassignSupportConversation(conversationId);
    },
    onSuccess: async () => {
      setToast({ type: "success", message: supportAssignmentSaved });
      pushSupportNotification("success", supportAssignmentSaved);
      await refreshConversationData();
    },
    onError: (error) => {
      pushSupportError(error, "assign_conversation");
    },
  });

  const metadataMutation = useMutation({
    mutationFn: async (payload: { priority: SupportConversationPriority; tags: string[] }) => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }
      if (!canMutateConversation) {
        throw new Error(supportOwnershipRequired);
      }

      return updateSupportConversationMetadata(conversationId, payload);
    },
    onSuccess: async () => {
      setToast({ type: "success", message: supportStatusSaved });
      pushSupportNotification("success", supportStatusSaved);
      await refreshConversationData();
    },
    onError: (error) => {
      pushSupportError(error, "update_metadata");
    },
  });

  return {
    assignmentMutation,
    isSendReplySubmitting: isSendReplyInFlight || sendMutation.isPending,
    metadataMutation,
    requestSendReply,
    sendMutation,
    statusMutation,
  };
}
