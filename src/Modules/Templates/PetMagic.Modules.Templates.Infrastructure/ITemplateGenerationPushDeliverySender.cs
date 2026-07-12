using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal interface ITemplateGenerationPushDeliverySender
{
    Task<PushDeliveryResult> DeliverGenerationTerminalAsync(
        TemplateGenerationResponse generation,
        CancellationToken cancellationToken);
}
