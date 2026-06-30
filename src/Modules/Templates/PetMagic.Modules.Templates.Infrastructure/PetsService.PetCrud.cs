using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class PetsService
{
    public async Task<Result<IReadOnlyList<PetResponse>>> ListAsync(Guid userId, CancellationToken cancellationToken)
    {
        var rows = await dbContext.Pets
            .AsNoTracking()
            .Where(x => x.UserId == userId && !x.IsDeleted && x.Status == "active")
            .OrderByDescending(x => x.UpdatedAtUtc)
            .Select(x => new PetListProjection(
                x,
                x.Photos.Count(photo => !photo.IsDeleted && photo.Status == "active" && !photo.MediaAsset.IsDeleted),
                dbContext.TemplateGenerationJobs.Count(job => job.UserId == userId && job.PetId == x.Id && job.HiddenByUserAtUtc == null),
                x.Photos
                    .Where(photo => !photo.IsDeleted
                        && photo.Status == "active"
                        && !photo.MediaAsset.IsDeleted)
                    .OrderByDescending(photo => photo.MediaAssetId == x.AvatarMediaAssetId || photo.IsAvatar)
                    .ThenBy(photo => photo.SortOrder)
                    .ThenBy(photo => photo.CreatedAtUtc)
                    .Select(photo => photo.MediaAsset.Url != string.Empty
                        ? photo.MediaAsset.Url
                        : photo.MediaAsset.StoragePath)
                    .FirstOrDefault()))
            .ToArrayAsync(cancellationToken);

        var mapped = new List<PetResponse>(rows.Length);
        foreach (var row in rows)
        {
            mapped.Add(await MapPetAsync(row.Pet, row.PhotosCount, row.GenerationsCount, row.AvatarUrl, cancellationToken));
        }

        return Result.Success<IReadOnlyList<PetResponse>>(mapped);
    }

    public async Task<Result<PetResponse>> CreateAsync(CreatePetCommand command, CancellationToken cancellationToken)
    {
        var type = NormalizeType(command.Type);
        if (type is null)
        {
            return Result.Failure<PetResponse>(TemplatesErrors.InvalidPetStatus);
        }

        var now = DateTime.UtcNow;
        var pet = new Pet
        {
            Id = Guid.NewGuid(),
            UserId = command.UserId,
            Name = command.Name.Trim(),
            Type = type,
            Breed = NormalizeOptional(command.Breed),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.Pets.Add(pet);
        await AddPetAnalyticsEventAsync(pet, TemplateAnalyticsEventTypes.PetCreated, cancellationToken: cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(await MapPetAsync(pet, 0, 0, null, cancellationToken));
    }

    public async Task<Result<PetResponse>> UpdateAsync(UpdatePetCommand command, CancellationToken cancellationToken)
    {
        var type = NormalizeType(command.Type);
        if (type is null)
        {
            return Result.Failure<PetResponse>(TemplatesErrors.InvalidPetStatus);
        }

        var pet = await FindActivePetAsync(command.UserId, command.PetId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure<PetResponse>(TemplatesErrors.PetNotFound);
        }

        pet.Name = command.Name.Trim();
        pet.Type = type;
        pet.Breed = NormalizeOptional(command.Breed);
        pet.UpdatedAtUtc = DateTime.UtcNow;
        await AddPetAnalyticsEventAsync(pet, TemplateAnalyticsEventTypes.PetUpdated, cancellationToken: cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(await BuildPetResponseAsync(pet, cancellationToken));
    }

    public async Task<Result> DeleteAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(userId, petId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure(TemplatesErrors.PetNotFound);
        }

        var now = DateTime.UtcNow;
        pet.IsDeleted = true;
        pet.Status = "deleted";
        pet.DeletedAtUtc = now;
        pet.UpdatedAtUtc = now;
        await AddPetAnalyticsEventAsync(pet, TemplateAnalyticsEventTypes.PetDeleted, cancellationToken: cancellationToken);

        await dbContext.PetPhotos
            .Where(x => x.UserId == userId && x.PetId == petId && !x.IsDeleted)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.IsDeleted, true)
                .SetProperty(x => x.Status, "deleted")
                .SetProperty(x => x.DeletedAtUtc, now),
                cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    private static string? NormalizeType(string value)
    {
        var normalized = value.Trim().ToLowerInvariant();
        return ValidPetTypes.Contains(normalized) ? normalized : null;
    }

    private static string? NormalizeOptional(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }
}
