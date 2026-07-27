namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface IIdentityAccessTokenValidator
{
    Task<bool> IsCurrentAsync(Guid userId, string securityStamp, CancellationToken cancellationToken);

    Task<bool> IsCurrentAsync(
        Guid userId,
        string securityStamp,
        Guid? sessionId,
        CancellationToken cancellationToken);
}
