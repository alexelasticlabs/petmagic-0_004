namespace PetMagic.Modules.Identity.Application.Abstractions;

public sealed record IdentityUserLookup(
    Guid UserId,
    string Email,
    string? DisplayName);

public interface IIdentityUserLookupService
{
    Task<IReadOnlyDictionary<Guid, IdentityUserLookup>> GetUsersByIdsAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken);

    Task<IdentityUserLookup?> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken);
}
