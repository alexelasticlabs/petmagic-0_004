using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FakeGeneratedMediaImporter(IMediaStorage mediaStorage) : IGeneratedMediaImporter
{
    private static readonly byte[] Png1x1 = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAANSURBVBhXY/j///9/AAn7A/0FQ0XKAAAAAElFTkSuQmCC");

    private static readonly byte[] Mp4Header =
    [
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D,
        0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D,
        0x69, 0x73, 0x6F, 0x32
    ];

    public Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
    {
        return mediaStorage.StoreAsync(
            new MediaUploadCommand(
                $"generated-{generationId:N}.mp4",
                "video/mp4",
                Mp4Header,
                ContentStream: null,
                ContentLengthBytes: Mp4Header.LongLength,
                PreferredStorageKey: $"generations/{generationId:N}/original.mp4"),
            cancellationToken);
    }

    public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
    {
        return mediaStorage.StoreAsync(
            new MediaUploadCommand(
                $"generated-{generationId:N}.png",
                "image/png",
                Png1x1,
                ContentStream: null,
                ContentLengthBytes: Png1x1.LongLength,
                PreferredStorageKey: $"generations/{generationId:N}/original.png"),
            cancellationToken);
    }
}
