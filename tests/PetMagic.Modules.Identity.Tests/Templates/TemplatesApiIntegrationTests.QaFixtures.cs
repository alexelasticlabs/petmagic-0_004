using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task QaGenerationFixtures_ShouldReturnNotFound_WhenFlagDisabled()
    {
        await using var application = await TestApplication.CreateAsync(qaFixturesEnabled: false);
        var image = await CreateActiveImageTemplateAsync(application.Client, "QA Disabled Image", "QA", ["qa"]);

        using var response = await application.Client.PostAsJsonAsync(
            "/api/templates/qa/generation-fixtures",
            new
            {
                imageTemplateId = image.TemplateId,
                scenarios = new[] { "queued" }
            });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task QaGenerationFixtures_ShouldRequireAdminRole_WhenFlagEnabled()
    {
        await using var application = await TestApplication.CreateAsync(qaFixturesEnabled: true);
        var image = await CreateActiveImageTemplateAsync(application.Client, "QA Guard Image", "QA", ["qa"]);
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/templates/qa/generation-fixtures")
        {
            Content = JsonContent.Create(new
            {
                imageTemplateId = image.TemplateId,
                scenarios = new[] { "queued" }
            })
        };
        request.Headers.Add("X-Test-Role", "User");

        using var response = await application.Client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task QaGenerationFixtures_ShouldCreateDeterministicGenerationStatesAndCleanup()
    {
        await using var application = await TestApplication.CreateAsync(
            startGenerationWorker: true,
            qaFixturesEnabled: true);
        var image = await CreateActiveImageTemplateAsync(application.Client, "QA Image", "QA", ["qa"]);
        var videoTemplateId = await CreateActiveVideoTemplateAsync(application, "QA Video", "QA", ["qa"]);

        var fixtures = await PostAsJsonAsync<QaGenerationFixturesResponse>(
            application.Client,
            "/api/templates/qa/generation-fixtures",
            new
            {
                imageTemplateId = image.TemplateId,
                videoTemplateId,
                scenarios = new[] { "queued", "providerQueued", "providerProcessing", "importingMedia", "failed" }
            });

        Assert.Collection(
            fixtures.Generations.OrderBy(x => x.Status).ToArray(),
            item => Assert.Equal("Failed", item.Status),
            item => Assert.Equal("ImportingMedia", item.Status),
            item => Assert.Equal("ProviderProcessing", item.Status),
            item => Assert.Equal("ProviderQueued", item.Status),
            item => Assert.Equal("Queued", item.Status));

        var queued = fixtures.Generations.Single(x => x.Status == "Queued");
        Assert.True(queued.CanCancel);
        Assert.Contains(queued.GenerationId, application.Billing.ChargedGenerationIds);

        var providerQueued = fixtures.Generations.Single(x => x.Status == "ProviderQueued");
        Assert.False(providerQueued.CanCancel);
        using var cancelProvider = await application.Client.PostAsync(
            $"/api/templates/generations/{providerQueued.GenerationId}/cancel",
            null);
        Assert.Equal(HttpStatusCode.Conflict, cancelProvider.StatusCode);

        var cancel = await PostAsJsonAsync<CancelQueuedGenerationResponse>(
            application.Client,
            $"/api/templates/generations/{queued.GenerationId}/cancel",
            new { });
        Assert.Equal("Cancelled", cancel.Status);
        Assert.True(cancel.Refunded);
        Assert.Contains(queued.GenerationId, application.Billing.RefundedGenerationIds);

        var failed = fixtures.Generations.Single(x => x.Status == "Failed");
        Assert.Equal("templates.ai_provider_failed", failed.FailureCode);
        Assert.NotNull(failed.RefundedAtUtc);

        await Task.Delay(100);
        var importing = await GetFromJsonAsync<TemplateGenerationResponse>(
            application.Client,
            $"/api/templates/generations/{fixtures.Generations.Single(x => x.Status == "ImportingMedia").GenerationId}");
        Assert.Equal("ImportingMedia", importing.Status);
        Assert.False(importing.CanCancel);

        var fixtureIds = fixtures.Generations.Select(x => x.GenerationId).ToArray();
        await WaitForFixtureRealtimeEventsAsync(application, fixtureIds, expectedCount: fixtureIds.Length);

        using var cleanupResponse = await application.Client.DeleteAsync("/api/templates/qa/generation-fixtures");
        cleanupResponse.EnsureSuccessStatusCode();
        var cleanup = await ReadJsonAsync<QaGenerationFixtureCleanupResponse>(cleanupResponse);
        Assert.True(cleanup.DeletedGenerationJobs >= 5);
        Assert.True(cleanup.DeletedRealtimeEvents >= fixtureIds.Length);

        await using var cleanupScope = application.Services.CreateAsyncScope();
        var cleanupDbContext = cleanupScope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var remainingFixtureEvents = await CountFixtureRealtimeEventsAsync(cleanupDbContext, fixtureIds);
        Assert.Equal(0, remainingFixtureEvents);
    }

    [Fact]
    public async Task QaGenerationFixtures_ShouldCreateWaitTooLongBacklog_ForRealStartPathWithoutChargeOrJob()
    {
        await using var application = await TestApplication.CreateAsync(
            freeImageMaxEstimatedWaitSeconds: 1,
            startGenerationWorker: true,
            qaFixturesEnabled: true);
        var image = await CreateActiveImageTemplateAsync(application.Client, "QA Wait Image", "QA", ["qa"]);

        var beforeCharged = application.Billing.ChargedGenerationIds.Count;
        var fixtures = await PostAsJsonAsync<QaGenerationFixturesResponse>(
            application.Client,
            "/api/templates/qa/generation-fixtures",
            new
            {
                imageTemplateId = image.TemplateId,
                scenarios = new[] { "waitTooLongImage" }
            });

        var waitFixture = Assert.Single(fixtures.WaitTooLong);
        Assert.Equal("GENERATION_WAIT_TOO_LONG", waitFixture.ExpectedErrorCode);
        Assert.True(waitFixture.BacklogJobsCreated > 0);

        using var multipart = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(JpegBytes());
        fileContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg");
        multipart.Add(fileContent, "sourceImage", "pet.jpg");
        using var request = new HttpRequestMessage(HttpMethod.Post, $"/api/templates/{image.TemplateId}/generations")
        {
            Content = multipart
        };
        request.Headers.Add("X-Test-Role", "User");
        request.Headers.Add("X-Test-Premium", "false");
        using var response = await application.Client.SendAsync(request);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal("GENERATION_WAIT_TOO_LONG", body.RootElement.GetProperty("title").GetString());
        Assert.Equal("GENERATION_WAIT_TOO_LONG", body.RootElement.GetProperty("code").GetString());
        Assert.Equal("image", body.RootElement.GetProperty("mediaType").GetString());
        Assert.True(body.RootElement.GetProperty("estimatedWaitSeconds").GetInt32() > 1);
        Assert.Equal(beforeCharged, application.Billing.ChargedGenerationIds.Count);

        await using var scope = application.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var userActiveJobs = await dbContext.TemplateGenerationJobs.CountAsync(x =>
            x.UserId == TestUserId
            && TemplateGenerationJobStatusSets.Active.Contains(x.Status));
        Assert.Equal(0, userActiveJobs);
    }

    private static async Task<Guid> CreateActiveVideoTemplateAsync(TestApplication application, string title, string category, string[] tags)
    {
        await using var scope = application.Services.CreateAsyncScope();
        var service = scope.ServiceProvider.GetRequiredService<ITemplatesService>();
        var slug = title.ToLowerInvariant().Replace(' ', '-');
        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                title,
                $"{title} description",
                category,
                tags,
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                string.Empty,
                new TemplateAssetCommand($"https://cdn.example.com/{slug}.mp4", $"{slug}.mp4", "video/mp4", 1024, 7.0),
                new TemplateAssetCommand($"https://cdn.example.com/{slug}-reference.mp4", $"{slug}-reference.mp4", "video/mp4", 2048, 7.0),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/pro/motion-control",
                "Smooth cinematic motion.",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        return created.Value.TemplateId;
    }

    private static async Task WaitForFixtureRealtimeEventsAsync(
        TestApplication application,
        IReadOnlyCollection<Guid> generationIds,
        int expectedCount)
    {
        for (var attempt = 0; attempt < 20; attempt++)
        {
            await using var scope = application.Services.CreateAsyncScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var count = await CountFixtureRealtimeEventsAsync(dbContext, generationIds);
            if (count >= expectedCount)
            {
                return;
            }

            await Task.Delay(50);
        }

        await using var finalScope = application.Services.CreateAsyncScope();
        var finalDbContext = finalScope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var finalCount = await CountFixtureRealtimeEventsAsync(finalDbContext, generationIds);
        Assert.True(finalCount >= expectedCount);
    }

    private static async Task<int> CountFixtureRealtimeEventsAsync(
        TemplatesDbContext dbContext,
        IReadOnlyCollection<Guid> generationIds)
    {
        var generationIdStrings = generationIds.Select(x => x.ToString()).ToArray();
        var candidates = await dbContext.TemplateRealtimeEvents
            .Where(x => x.Topic == TemplateFeedRealtimeTopics.GenerationStatusChanged && x.Data != null)
            .Select(x => x.Data!)
            .ToArrayAsync();

        return candidates.Count(data =>
            generationIdStrings.Any(id => data.Contains(id, StringComparison.OrdinalIgnoreCase)));
    }
}
