using FluentValidation;

using PetMagic.Modules.SupportChat.Application.Contracts;
namespace PetMagic.Modules.SupportChat.Application.Validation;

public sealed class OpenSupportConversationCommandValidator : AbstractValidator<OpenSupportConversationCommand>
{
    public OpenSupportConversationCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.InitialMessage)
            .MaximumLength(4000)
            .When(x => !string.IsNullOrWhiteSpace(x.InitialMessage));
    }
}

public sealed class SendSupportMessageCommandValidator : AbstractValidator<SendSupportMessageCommand>
{
    public SendSupportMessageCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.SenderUserId).NotEmpty();
        RuleFor(x => x.Body)
            .MaximumLength(4000);
        RuleFor(x => x.Body)
            .NotEmpty()
            .When(x => string.IsNullOrWhiteSpace(x.AttachmentUrl));
        RuleFor(x => x.AttachmentUrl)
            .NotEmpty()
            .When(x => !string.IsNullOrWhiteSpace(x.AttachmentFileName));
        RuleFor(x => x.AttachmentFileName)
            .NotEmpty()
            .MaximumLength(256)
            .When(x => !string.IsNullOrWhiteSpace(x.AttachmentUrl));
        RuleFor(x => x.AttachmentContentType)
            .NotEmpty()
            .MaximumLength(128)
            .When(x => !string.IsNullOrWhiteSpace(x.AttachmentUrl));
        RuleFor(x => x.AttachmentFileSizeBytes)
            .NotNull()
            .GreaterThan(0)
            .When(x => !string.IsNullOrWhiteSpace(x.AttachmentUrl));
        RuleFor(x => x.ReplyToMessageId)
            .NotEmpty()
            .When(x => x.ReplyToMessageId.HasValue);
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
            .WithMessage("Support message attachments must contain from 1 to 5 files.");
        RuleForEach(x => x.Attachments).SetValidator(new SupportMessageAttachmentInputValidator());
        RuleFor(x => x.ReplyToMessageId)
            .NotEmpty()
            .When(x => x.ReplyToMessageId.HasValue);
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

public sealed class UpdateSupportConversationStatusCommandValidator : AbstractValidator<UpdateSupportConversationStatusCommand>
{
    public UpdateSupportConversationStatusCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
        RuleFor(x => x.Status)
            .Must(status => Enum.IsDefined(status))
            .WithMessage("Support conversation status is not supported.");
    }
}

public sealed class AssignSupportConversationCommandValidator : AbstractValidator<AssignSupportConversationCommand>
{
    public AssignSupportConversationCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
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
    }
}

public sealed class DeleteSupportReplyTemplateCommandValidator : AbstractValidator<DeleteSupportReplyTemplateCommand>
{
    public DeleteSupportReplyTemplateCommandValidator()
    {
        RuleFor(x => x.TemplateId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
    }
}
