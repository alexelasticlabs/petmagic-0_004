using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateGenerationPushNotificationSender
{
    Task NotifyGenerationTerminalAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken);
}
