using System.IO;

using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record CreatePetCommand(
    Guid UserId,
    string Name,
    string Type,
    string? Breed);

public sealed record UpdatePetCommand(
    Guid UserId,
    Guid PetId,
    string Name,
    string Type,
    string? Breed);

public sealed record UploadPetPhotoCommand(
    Guid UserId,
    Guid PetId,
    MediaUploadCommand Photo);

public sealed record SetPetPhotoFavoriteCommand(
    Guid UserId,
    Guid PetId,
    Guid PhotoId,
    bool IsFavorite);

public sealed record StoredMediaResponse(
    string Url,
    string StorageKey,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    string? LocalPath);

public sealed record PetPhotoResponse(
    Guid Id,
    Guid PetId,
    Guid MediaAssetId,
    string Url,
    string? ThumbnailUrl,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    bool IsFavorite,
    bool IsAvatar,
    int SortOrder,
    string Status,
    DateTime CreatedAtUtc,
    bool IsDeleted);

public sealed record PetResponse(
    Guid Id,
    Guid UserId,
    string Name,
    string Type,
    string? Breed,
    Guid? AvatarMediaAssetId,
    string? AvatarUrl,
    int PhotosCount,
    int GenerationsCount,
    string Status,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    bool IsDeleted);

public sealed record AdminPetResponse(
    Guid Id,
    Guid UserId,
    string Name,
    string Type,
    string? Breed,
    Guid? AvatarMediaAssetId,
    string? AvatarUrl,
    int PhotosCount,
    int GenerationsCount,
    string Status,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    bool IsDeleted);

public sealed record TemplateAssetResponse(
    string Url,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    double? DurationSeconds);

public sealed record TemplateMediaUploadResponse(
    string Url,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    double? DurationSeconds,
    TemplateAssetResponse? ThumbnailAsset = null,
    TemplateAssetResponse? AnimatedPreviewAsset = null,
    TemplateAssetResponse? FeedLoopLowAsset = null,
    TemplateAssetResponse? FeedLoopMediumAsset = null,
    TemplateAssetResponse? DetailPreviewAsset = null,
    bool WasOptimized = false);

public sealed record TemplatePreviewOptimizationResult(
    StoredMediaResponse PrimaryAsset,
    StoredMediaResponse? ThumbnailAsset,
    StoredMediaResponse? AnimatedPreviewAsset,
    StoredMediaResponse? FeedLoopLowAsset,
    StoredMediaResponse? FeedLoopMediumAsset,
    StoredMediaResponse? DetailPreviewAsset,
    bool WasOptimized);
