using System.Linq;

using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.PixelFormats;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ListPetsAsync_ShouldUseFirstActivePhotoOriginalAsAvatarFallback()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var mediaId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.Pets.Add(new Pet
        {
            Id = petId,
            UserId = userId,
            Name = "Milo",
            Type = "dog",
            Breed = "Corgi",
            Status = "active",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        dbContext.TemplateMediaRecords.Add(new TemplateMediaRecord
        {
            Id = mediaId,
            UserId = userId,
            MediaType = "image",
            StoragePath = "users/pets/milo/original.jpg",
            Url = "https://cdn.petmagic.test/milo-original.jpg",
            FileName = "milo.jpg",
            ContentType = "image/jpeg",
            FileSizeBytes = 512,
            SourceType = "pet_photo",
            Role = TemplateMediaRole.GenerationSourceImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            UploadedAtUtc = now,
            AttachedAtUtc = now
        });
        dbContext.PetPhotos.Add(new PetPhoto
        {
            Id = Guid.NewGuid(),
            PetId = petId,
            UserId = userId,
            MediaAssetId = mediaId,
            ThumbnailStoragePath = "users/pets/milo/thumb.webp",
            Status = "active",
            SortOrder = 1,
            CreatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var storage = new RecordingMediaStorage(signReadUrls: true);
        var service = new PetsService(dbContext, storage, CreateTemplatesOptions(), NullLogger<PetsService>.Instance);

        var result = await service.ListAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var pet = Assert.Single(result.Value);
        Assert.Equal("https://cdn.petmagic.test/milo-original.jpg?signed=1", pet.AvatarUrl);
        Assert.Equal(["https://cdn.petmagic.test/milo-original.jpg"], storage.ReadUrls);
        Assert.Equal(1, pet.PhotosCount);
    }

    [Fact]
    public async Task ListPetsAsync_ShouldSuppressUnsafeExternalAvatarUrl()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var mediaId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.Pets.Add(new Pet
        {
            Id = petId,
            UserId = userId,
            Name = "Milo",
            Type = "dog",
            Breed = "Corgi",
            Status = "active",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        dbContext.TemplateMediaRecords.Add(new TemplateMediaRecord
        {
            Id = mediaId,
            UserId = userId,
            MediaType = "image",
            StoragePath = string.Empty,
            Url = "https://tracker.example.com/milo-original.jpg",
            FileName = "milo.jpg",
            ContentType = "image/jpeg",
            FileSizeBytes = 512,
            SourceType = "pet_photo",
            Role = TemplateMediaRole.GenerationSourceImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            UploadedAtUtc = now,
            AttachedAtUtc = now
        });
        dbContext.PetPhotos.Add(new PetPhoto
        {
            Id = Guid.NewGuid(),
            PetId = petId,
            UserId = userId,
            MediaAssetId = mediaId,
            Status = "active",
            SortOrder = 1,
            CreatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var storage = new RejectingReadUrlMediaStorage();
        var service = new PetsService(dbContext, storage, CreateTemplatesOptions(), NullLogger<PetsService>.Instance);

        var result = await service.ListAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var pet = Assert.Single(result.Value);
        Assert.Null(pet.AvatarUrl);
        Assert.Equal(["https://tracker.example.com/milo-original.jpg"], storage.ReadUrls);
    }

    [Fact]
    public async Task AddPhotoAsync_ShouldNormalizeDecodableImageBeforeStorage()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.Pets.Add(new Pet
        {
            Id = petId,
            UserId = userId,
            Name = "Nora",
            Type = "cat",
            Breed = "British",
            Status = "active",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var storage = new RecordingMediaStorage();
        var service = new PetsService(
            dbContext,
            storage,
            CreateTemplatesOptions(),
            NullLogger<PetsService>.Instance);

        var result = await service.AddPhotoAsync(
            new UploadPetPhotoCommand(
                userId,
                petId,
                new MediaUploadCommand("nora.png", "image/png", PngBytes())),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var stored = Assert.Single(storage.StoredAssets);
        Assert.Equal("image/jpeg", stored.ContentType);
        Assert.NotNull(stored.Content);
        Assert.Equal((byte)0xFF, stored.Content![0]);
        Assert.Equal((byte)0xD8, stored.Content[1]);
        Assert.Equal((byte)0xFF, stored.Content[2]);
        using var normalized = Image.Load(stored.Content);
        Assert.Equal(2048, normalized.Width);
        Assert.Equal(1536, normalized.Height);
    }

    private static byte[] PngBytes()
    {
        using var image = new Image<Rgba32>(3200, 2400);
        for (var y = 0; y < image.Height; y++)
        {
            for (var x = 0; x < image.Width; x++)
            {
                image[x, y] = new Rgba32(
                    (byte)((x * 31 + y * 17) & 0xFF),
                    (byte)((x * 13 + y * 29) & 0xFF),
                    (byte)((x * 7 + y * 19) & 0xFF));
            }
        }

        using var buffer = new MemoryStream();
        image.Save(buffer, new PngEncoder());
        return buffer.ToArray();
    }

    private sealed class RejectingReadUrlMediaStorage : IMediaStorage
    {
        public List<string> ReadUrls { get; } = [];

        public Task<PetMagic.BuildingBlocks.Results.Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            throw new NotSupportedException();
        }

        public Task<PetMagic.BuildingBlocks.Results.Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            throw new NotSupportedException();
        }

        public Task<PetMagic.BuildingBlocks.Results.Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            ReadUrls.Add(assetUrl);
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Failure<string>(TemplatesErrors.MediaStorageFailed));
        }
    }
}
