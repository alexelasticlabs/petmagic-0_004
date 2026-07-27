using System.Net;
using System.Net.Http.Json;
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
    public async Task AdminGenerationRefundRetry_ShouldAcceptLegacyEmptyBodyAndEnforceIdempotencyConflict()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Admin Refund Recovery API",
            "Portrait",
            ["refund-recovery"]);
        var generationId = Guid.NewGuid();
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var now = DateTime.UtcNow.AddMinutes(-5);
            dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
            {
                Id = generationId,
                UserId = TestUserId,
                TemplateId = created.TemplateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = created.TokenCost,
                QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
                QueueTier = TemplateGenerationQueue.TierFree,
                SourceImageUrl = "https://cdn.example.com/refund-recovery-api.jpg",
                SourceImageFileName = "refund-recovery-api.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                UpdatedAtUtc = now,
                CompletedAtUtc = now,
                ChargedAtUtc = now,
                RefundAttemptCount = 5,
                RefundLastAttemptedAtUtc = now,
                RefundLastErrorCode = "economy.temporarily_unavailable"
            });
            await dbContext.SaveChangesAsync();
        }

        using var legacyRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"/api/admin/templates/generations/{generationId:D}/retry-refund");
        using var legacyResponse = await application.Client.SendAsync(legacyRequest);

        Assert.Equal(HttpStatusCode.OK, legacyResponse.StatusCode);

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var job = await dbContext.TemplateGenerationJobs.SingleAsync(item => item.Id == generationId);
            job.RefundAttemptCount = 5;
            job.RefundLastAttemptedAtUtc = DateTime.UtcNow;
            job.RefundLastErrorCode = "economy.temporarily_unavailable";
            await dbContext.SaveChangesAsync();
        }

        using var firstIdempotentRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"/api/admin/templates/generations/{generationId:D}/retry-refund")
        {
            Content = JsonContent.Create(new { reason = "Manual recovery after exhausted worker retries." })
        };
        firstIdempotentRequest.Headers.Add("Idempotency-Key", "refund-recovery-api:test");
        using var firstIdempotentResponse = await application.Client.SendAsync(firstIdempotentRequest);

        using var conflictingRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"/api/admin/templates/generations/{generationId:D}/retry-refund")
        {
            Content = JsonContent.Create(new { reason = "Different recovery payload." })
        };
        conflictingRequest.Headers.Add("Idempotency-Key", "refund-recovery-api:test");
        using var conflictingResponse = await application.Client.SendAsync(conflictingRequest);
        var conflictJson = JsonDocument.Parse(await conflictingResponse.Content.ReadAsStringAsync());

        Assert.Equal(HttpStatusCode.OK, firstIdempotentResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, conflictingResponse.StatusCode);
        Assert.Equal(
            "templates.generation_refund_retry_idempotency_conflict",
            conflictJson.RootElement.GetProperty("code").GetString());

        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            Assert.Equal(1, await dbContext.AdminGenerationRefundRetryReceipts.CountAsync());
        }
    }
}
