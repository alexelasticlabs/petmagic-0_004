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
    }
}

public sealed class SendSupportMessageCommandValidator : AbstractValidator<SendSupportMessageCommand>
{
    public SendSupportMessageCommandValidator()
    {
        RuleFor(x => x.ConversationId).NotEmpty();
        RuleFor(x => x.SenderUserId).NotEmpty();
        RuleFor(x => x.IsInternalNote)
            .Equal(false)
            .When(x => !x.IsAdmin)
            .WithMessage("Internal notes are only supported for admin senders.");
        RuleFor(x => x.Body)
            .NotEmpty()
            .MaximumLength(4000);
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
        RuleFor(x => x.Kind)
            .Must(kind => Enum.IsDefined(kind))
            .WithMessage("Support reply template kind is not supported.");
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