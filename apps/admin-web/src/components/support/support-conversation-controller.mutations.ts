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
  getSupportReplyActor,
  isSupportReplyActorCurrent,
  rollbackOptimisticSupportMessage,
  type SupportReplyActor,
  type SupportReplySessionIdentity,
  type SendOptimisticContext,
  type ToastState,
} from "@/components/support/support-conversation-controller.helpers";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  isSupportedSupportAttachmentMimeType,
  retrySupportAttachment,
  sendSupportAttachment,
  sendSupportMessage,
  updateSupportConversationMetadata,
  updateSupportConversationStatus,
  type AdminSupportConversation,
  type SupportConversationPriority,
  type SupportConversationStatus,
} from "@/lib/api-client";
import { getSession } from "@/lib/api-client.core";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";
import {
  clearSupportAttachmentIdempotencyKey,
  clearSupportMessageIdempotencyKey,
  getOrCreateSupportAttachmentIdempotencyKey,
  getOrCreateSupportMessageIdempotencyKey,
} from "@/lib/support-message-idempotency";

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
  sessionUser: SupportReplySessionIdentity | null | undefined;
  queryClient: QueryClient;
  optimisticAttachmentPreview: (fileName?: string | null) => string;
  operatorLabel: string;
  supportReplySent: string;
  supportAttachmentRetryRequired: string;
  supportStatusSaved: string;
  pushSupportNotification: (type: ToastState["type"], message: string) => void;
  pushSupportError: (error: unknown, action?: string) => void;
  setToast: Dispatch<SetStateAction<ToastState | null>>;
  resetSelectedAttachment: () => void;
  refreshConversationData: () => Promise<void>;
  setReply: Dispatch<SetStateAction<string>>;
  setReplyToMessageId: Dispatch<SetStateAction<string | null>>;
  setReplyToPreview: Dispatch<SetStateAction<string | null>>;
};

type SendSupportReplyVariables = {
  actor: SupportReplyActor;
  body: string;
  idempotencyKey: string;
  idempotencyIntent: "attachment" | "text";
  replyToMessageId: string | null;
  replyToPreview: string | null;
  selectedAttachment: File | null;
};

type PendingSupportReplyIntent = {
  actorId: string;
  draftSignature: string;
  idempotencyKey: string;
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
  supportAttachmentRetryRequired,
  supportStatusSaved,
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
  const [sendReplyActorId, setSendReplyActorId] = useState<string | null>(null);
  const sendReplyInFlightRef = useRef(false);
  const optimisticAttachmentObjectUrlsRef = useRef(new Map<string, string>());
  const optimisticMessageCounterRef = useRef(0);
  const pendingSupportReplyIntentRef = useRef<PendingSupportReplyIntent | null>(null);
  const sendReplyActorIdRef = useRef<string | null>(null);
  const attachmentIntentIdsRef = useRef(new WeakMap<File, string>());
  const attachmentIntentCounterRef = useRef(0);
  const sessionActor = getSupportReplyActor(sessionUser);
  const isReplyActorCurrent = useCallback(
    (actor: SupportReplyActor) => isSupportReplyActorCurrent(actor, getSession()?.user),
    []
  );
  const releaseSendReply = useCallback((actorId: string) => {
    if (sendReplyActorIdRef.current !== actorId) {
      return;
    }

    sendReplyInFlightRef.current = false;
    sendReplyActorIdRef.current = null;
    setSendReplyActorId(null);
    setIsSendReplyInFlight(false);
  }, []);

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
    mutationFn: async (variables: SendSupportReplyVariables) => {
      if (!isReplyActorCurrent(variables.actor)) {
        throw new Error("Support reply actor changed before the request was sent.");
      }
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }
      if (!canMutateConversation) {
        throw new Error(supportOwnershipRequired);
      }

      return variables.selectedAttachment
        ? sendSupportAttachment(
            conversationId,
            variables.selectedAttachment,
            variables.body,
            variables.replyToMessageId,
            variables.idempotencyKey
          )
        : sendSupportMessage(
            conversationId,
            variables.body,
            variables.replyToMessageId,
            variables.idempotencyKey
          );
    },
    onMutate: async (variables: SendSupportReplyVariables): Promise<SendOptimisticContext> => {
      if (!isReplyActorCurrent(variables.actor) || !canMutateConversation) {
        return {};
      }

      const trimmedReply = variables.body;
      const selectedAttachment = variables.selectedAttachment;
      const replyToMessageId = variables.replyToMessageId;
      const replyToPreview = variables.replyToPreview;
      const hasAttachment = Boolean(selectedAttachment);
      const canApplyOptimisticMessage = hasAttachment || trimmedReply.length > 0;
      if (!canApplyOptimisticMessage) {
        return {};
      }

      const queryKey = adminQueryKeys.supportConversation(conversationId);
      await queryClient.cancelQueries({ queryKey });
      if (!isReplyActorCurrent(variables.actor)) {
        return {};
      }
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
          senderUserId: variables.actor.userId,
          senderDisplayName:
            variables.actor.displayName?.trim() ||
            (variables.actor.email ? maskEmail(variables.actor.email) : null) ||
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

        return { optimisticMessageId, optimisticAttachmentObjectUrl };
      } catch (error) {
        if (optimisticAttachmentObjectUrl) {
          optimisticAttachmentObjectUrlsRef.current.delete(optimisticMessageId);
          URL.revokeObjectURL(optimisticAttachmentObjectUrl);
        }
        throw error;
      }
    },
    onSuccess: async (_data, variables, context) => {
      if (context?.optimisticMessageId) {
        const optimisticObjectUrl = optimisticAttachmentObjectUrlsRef.current.get(
          context.optimisticMessageId
        );
        if (optimisticObjectUrl) {
          URL.revokeObjectURL(optimisticObjectUrl);
          optimisticAttachmentObjectUrlsRef.current.delete(context.optimisticMessageId);
        }
      }

      if (variables.idempotencyIntent === "text") {
        await clearSupportMessageIdempotencyKey(
          variables.actor.userId,
          conversationId,
          variables.body,
          variables.replyToMessageId
        );
      } else if (variables.selectedAttachment) {
        await clearSupportAttachmentIdempotencyKey(
          variables.actor.userId,
          conversationId,
          variables.selectedAttachment,
          variables.body,
          variables.replyToMessageId
        );
      }
      if (pendingSupportReplyIntentRef.current?.actorId === variables.actor.userId) {
        pendingSupportReplyIntentRef.current = null;
      }
      if (!isReplyActorCurrent(variables.actor)) {
        return;
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
      const attachmentUploadFailed =
        Boolean(variables.selectedAttachment) &&
        _data.attachmentUploadStatus?.trim().toLowerCase() !== "uploaded";
      const notificationMessage = attachmentUploadFailed
        ? supportAttachmentRetryRequired
        : supportReplySent;
      const notificationType = attachmentUploadFailed ? "error" : "success";
      setToast({ type: notificationType, message: notificationMessage });
      pushSupportNotification(notificationType, notificationMessage);
      await refreshConversationData();
    },
    onError: (error, variables, context) => {
      if (context?.optimisticMessageId) {
        const optimisticObjectUrl = optimisticAttachmentObjectUrlsRef.current.get(
          context.optimisticMessageId
        );
        if (optimisticObjectUrl) {
          URL.revokeObjectURL(optimisticObjectUrl);
          optimisticAttachmentObjectUrlsRef.current.delete(context.optimisticMessageId);
        }
      }

      if (!isReplyActorCurrent(variables.actor)) {
        return;
      }

      const queryKey = adminQueryKeys.supportConversation(conversationId);
      const optimisticMessageId = context?.optimisticMessageId;
      if (optimisticMessageId) {
        queryClient.setQueryData<AdminSupportConversation>(queryKey, (currentConversation) =>
          currentConversation
            ? rollbackOptimisticSupportMessage(currentConversation, optimisticMessageId)
            : currentConversation
        );
      }

      void queryClient.invalidateQueries({ queryKey });

      pushSupportError(error, "send_reply");
    },
    onSettled: (_data, _error, variables) => {
      releaseSendReply(variables.actor.userId);
    },
  });

  const requestSendReply = useCallback(() => {
    const actor = sessionActor;
    const isReplyInFlightForActor = Boolean(
      actor &&
      sendReplyActorIdRef.current === actor.userId &&
      (sendReplyInFlightRef.current || sendMutation.isPending)
    );
    if (
      !actor ||
      !canMutateConversation ||
      !isReplyActorCurrent(actor) ||
      isReplyInFlightForActor ||
      (!reply.trim() && !selectedAttachment)
    ) {
      return false;
    }

    sendReplyInFlightRef.current = true;
    sendReplyActorIdRef.current = actor.userId;
    setSendReplyActorId(actor.userId);
    setIsSendReplyInFlight(true);
    const body = reply.trim();
    const replyToId = replyToMessageId?.trim() || null;
    const selectedReplyAttachment = selectedAttachment;
    const attachmentIntentId = (() => {
      if (!selectedReplyAttachment) {
        return "text";
      }

      const knownId = attachmentIntentIdsRef.current.get(selectedReplyAttachment);
      if (knownId) {
        return knownId;
      }

      attachmentIntentCounterRef.current += 1;
      const nextId = `attachment-${attachmentIntentCounterRef.current}`;
      attachmentIntentIdsRef.current.set(selectedReplyAttachment, nextId);
      return nextId;
    })();
    const draftSignature = JSON.stringify({
      attachmentIntentId,
      body,
      replyToMessageId: replyToId,
    });

    void (async () => {
      const pendingIntent = pendingSupportReplyIntentRef.current;
      const idempotencyIntent = selectedReplyAttachment ? "attachment" : "text";
      const idempotencyKey =
        pendingIntent?.actorId === actor.userId && pendingIntent.draftSignature === draftSignature
          ? pendingIntent.idempotencyKey
          : idempotencyIntent === "text"
            ? await getOrCreateSupportMessageIdempotencyKey(
                actor.userId,
                conversationId,
                body,
                replyToId
              )
            : await getOrCreateSupportAttachmentIdempotencyKey(
                actor.userId,
                conversationId,
                selectedReplyAttachment!,
                body,
                replyToId
              );

      if (!isReplyActorCurrent(actor)) {
        releaseSendReply(actor.userId);
        return;
      }

      pendingSupportReplyIntentRef.current = {
        actorId: actor.userId,
        draftSignature,
        idempotencyKey,
      };
      sendMutation.mutate({
        actor,
        body,
        idempotencyKey,
        idempotencyIntent,
        replyToMessageId: replyToId,
        replyToPreview,
        selectedAttachment: selectedReplyAttachment,
      });
    })().catch((error: unknown) => {
      releaseSendReply(actor.userId);
      if (isReplyActorCurrent(actor)) {
        pushSupportError(error, "send_reply");
      }
    });
    return true;
  }, [
    canMutateConversation,
    conversationId,
    isReplyActorCurrent,
    pushSupportError,
    reply,
    replyToMessageId,
    replyToPreview,
    releaseSendReply,
    selectedAttachment,
    sendMutation,
    sessionActor,
  ]);

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

  const retryAttachmentMutation = useMutation({
    mutationFn: async ({ messageId, file }: { messageId: string; file: File }) => {
      if (!assertCanManageSupportWorkspace()) {
        throw new Error(supportActionsForbidden);
      }
      if (!canMutateConversation) {
        throw new Error(supportOwnershipRequired);
      }

      return retrySupportAttachment(conversationId, messageId, file);
    },
    onSuccess: async (message) => {
      const uploadSucceeded = message.attachmentUploadStatus?.trim().toLowerCase() === "uploaded";
      const notificationMessage = uploadSucceeded
        ? supportReplySent
        : supportAttachmentRetryRequired;
      const notificationType = uploadSucceeded ? "success" : "error";
      setToast({ type: notificationType, message: notificationMessage });
      pushSupportNotification(notificationType, notificationMessage);
      await refreshConversationData();
    },
    onError: (error) => {
      pushSupportError(error, "retry_attachment");
    },
  });

  const requestAttachmentRetry = useCallback(
    (messageId: string, file: File) => {
      if (
        !canMutateConversation ||
        retryAttachmentMutation.isPending ||
        !isSupportedSupportAttachmentMimeType(file.type)
      ) {
        if (!isSupportedSupportAttachmentMimeType(file.type)) {
          setToast({ type: "error", message: supportAttachmentRetryRequired });
          pushSupportNotification("error", supportAttachmentRetryRequired);
        }
        return;
      }

      retryAttachmentMutation.mutate({ messageId, file });
    },
    [
      canMutateConversation,
      pushSupportNotification,
      retryAttachmentMutation,
      setToast,
      supportAttachmentRetryRequired,
    ]
  );

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
    isAttachmentRetrySubmitting: retryAttachmentMutation.isPending,
    isSendReplySubmitting: Boolean(
      sessionActor &&
      sendReplyActorId === sessionActor.userId &&
      (isSendReplyInFlight || sendMutation.isPending)
    ),
    metadataMutation,
    requestAttachmentRetry,
    requestSendReply,
    sendMutation,
    statusMutation,
  };
}
