using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class NoopTemplateGenerationPushNotificationSender : ITemplateGenerationPushNotificationSender
{
    public Task NotifyGenerationTerminalAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
