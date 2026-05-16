using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

internal interface IEmailSender
{
    Task<Result> SendAsync(EmailDispatchJob job, CancellationToken cancellationToken);
}