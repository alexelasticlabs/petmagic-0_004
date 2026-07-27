using FluentValidation;

using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Application.Validation;

public sealed class OpenSupportConversationCommandValidator : AbstractValidator<OpenSupportConversationCommand>
{
    public OpenSupportConversationCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.InitialMessage)
            .MaximumLength(4000)
            .When(x => !string.IsNullOrWhiteSpace(x.InitialMessage));
        RuleFor(x => x.Priority)
            .Equal(SupportConversationPriority.Normal)
            .WithMessage("support.conversation_priority_invalid");
        RuleFor(x => x.Source)
            .Must(source => source is SupportConversationSource.MobileChat or SupportConversationSource.MobileAssistant)
            .WithMessage("support.conversation_source_invalid");
        RuleFor(x => x.AssistantScenario)
            .MaximumLength(64)
            .When(x => !string.IsNullOrWhiteSpace(x.AssistantScenario));
        RuleFor(x => x.RelatedGenerationId)
            .Must(id => id is null || id.Value != Guid.Empty)
            .When(x => x.RelatedGenerationId.HasValue);
        RuleFor(x => x.RelatedPaymentId)
            .Must(id => id is null || id.Value != Guid.Empty)
            .When(x => x.RelatedPaymentId.HasValue);
        RuleFor(x => x.RelatedSubscriptionId)
            .Must(id => id is null || id.Value != Guid.Empty)
            .When(x => x.RelatedSubscriptionId.HasValue);
    }
}

public sealed class SendSupportMessageCommandValidator : AbstractValidator<SendSupportMessageCommand>
{
    public SendSupportMessageCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.SenderUserId).NotEmpty();
        RuleFor(x => x.Body)
            .NotEmpty()
            .MaximumLength(4000);
        RuleFor(x => x.ReplyToMessageId)
            .NotEmpty()
            .When(x => x.ReplyToMessageId.HasValue);
        RuleFor(x => x.IdempotencyKey)
            .Must(value => SupportMessageIdempotency.TryNormalize(value, out _))
            .WithMessage("support.idempotency_key_invalid");
    }
}

public sealed class SendSupportAttachmentsCommandValidator : AbstractValidator<SendSupportAttachmentsCommand>
{
    public SendSupportAttachmentsCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.SenderUserId).NotEmpty();
        RuleFor(x => x.Body).MaximumLength(4000);
        RuleFor(x => x.Attachments)
            .NotNull()
            .Must(attachments => attachments.Count is >= 1 and <= 5)
            .WithMessage("support.message_attachments_count_invalid");
        RuleForEach(x => x.Attachments).SetValidator(new SupportMessageAttachmentInputValidator());
        RuleFor(x => x.ReplyToMessageId)
            .NotEmpty()
            .When(x => x.ReplyToMessageId.HasValue);
        RuleFor(x => x.IdempotencyKey)
            .Must(value => SupportMessageIdempotency.TryNormalize(value, out _))
            .WithMessage("support.idempotency_key_invalid");
    }
}

public sealed class SupportMessageAttachmentInputValidator : AbstractValidator<SupportMessageAttachmentInput>
{
    public SupportMessageAttachmentInputValidator()
    {
        RuleFor(x => x.FileUrl).NotEmpty().MaximumLength(2048);
        RuleFor(x => x.FileName).NotEmpty().MaximumLength(256);
        RuleFor(x => x.MimeType).NotEmpty().MaximumLength(128);
        RuleFor(x => x.SizeBytes).GreaterThan(0);
        RuleFor(x => x.StorageKey).MaximumLength(1024);
    }
}

public sealed class MarkSupportConversationReadCommandValidator : AbstractValidator<MarkSupportConversationReadCommand>
{
    public MarkSupportConversationReadCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class ResolveSupportConversationCommandValidator : AbstractValidator<ResolveSupportConversationCommand>
{
    public ResolveSupportConversationCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class CloseSupportConversationCommandValidator : AbstractValidator<CloseSupportConversationCommand>
{
    public CloseSupportConversationCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class ReopenSupportConversationCommandValidator : AbstractValidator<ReopenSupportConversationCommand>
{
    public ReopenSupportConversationCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class SubmitSupportConversationFeedbackCommandValidator : AbstractValidator<SubmitSupportConversationFeedbackCommand>
{
    public SubmitSupportConversationFeedbackCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Rating).InclusiveBetween(1, 5);
        RuleFor(x => x.Comment).MaximumLength(1000);
    }
}

public sealed class RegisterSupportPushTokenCommandValidator : AbstractValidator<RegisterSupportPushTokenCommand>
{
    private const int MinPushTokenLength = 20;

    public RegisterSupportPushTokenCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Token).NotEmpty().MinimumLength(MinPushTokenLength).MaximumLength(4096);
        RuleFor(x => x.Platform).MaximumLength(32);
        RuleFor(x => x.DeviceId).MaximumLength(128);
        RuleFor(x => x.AppVersion).MaximumLength(64);
        RuleFor(x => x.Locale).MaximumLength(16);
    }
}

public sealed class UnregisterSupportPushTokenCommandValidator : AbstractValidator<UnregisterSupportPushTokenCommand>
{
    private const int MinPushTokenLength = 20;

    public UnregisterSupportPushTokenCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Token).NotEmpty().MinimumLength(MinPushTokenLength).MaximumLength(4096);
    }
}

public sealed class UpdateSupportConversationStatusCommandValidator : AbstractValidator<UpdateSupportConversationStatusCommand>
{
    public UpdateSupportConversationStatusCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
        RuleFor(x => x.Status)
            .Must(status => Enum.IsDefined(status))
            .WithMessage("support.conversation_status_invalid");
    }
}

public sealed class AssignSupportConversationCommandValidator : AbstractValidator<AssignSupportConversationCommand>
{
    private const int MaxReasonLength = 500;

    public AssignSupportConversationCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
        RuleFor(x => x.AssignedAdminId)
            .NotEqual(Guid.Empty)
            .When(x => x.AssignedAdminId.HasValue)
            .WithMessage("support.assigned_admin_id_required");
        RuleFor(x => x.Reason)
            .NotEmpty()
            .WithMessage("support.assignment_reason_required")
            .MinimumLength(3)
            .WithMessage("support.assignment_reason_too_short")
            .MaximumLength(MaxReasonLength)
            .WithMessage("support.assignment_reason_too_long");
        RuleFor(x => x.ExpectedVersion)
            .NotNull()
            .WithMessage("support.assignment_expected_version_required")
            .GreaterThan(0)
            .WithMessage("support.assignment_expected_version_invalid");
    }
}

public sealed class UpdateSupportConversationMetadataCommandValidator : AbstractValidator<UpdateSupportConversationMetadataCommand>
{
    public UpdateSupportConversationMetadataCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
        RuleFor(x => x.Priority)
            .Must(priority => Enum.IsDefined(priority))
            .WithMessage("support.conversation_priority_invalid");
        RuleFor(x => x.Tags)
            .NotNull();
        RuleFor(x => x.Tags.Count)
            .LessThanOrEqualTo(SupportConversationMetadataLimits.MaxTagCount);
        RuleForEach(x => x.Tags)
            .NotEmpty()
            .MaximumLength(SupportConversationMetadataLimits.MaxTagLength);
    }
}

public sealed class UpsertSupportReplyTemplateCommandValidator : AbstractValidator<UpsertSupportReplyTemplateCommand>
{
    public UpsertSupportReplyTemplateCommandValidator()
    {
        RuleFor(x => x.AdminUserId).NotEmpty();
        RuleFor(x => x.Title).NotEmpty().MaximumLength(120);
        RuleFor(x => x.Body).NotEmpty().MaximumLength(4000);
        RuleFor(x => x.SortOrder).GreaterThanOrEqualTo(0);
        RuleFor(x => x.ExpectedVersion).GreaterThan(0).When(x => x.ExpectedVersion.HasValue);
        RuleFor(x => x.Reason).MaximumLength(500).When(x => x.Reason is not null);
    }
}

public sealed class DeleteSupportReplyTemplateCommandValidator : AbstractValidator<DeleteSupportReplyTemplateCommand>
{
    public DeleteSupportReplyTemplateCommandValidator()
    {
        RuleFor(x => x.TemplateId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
        RuleFor(x => x.ExpectedVersion).GreaterThan(0).When(x => x.ExpectedVersion.HasValue);
        RuleFor(x => x.Reason).MaximumLength(500).When(x => x.Reason is not null);
    }
}
