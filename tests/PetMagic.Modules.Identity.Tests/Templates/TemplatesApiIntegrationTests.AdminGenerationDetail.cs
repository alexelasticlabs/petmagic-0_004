using System.Net;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task AdminGenerationDetail_ShouldReturnSafeOperationalStateAndNotFound()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var template = await CreateActiveImageTemplateAsync(
            application.Client,
            "Admin Generation Detail API",
            "Portrait",
            ["generation-detail"]);
        var generationId = Guid.NewGuid();
        var now = DateTime.UtcNow.AddMinutes(-5);

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
            {
                Id = generationId,
                UserId = TestUserId,
                TemplateId = template.TemplateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = template.TokenCost,
                QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
                QueueTier = TemplateGenerationQueue.TierFree,
                SourceImageUrl = "https://cdn.example.com/admin-generation-detail.jpg",
                SourceImageFileName = "admin-generation-detail.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                UpdatedAtUtc = now,
                CompletedAtUtc = now,
                ChargedAtUtc = now,
                AttemptCount = 3,
                LastErrorCode = "provider.timeout",
                LastErrorMessage = "Provider request timed out. Secret payload must not be returned.",
                RefundAttemptCount = 5,
                RefundLastAttemptedAtUtc = now,
                RefundLastErrorCode = "economy.temporarily_unavailable"
            });
            await dbContext.SaveChangesAsync();
        }

        using var response = await application.Client.GetAsync(
            $"/api/admin/templates/generations/{generationId:D}");
        var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var generation = json.RootElement.GetProperty("generation");
        Assert.Equal(generationId, generation.GetProperty("generationId").GetGuid());
        Assert.Equal(3, generation.GetProperty("attemptCount").GetInt32());
        Assert.Equal("exhausted", generation.GetProperty("refundState").GetString());
        Assert.True(generation.GetProperty("canRetryRefund").GetBoolean());
        Assert.True(generation.GetProperty("canRetry").GetBoolean());
        Assert.False(generation.TryGetProperty("preprocessingProviderStatusUrl", out _));
        Assert.False(generation.TryGetProperty("motionProviderCancelUrl", out _));

        using var missingResponse = await application.Client.GetAsync(
            $"/api/admin/templates/generations/{Guid.NewGuid():D}");
        Assert.Equal(HttpStatusCode.NotFound, missingResponse.StatusCode);
    }
}
