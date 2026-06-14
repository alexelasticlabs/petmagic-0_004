using System.Diagnostics;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class PetsService(
    TemplatesDbContext dbContext,
    IMediaStorage mediaStorage,
    TemplatesOptions options,
    TemplateWatermarkSettingsStore? watermarkSettings = null) : IPetsService
{
    private static readonly HashSet<string> ValidPetTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "dog",
        "cat",
        "other"
    };

    private static readonly HashSet<string> ValidAdminStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "active",
        "hidden",
        "flagged",
        "deleted"
    };

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
                        && !photo.MediaAsset.IsDeleted
                        && photo.MediaAssetId == x.AvatarMediaAssetId)
                    .Select(photo => photo.ThumbnailUrl ?? photo.MediaAsset.Url)
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

    public async Task<Result<PetPhotoResponse>> AddPhotoAsync(UploadPetPhotoCommand command, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(command.UserId, command.PetId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetNotFound);
        }

        var photoId = Guid.NewGuid();
        var petPhotoUpload = command.Photo with
        {
            PreferredStorageKey = BuildPetPhotoStorageKey(command.UserId, command.PetId, photoId, command.Photo.ContentType)
        };
        var stored = await mediaStorage.StoreAsync(petPhotoUpload, cancellationToken);
        if (stored.IsFailure)
        {
            return Result.Failure<PetPhotoResponse>(stored.Error);
        }

        var thumbnail = await CreateThumbnailAsync(stored.Value, command.UserId, command.PetId, photoId, cancellationToken);

        var hasPhotos = await dbContext.PetPhotos
            .AnyAsync(x => x.UserId == command.UserId && x.PetId == command.PetId && !x.IsDeleted, cancellationToken);
        var nextSortOrder = await dbContext.PetPhotos
            .Where(x => x.UserId == command.UserId && x.PetId == command.PetId)
            .Select(x => (int?)x.SortOrder)
            .MaxAsync(cancellationToken) ?? 0;
        var now = DateTime.UtcNow;
        var media = new TemplateMediaRecord
        {
            Id = Guid.NewGuid(),
            UserId = command.UserId,
            MediaType = "image",
            StoragePath = stored.Value.StorageKey,
            PreviewUrl = thumbnail?.StorageKey,
            SourceType = "pet_photo",
            Url = stored.Value.Url,
            FileName = stored.Value.FileName,
            ContentType = stored.Value.ContentType,
            FileSizeBytes = stored.Value.FileSizeBytes,
            Role = TemplateMediaRole.GenerationSourceImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            UploadedAtUtc = now,
            AttachedAtUtc = now
        };
        var photo = new PetPhoto
        {
            Id = photoId,
            PetId = command.PetId,
            UserId = command.UserId,
            MediaAssetId = media.Id,
            MediaAsset = media,
            ThumbnailUrl = thumbnail?.Url,
            ThumbnailStoragePath = thumbnail?.StorageKey,
            IsAvatar = !hasPhotos,
            SortOrder = nextSortOrder + 1,
            CreatedAtUtc = now
        };

        if (!hasPhotos)
        {
            pet.AvatarMediaAssetId = media.Id;
        }

        pet.UpdatedAtUtc = now;
        dbContext.TemplateMediaRecords.Add(media);
        dbContext.PetPhotos.Add(photo);
        await AddPetAnalyticsEventAsync(
            pet,
            TemplateAnalyticsEventTypes.PhotoUploaded,
            petPhotoId: photo.Id,
            photosCountOverride: hasPhotos ? nextSortOrder + 1 : 1,
            cancellationToken: cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(await MapPhotoAsync(photo, media, cancellationToken));
    }

    public async Task<Result<IReadOnlyList<PetPhotoResponse>>> ListPhotosAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
    {
        if (!await dbContext.Pets.AnyAsync(
            x => x.Id == petId && x.UserId == userId && !x.IsDeleted && x.Status == "active",
            cancellationToken))
        {
            return Result.Failure<IReadOnlyList<PetPhotoResponse>>(TemplatesErrors.PetNotFound);
        }

        var photos = await dbContext.PetPhotos
            .AsNoTracking()
            .Include(x => x.MediaAsset)
            .Where(x => x.UserId == userId && x.PetId == petId && !x.IsDeleted && x.Status == "active" && !x.MediaAsset.IsDeleted)
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

    public async Task<Result<PetPhotoResponse>> SetAvatarAsync(Guid userId, Guid petId, Guid photoId, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(userId, petId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetNotFound);
        }

        var photo = await FindActivePhotoAsync(userId, petId, photoId, cancellationToken);
        if (photo is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetPhotoNotFound);
        }

        await dbContext.PetPhotos
            .Where(x => x.UserId == userId && x.PetId == petId && !x.IsDeleted)
            .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.IsAvatar, x => x.Id == photoId), cancellationToken);
        pet.AvatarMediaAssetId = photo.MediaAssetId;
        pet.UpdatedAtUtc = DateTime.UtcNow;
        await AddPetAnalyticsEventAsync(
            pet,
            TemplateAnalyticsEventTypes.PhotoSetAvatar,
            petPhotoId: photo.Id,
            cancellationToken: cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        photo.IsAvatar = true;
        return Result.Success(await MapPhotoAsync(photo, photo.MediaAsset, cancellationToken));
    }

    public async Task<Result<PetPhotoResponse>> SetFavoriteAsync(SetPetPhotoFavoriteCommand command, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(command.UserId, command.PetId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetNotFound);
        }

        var photo = await FindActivePhotoAsync(command.UserId, command.PetId, command.PhotoId, cancellationToken);
        if (photo is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetPhotoNotFound);
        }

        photo.IsFavorite = command.IsFavorite;
        await AddPetAnalyticsEventAsync(
            pet,
            TemplateAnalyticsEventTypes.PhotoFavorited,
            petPhotoId: photo.Id,
            cancellationToken: cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(await MapPhotoAsync(photo, photo.MediaAsset, cancellationToken));
    }

    public async Task<Result> DeletePhotoAsync(Guid userId, Guid petId, Guid photoId, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(userId, petId, cancellationToken);
        var photo = await FindActivePhotoAsync(userId, petId, photoId, cancellationToken);
        if (pet is null || photo is null)
        {
            return Result.Failure(TemplatesErrors.PetPhotoNotFound);
        }

        photo.IsDeleted = true;
        photo.Status = "deleted";
        photo.DeletedAtUtc = DateTime.UtcNow;
        photo.IsAvatar = false;
        photo.MediaAsset.IsDeleted = true;
        photo.MediaAsset.DeletedAtUtc = photo.DeletedAtUtc;
        photo.MediaAsset.LifecycleState = TemplateMediaLifecycleState.Deleted;

        if (pet.AvatarMediaAssetId == photo.MediaAssetId)
        {
            var replacement = await ResolveBestPhotoAsync(userId, petId, excludePhotoId: photoId, cancellationToken);
            pet.AvatarMediaAssetId = replacement?.MediaAssetId;
            if (replacement is not null)
            {
                replacement.IsAvatar = true;
            }
        }

        pet.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListGenerationsAsync(Guid userId, Guid petId, bool isPremium, CancellationToken cancellationToken)
    {
        if (!await dbContext.Pets.AnyAsync(
            x => x.Id == petId && x.UserId == userId && !x.IsDeleted && x.Status == "active",
            cancellationToken))
        {
            return Result.Failure<IReadOnlyList<TemplateGenerationResponse>>(TemplatesErrors.PetNotFound);
        }

        var generations = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .Where(x => x.UserId == userId && x.PetId == petId && x.HiddenByUserAtUtc == null)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(50)
            .ToArrayAsync(cancellationToken);

        var cost = Math.Max(1, (watermarkSettings ?? new TemplateWatermarkSettingsStore(options)).Current.CostCredits);
        var mapped = new List<TemplateGenerationResponse>(generations.Length);
        foreach (var generation in generations)
        {
            var response = TemplateGenerationService.ApplyWatermarkAccess(
                TemplateGenerationService.MapResponse(generation),
                generation,
                isPremium,
                generation.WatermarkUnlocks.Any(unlock => unlock.UserId == userId),
                cost);
            mapped.Add(await TemplateGenerationService.SignUserMediaUrlsAsync(
                mediaStorage,
                options,
                response,
                cancellationToken));
        }

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>(mapped);
    }

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
                    .Select(photo => photo.ThumbnailUrl ?? photo.MediaAsset.Url)
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

    private async Task<PetResponse> BuildPetResponseAsync(Pet pet, CancellationToken cancellationToken)
    {
        var photosCount = await dbContext.PetPhotos.CountAsync(x => x.PetId == pet.Id && !x.IsDeleted, cancellationToken);
        var generationsCount = await dbContext.TemplateGenerationJobs.CountAsync(x => x.PetId == pet.Id, cancellationToken);
        var avatarUrl = await dbContext.PetPhotos
            .Where(x => x.PetId == pet.Id && !x.IsDeleted && x.MediaAssetId == pet.AvatarMediaAssetId)
            .Select(x => x.ThumbnailStoragePath ?? x.ThumbnailUrl ?? x.MediaAsset.StoragePath ?? x.MediaAsset.Url)
            .FirstOrDefaultAsync(cancellationToken);
        return await MapPetAsync(pet, photosCount, generationsCount, avatarUrl, cancellationToken);
    }

    private async Task<PetResponse> MapPetAsync(Pet pet, int photosCount, int generationsCount, string? avatarUrl, CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(avatarUrl))
        {
            var signed = await mediaStorage.CreateReadUrlAsync(
                avatarUrl,
                TimeSpan.FromSeconds(options.UserMediaReadUrlTtlSeconds),
                cancellationToken);
            avatarUrl = signed.IsSuccess ? signed.Value : avatarUrl;
        }

        return new PetResponse(
            pet.Id,
            pet.UserId,
            pet.Name,
            pet.Type,
            pet.Breed,
            pet.AvatarMediaAssetId,
            avatarUrl,
            photosCount,
            generationsCount,
            pet.Status,
            pet.CreatedAtUtc,
            pet.UpdatedAtUtc,
            pet.IsDeleted);
    }

    private async Task<PetPhotoResponse> MapPhotoAsync(PetPhoto photo, TemplateMediaRecord media, CancellationToken cancellationToken)
    {
        var url = string.IsNullOrWhiteSpace(media.StoragePath) ? media.Url : media.StoragePath;
        var signed = await mediaStorage.CreateReadUrlAsync(
            url,
            TimeSpan.FromSeconds(options.UserMediaReadUrlTtlSeconds),
            cancellationToken);
        if (signed.IsSuccess)
        {
            url = signed.Value;
        }

        string? thumbnailUrl = photo.ThumbnailStoragePath ?? photo.ThumbnailUrl;
        if (!string.IsNullOrWhiteSpace(thumbnailUrl))
        {
            var signedThumbnail = await mediaStorage.CreateReadUrlAsync(
                thumbnailUrl,
                TimeSpan.FromSeconds(options.UserMediaReadUrlTtlSeconds),
                cancellationToken);
            if (signedThumbnail.IsSuccess)
            {
                thumbnailUrl = signedThumbnail.Value;
            }
        }

        return new PetPhotoResponse(
            photo.Id,
            photo.PetId,
            photo.MediaAssetId,
            url,
            thumbnailUrl,
            media.FileName,
            media.ContentType,
            media.FileSizeBytes,
            photo.IsFavorite,
            photo.IsAvatar,
            photo.SortOrder,
            photo.Status,
            photo.CreatedAtUtc,
            photo.IsDeleted);
    }

    private Task<Pet?> FindActivePetAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
    {
        return dbContext.Pets.FirstOrDefaultAsync(
            x => x.Id == petId && x.UserId == userId && !x.IsDeleted && x.Status == "active",
            cancellationToken);
    }

    private Task<PetPhoto?> FindActivePhotoAsync(Guid userId, Guid petId, Guid photoId, CancellationToken cancellationToken)
    {
        return dbContext.PetPhotos
            .Include(x => x.MediaAsset)
            .FirstOrDefaultAsync(
                x => x.Id == photoId
                    && x.PetId == petId
                    && x.UserId == userId
                    && !x.IsDeleted
                    && x.Status == "active"
                    && !x.MediaAsset.IsDeleted,
                cancellationToken);
    }

    private Task<PetPhoto?> ResolveBestPhotoAsync(Guid userId, Guid petId, Guid? excludePhotoId, CancellationToken cancellationToken)
    {
        var query = dbContext.PetPhotos
            .Include(x => x.MediaAsset)
            .Where(x => x.UserId == userId
                && x.PetId == petId
                && !x.IsDeleted
                && x.Status == "active"
                && !x.MediaAsset.IsDeleted);

        if (excludePhotoId is not null)
        {
            query = query.Where(x => x.Id != excludePhotoId.Value);
        }

        return query
            .OrderByDescending(x => x.IsFavorite)
            .ThenByDescending(x => x.IsAvatar)
            .ThenByDescending(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task AddPetAnalyticsEventAsync(
        Pet pet,
        string eventType,
        Guid? petPhotoId = null,
        Guid? templateId = null,
        Guid? generationId = null,
        int? photosCountOverride = null,
        string userPlan = "unknown",
        string sourceScreen = "api",
        CancellationToken cancellationToken = default)
    {
        var photosCount = photosCountOverride
            ?? await dbContext.PetPhotos.CountAsync(
                x => x.UserId == pet.UserId && x.PetId == pet.Id && !x.IsDeleted,
                cancellationToken);

        dbContext.PetAnalyticsEvents.Add(new PetAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            UserId = pet.UserId,
            PetId = pet.Id,
            PetPhotoId = petPhotoId,
            TemplateId = templateId,
            GenerationId = generationId,
            EventType = eventType,
            PetType = pet.Type,
            PhotosCount = photosCount,
            UserPlan = userPlan,
            SourceScreen = sourceScreen,
            CreatedAtUtc = DateTime.UtcNow
        });
    }

    private static string? NormalizeType(string value)
    {
        var normalized = value.Trim().ToLowerInvariant();
        return ValidPetTypes.Contains(normalized) ? normalized : null;
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

    private static string? NormalizeOptional(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static string BuildPetPhotoStorageKey(Guid userId, Guid petId, Guid photoId, string contentType)
    {
        var extension = NormalizeContentType(contentType) switch
        {
            "image/jpeg" or "image/jpg" => ".jpg",
            "image/png" => ".png",
            "image/webp" => ".webp",
            "image/heic" => ".heic",
            "image/heif" => ".heif",
            _ => Path.GetExtension($"upload-{photoId:N}.jpg")
        };

        return $"users/{userId:N}/pets/{petId:N}/photos/{photoId:N}/original{extension}";
    }

    private static string BuildPetPhotoThumbnailStorageKey(Guid userId, Guid petId, Guid photoId)
    {
        return $"users/{userId:N}/pets/{petId:N}/photos/{photoId:N}/thumbnail.webp";
    }

    private async Task<StoredMediaResponse?> CreateThumbnailAsync(
        StoredMediaResponse original,
        Guid userId,
        Guid petId,
        Guid photoId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(original.LocalPath) || !File.Exists(original.LocalPath))
        {
            return null;
        }

        try
        {
            await using var input = File.OpenRead(original.LocalPath);
            using var image = await Image.LoadAsync(input, cancellationToken);
            image.Mutate(context => context.Resize(new ResizeOptions
            {
                Size = new Size(360, 360),
                Mode = ResizeMode.Max
            }));

            await using var output = new MemoryStream();
            await image.SaveAsWebpAsync(output, new WebpEncoder { Quality = 78 }, cancellationToken);
            output.Position = 0;

            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    $"pet-thumbnail-{photoId:N}.webp",
                    "image/webp",
                    null,
                    output,
                    output.Length,
                    BuildPetPhotoThumbnailStorageKey(userId, petId, photoId)),
                cancellationToken);

            return stored.IsSuccess ? stored.Value : null;
        }
        catch (NotSupportedException)
        {
            return await CreateHeicThumbnailWithExternalToolsAsync(original, userId, petId, photoId, cancellationToken);
        }
        catch (InvalidImageContentException)
        {
            return await CreateHeicThumbnailWithExternalToolsAsync(original, userId, petId, photoId, cancellationToken);
        }
        catch (UnknownImageFormatException)
        {
            return await CreateHeicThumbnailWithExternalToolsAsync(original, userId, petId, photoId, cancellationToken);
        }
    }

    private async Task<StoredMediaResponse?> CreateHeicThumbnailWithExternalToolsAsync(
        StoredMediaResponse original,
        Guid userId,
        Guid petId,
        Guid photoId,
        CancellationToken cancellationToken)
    {
        if (!string.Equals(original.ContentType, "image/heic", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(original.ContentType, "image/heif", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return await CreateHeicThumbnailWithFfmpegAsync(original, userId, petId, photoId, cancellationToken)
            ?? await CreateHeicThumbnailWithSipsAsync(original, userId, petId, photoId, cancellationToken);
    }

    private async Task<StoredMediaResponse?> CreateHeicThumbnailWithFfmpegAsync(
        StoredMediaResponse original,
        Guid userId,
        Guid petId,
        Guid photoId,
        CancellationToken cancellationToken)
    {
        var tempOutput = Path.Combine(Path.GetTempPath(), $"petmagic-pet-thumbnail-{photoId:N}.webp");
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = options.Watermark.FfmpegPath,
                    RedirectStandardError = true,
                    RedirectStandardOutput = true,
                    UseShellExecute = false
                }
            };
            process.StartInfo.ArgumentList.Add("-y");
            process.StartInfo.ArgumentList.Add("-i");
            process.StartInfo.ArgumentList.Add(original.LocalPath!);
            process.StartInfo.ArgumentList.Add("-vf");
            process.StartInfo.ArgumentList.Add("scale=w='min(360,iw)':h=-2");
            process.StartInfo.ArgumentList.Add("-frames:v");
            process.StartInfo.ArgumentList.Add("1");
            process.StartInfo.ArgumentList.Add("-quality");
            process.StartInfo.ArgumentList.Add("78");
            process.StartInfo.ArgumentList.Add(tempOutput);

            process.Start();
            await process.WaitForExitAsync(cancellationToken);
            if (process.ExitCode != 0 || !File.Exists(tempOutput) || new FileInfo(tempOutput).Length == 0)
            {
                return null;
            }

            await using var output = File.OpenRead(tempOutput);
            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    $"pet-thumbnail-{photoId:N}.webp",
                    "image/webp",
                    null,
                    output,
                    output.Length,
                    BuildPetPhotoThumbnailStorageKey(userId, petId, photoId)),
                cancellationToken);

            return stored.IsSuccess ? stored.Value : null;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch
        {
            return null;
        }
        finally
        {
            TryDelete(tempOutput);
        }
    }

    private async Task<StoredMediaResponse?> CreateHeicThumbnailWithSipsAsync(
        StoredMediaResponse original,
        Guid userId,
        Guid petId,
        Guid photoId,
        CancellationToken cancellationToken)
    {
        var sipsPath = OperatingSystem.IsMacOS() ? "/usr/bin/sips" : "sips";
        var tempPng = Path.Combine(Path.GetTempPath(), $"petmagic-pet-thumbnail-{photoId:N}.png");
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = sipsPath,
                    RedirectStandardError = true,
                    RedirectStandardOutput = true,
                    UseShellExecute = false
                }
            };
            process.StartInfo.ArgumentList.Add("-s");
            process.StartInfo.ArgumentList.Add("format");
            process.StartInfo.ArgumentList.Add("png");
            process.StartInfo.ArgumentList.Add("-Z");
            process.StartInfo.ArgumentList.Add("360");
            process.StartInfo.ArgumentList.Add(original.LocalPath!);
            process.StartInfo.ArgumentList.Add("--out");
            process.StartInfo.ArgumentList.Add(tempPng);

            process.Start();
            await process.WaitForExitAsync(cancellationToken);
            if (process.ExitCode != 0 || !File.Exists(tempPng) || new FileInfo(tempPng).Length == 0)
            {
                return null;
            }

            await using var input = File.OpenRead(tempPng);
            using var image = await Image.LoadAsync(input, cancellationToken);
            await using var output = new MemoryStream();
            await image.SaveAsWebpAsync(output, new WebpEncoder { Quality = 78 }, cancellationToken);
            output.Position = 0;

            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    $"pet-thumbnail-{photoId:N}.webp",
                    "image/webp",
                    null,
                    output,
                    output.Length,
                    BuildPetPhotoThumbnailStorageKey(userId, petId, photoId)),
                cancellationToken);

            return stored.IsSuccess ? stored.Value : null;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch
        {
            return null;
        }
        finally
        {
            TryDelete(tempPng);
        }
    }

    private static void TryDelete(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return;
        }

        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
            // Best-effort temp cleanup.
        }
    }

    private static string NormalizeContentType(string contentType)
    {
        return contentType.Trim().ToLowerInvariant();
    }

    private sealed record PetListProjection(Pet Pet, int PhotosCount, int GenerationsCount, string? AvatarUrl);
}
