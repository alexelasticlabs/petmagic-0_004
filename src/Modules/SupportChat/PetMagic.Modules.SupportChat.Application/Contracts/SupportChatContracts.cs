using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Application.Contracts;

public sealed record OpenSupportConversationCommand(
    Guid UserId,
    string? InitialMessage,
    SupportConversationPriority Priority);

public sealed record ListAdminSupportInboxQuery(
    string? Status,
    Guid? AssignedAdminId = null,
    bool UnassignedOnly = false);

public sealed record SendSupportMessageCommand(
    Guid ConversationId,
    Guid SenderUserId,
    string Body,
    bool IsAdmin,
    bool IsInternalNote = false);

public sealed record MarkSupportConversationReadCommand(
    Guid ConversationId,
    Guid UserId,
    bool IsAdmin);

public sealed record UpdateSupportConversationStatusCommand(
    Guid ConversationId,
    Guid AdminUserId,
    SupportConversationStatus Status);

public sealed record AssignSupportConversationCommand(
    Guid ConversationId,
    Guid AdminUserId,
    Guid? AssignedAdminId);

public sealed record UpsertSupportReplyTemplateCommand(
    Guid? TemplateId,
    Guid AdminUserId,
    string Title,
    string Body,
    SupportReplyTemplateKind Kind,
    bool IsEnabled,
    int SortOrder);

public sealed record DeleteSupportReplyTemplateCommand(
    Guid TemplateId,
    Guid AdminUserId);

public sealed record SupportConversationSummaryResponse(
    Guid ConversationId,
    Guid InitiatorUserId,
    string UserEmail,
    string? UserDisplayName,
    Guid? AssignedAdminId,
    string? AssignedAdminDisplayName,
    string Status,
    string Priority,
    string? LastMessagePreview,
    bool LastMessageIsInternalNote,
    DateTime? LastMessageAtUtc,
    int UserUnreadCount,
    int AdminUnreadCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);

public sealed record SupportMessageResponse(
    Guid MessageId,
    Guid ConversationId,
    Guid SenderUserId,
    string SenderDisplayName,
    bool IsFromAdmin,
    bool IsInternalNote,
    string Body,
    bool IsRead,
    DateTime? ReadAtUtc,
    DateTime CreatedAtUtc);

public sealed record SupportConversationDetailResponse(
    Guid ConversationId,
    Guid InitiatorUserId,
    string UserEmail,
    string? UserDisplayName,
    Guid? AssignedAdminId,
    string? AssignedAdminDisplayName,
    string Status,
    string Priority,
    int UserUnreadCount,
    int AdminUnreadCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? LastMessageAtUtc,
    IReadOnlyList<SupportMessageResponse> Messages);

public sealed record SupportReplyTemplateResponse(
    Guid TemplateId,
    string Title,
    string Body,
    string Kind,
    bool IsEnabled,
    int SortOrder,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);