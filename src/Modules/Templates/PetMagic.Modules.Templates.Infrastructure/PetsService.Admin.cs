using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class PetsService
{
    public async Task<Result<IReadOnlyList<AdminPetResponse>>> ListAdminUserPetsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var rows = await dbContext.Pets
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .Select(x => new PetListProjection(
                x,
                x.Photos.Count(photo => !photo.IsDeleted),
                dbContext.TemplateGenerationJobs.Count(job => job.UserId == userId && job.PetId == x.Id),
                x.Photos
                    .Where(photo => !photo.IsDeleted && photo.MediaAssetId == x.AvatarMediaAssetId)
                    .Select(photo => photo.MediaAsset.Url != string.Empty
                        ? photo.MediaAsset.Url
                        : photo.ThumbnailUrl)
                    .FirstOrDefault()))
            .ToArrayAsync(cancellationToken);

        var mapped = new List<AdminPetResponse>(rows.Length);
        foreach (var row in rows)
        {
            var pet = await MapPetAsync(row.Pet, row.PhotosCount, row.GenerationsCount, row.AvatarUrl, cancellationToken);
            mapped.Add(new AdminPetResponse(
                pet.Id,
                pet.UserId,
                pet.Name,
                pet.Type,
                pet.Breed,
                pet.AvatarMediaAssetId,
                pet.AvatarUrl,
                pet.PhotosCount,
                pet.GenerationsCount,
                pet.Status,
                pet.CreatedAtUtc,
                pet.UpdatedAtUtc,
                pet.IsDeleted));
        }

        return Result.Success<IReadOnlyList<AdminPetResponse>>(mapped);
    }

    public async Task<Result<IReadOnlyList<PetPhotoResponse>>> ListAdminPetPhotosAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
    {
        if (!await dbContext.Pets.AnyAsync(x => x.Id == petId && x.UserId == userId, cancellationToken))
        {
            return Result.Failure<IReadOnlyList<PetPhotoResponse>>(TemplatesErrors.PetNotFound);
        }

        var photos = await dbContext.PetPhotos
            .AsNoTracking()
            .Include(x => x.MediaAsset)
            .Where(x => x.UserId == userId && x.PetId == petId)
            .OrderBy(x => x.SortOrder)
            .ThenByDescending(x => x.CreatedAtUtc)
            .ToArrayAsync(cancellationToken);

        var mapped = new List<PetPhotoResponse>(photos.Length);
        foreach (var photo in photos)
        {
            mapped.Add(await MapPhotoAsync(photo, photo.MediaAsset, cancellationToken));
        }

        return Result.Success<IReadOnlyList<PetPhotoResponse>>(mapped);
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListAdminPetGenerationsAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
    {
        if (!await dbContext.Pets.AnyAsync(x => x.Id == petId && x.UserId == userId, cancellationToken))
        {
            return Result.Failure<IReadOnlyList<TemplateGenerationResponse>>(TemplatesErrors.PetNotFound);
        }

        var generations = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Where(x => x.UserId == userId && x.PetId == petId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(50)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>([.. generations.Select(x => TemplateGenerationService.MapResponse(x))]);
    }

    public async Task<Result<AdminPetResponse>> ChangeAdminPetStatusAsync(Guid userId, Guid petId, string? status, CancellationToken cancellationToken)
    {
        var normalized = NormalizeAdminStatus(status);
        if (normalized is null)
        {
            return Result.Failure<AdminPetResponse>(TemplatesErrors.InvalidPetStatus);
        }

        var pet = await dbContext.Pets.FirstOrDefaultAsync(x => x.Id == petId && x.UserId == userId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure<AdminPetResponse>(TemplatesErrors.PetNotFound);
        }

        pet.Status = normalized;
        pet.IsDeleted = normalized == "deleted";
        pet.DeletedAtUtc = pet.IsDeleted ? DateTime.UtcNow : null;
        pet.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        var mapped = await BuildPetResponseAsync(pet, cancellationToken);
        return Result.Success(new AdminPetResponse(
            mapped.Id,
            mapped.UserId,
            mapped.Name,
            mapped.Type,
            mapped.Breed,
            mapped.AvatarMediaAssetId,
            mapped.AvatarUrl,
            mapped.PhotosCount,
            mapped.GenerationsCount,
            mapped.Status,
            mapped.CreatedAtUtc,
            mapped.UpdatedAtUtc,
            mapped.IsDeleted));
    }

    public async Task<Result<PetPhotoResponse>> ChangeAdminPhotoStatusAsync(Guid userId, Guid petId, Guid photoId, string? status, CancellationToken cancellationToken)
    {
        var normalized = NormalizeAdminStatus(status);
        if (normalized is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.InvalidPetStatus);
        }

        var photo = await dbContext.PetPhotos
            .Include(x => x.MediaAsset)
            .FirstOrDefaultAsync(x => x.Id == photoId && x.UserId == userId && x.PetId == petId, cancellationToken);
        if (photo is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetPhotoNotFound);
        }

        photo.Status = normalized;
        photo.IsDeleted = normalized == "deleted";
        photo.DeletedAtUtc = photo.IsDeleted ? DateTime.UtcNow : null;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(await MapPhotoAsync(photo, photo.MediaAsset, cancellationToken));
    }

    private static string? NormalizeAdminStatus(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim().ToLowerInvariant();
        return ValidAdminStatuses.Contains(normalized) ? normalized : null;
    }
}
