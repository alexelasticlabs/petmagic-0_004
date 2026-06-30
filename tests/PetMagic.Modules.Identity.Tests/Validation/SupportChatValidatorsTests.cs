using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Application.Validation;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.Validation;

public sealed class SupportChatValidatorsTests
{
    [Fact]
    public void OpenSupportConversationValidator_ShouldFail_WhenSourceInvalid()
    {
        var validator = new OpenSupportConversationCommandValidator();
        var result = validator.Validate(new OpenSupportConversationCommand(
            Guid.NewGuid(),
            "Need help",
            SupportConversationPriority.Normal,
            (SupportConversationSource)999));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void OpenSupportConversationValidator_ShouldFail_WhenPriorityInvalid()
    {
        var validator = new OpenSupportConversationCommandValidator();
        var result = validator.Validate(new OpenSupportConversationCommand(
            Guid.NewGuid(),
            "Need help",
            (SupportConversationPriority)999));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void OpenSupportConversationValidator_ShouldFail_WhenAssistantScenarioTooLong()
    {
        var validator = new OpenSupportConversationCommandValidator();
        var result = validator.Validate(new OpenSupportConversationCommand(
            Guid.NewGuid(),
            "Need help",
            SupportConversationPriority.Normal,
            AssistantScenario: new string('a', 65)));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void OpenSupportConversationValidator_ShouldFail_WhenRelatedGenerationIdEmpty()
    {
        var validator = new OpenSupportConversationCommandValidator();
        var result = validator.Validate(new OpenSupportConversationCommand(
            Guid.NewGuid(),
            "Need help",
            SupportConversationPriority.Normal,
            RelatedGenerationId: Guid.Empty));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void OpenSupportConversationValidator_ShouldFail_WhenRelatedPaymentIdEmpty()
    {
        var validator = new OpenSupportConversationCommandValidator();
        var result = validator.Validate(new OpenSupportConversationCommand(
            Guid.NewGuid(),
            "Need help",
            SupportConversationPriority.Normal,
            RelatedPaymentId: Guid.Empty));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void OpenSupportConversationValidator_ShouldFail_WhenRelatedSubscriptionIdEmpty()
    {
        var validator = new OpenSupportConversationCommandValidator();
        var result = validator.Validate(new OpenSupportConversationCommand(
            Guid.NewGuid(),
            "Need help",
            SupportConversationPriority.Normal,
            RelatedSubscriptionId: Guid.Empty));

        Assert.False(result.IsValid);
    }
}
