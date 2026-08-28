using System.Net;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task CreateImageAsync_ShouldQueueOneLocalizationMessageForEachSupportedLocale()
    {
        await using var dbContext = CreateDbContext();
        var options = CreateTemplatesServiceOptions();
        var service = CreateService(dbContext, templatesOptions: options);

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Big Boss",
                "An English template description.",
                "Portrait",
                ["funny"],
                false,
                0,
                TemplatePromoBadgeMode.New.ToString(),
                null,
                string.Empty,
                string.Empty,
                TemplateStatus.Draft.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess, created.Error.Code);
        var templateId = created.Value.TemplateId;

        var queued = await dbContext.PushOutboxMessages
            .Where(message => message.Kind == TemplateLocalizationOutbox.Kind)
            .OrderBy(message => message.DeduplicationKey)
            .ToArrayAsync();

        Assert.Equal(options.SupportedLocalizationLocales.Length, queued.Length);
        Assert.All(queued, message => Assert.Equal(PushOutboxStatus.Queued, message.Status));
        Assert.Equal(
            options.SupportedLocalizationLocales.Order(StringComparer.OrdinalIgnoreCase),
            queued.Select(message => ReadTargetLocale(message.PayloadJson)).Order(StringComparer.OrdinalIgnoreCase));
        Assert.All(queued, message => Assert.Contains(templateId.ToString("N"), message.DeduplicationKey, StringComparison.Ordinal));
    }

    [Fact]
    public async Task CreateImageAsync_ShouldNotQueueLocalizationForNameOnlyDraft()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext, templatesOptions: CreateTemplatesServiceOptions());

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Unfinished draft",
                string.Empty,
                string.Empty,
                [],
                false,
                0,
                TemplatePromoBadgeMode.New.ToString(),
                null,
                string.Empty,
                string.Empty,
                TemplateStatus.Draft.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess, created.Error.Code);
        Assert.Empty(await dbContext.PushOutboxMessages.ToListAsync());
    }

    [Fact]
    public async Task LocalizationBackfill_ShouldQueueOnlyMissingLocales()
    {
        await using var dbContext = CreateDbContext();
        var options = CreateTemplatesServiceOptions(supportedLocalizationLocales: ["ru", "de"]);
        var template = CreateLocalizationTemplate("Big Boss");
        template.LocalizedTextsJson = System.Text.Json.JsonSerializer.Serialize(new Dictionary<string, TemplateLocalizationTranslator.TemplateLocalizedTexts>
        {
            ["ru"] = new("Босс", "Описание", ["Один питомец"], null, null, null)
        });
        dbContext.TemplateItems.Add(template);

        await TemplateLocalizationOutbox.EnqueueForTemplateAsync(
            dbContext,
            template,
            options,
            CancellationToken.None,
            onlyMissingTranslations: true);
        await dbContext.SaveChangesAsync();

        var message = await dbContext.PushOutboxMessages.SingleAsync();
        Assert.Equal("de", ReadTargetLocale(message.PayloadJson));
    }

    [Fact]
    public async Task LocalizationOutboxProcessor_ShouldSaveLocalizedTextAndInvalidateCatalog()
    {
        await using var dbContext = CreateDbContext();
        var options = CreateTemplatesServiceOptions(supportedLocalizationLocales: ["ru"]);
        var template = CreateLocalizationTemplate("Big Boss");
        dbContext.TemplateItems.Add(template);
        await TemplateLocalizationOutbox.EnqueueForTemplateAsync(dbContext, template, options, CancellationToken.None);
        await dbContext.SaveChangesAsync();
        var realtime = new RecordingTemplateFeedRealtimeService();
        using var httpClient = new HttpClient(new FixedTranslationHandler(HttpStatusCode.OK));
        var processor = new TemplatePushOutboxProcessor(
            dbContext,
            new NoopTemplatePushDeliverySender(),
            NullLogger<TemplatePushOutboxProcessor>.Instance,
            options,
            new FixedHttpClientFactory(httpClient),
            realtime);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));

        var message = await dbContext.PushOutboxMessages.SingleAsync();
        var persisted = await dbContext.TemplateItems.SingleAsync(item => item.Id == template.Id);
        var localized = TemplateLocalizationTranslator.Resolve(
            persisted.Title,
            persisted.ShortDescription,
            persisted.LocalizedTextsJson,
            "ru",
            musicDescription: persisted.MusicDescription);

        Assert.Equal(PushOutboxStatus.Sent, message.Status);
        Assert.Equal("Перевод", localized.Title);
        Assert.Equal("Перевод", localized.ShortDescription);
        Assert.Equal("Перевод", localized.MusicDescription);
        Assert.Equal(["Перевод", "Перевод"], localized.PetPhotoRequirements);
        Assert.Equal(1, persisted.Version);
        Assert.Single(await dbContext.TemplateCatalogChanges.ToListAsync());
        Assert.Equal(1, realtime.InvalidatedCount);
    }

    [Fact]
    public async Task LocalizationOutboxProcessor_ShouldDiscardStaleTranslationAfterSourceEdit()
    {
        await using var dbContext = CreateDbContext();
        var options = CreateTemplatesServiceOptions(supportedLocalizationLocales: ["ru"]);
        var template = CreateLocalizationTemplate("Original title");
        dbContext.TemplateItems.Add(template);
        await TemplateLocalizationOutbox.EnqueueForTemplateAsync(dbContext, template, options, CancellationToken.None);
        await dbContext.SaveChangesAsync();
        template.Title = "Updated title";
        await dbContext.SaveChangesAsync();
        using var httpClient = new HttpClient(new FixedTranslationHandler(HttpStatusCode.OK));
        var realtime = new RecordingTemplateFeedRealtimeService();
        var processor = new TemplatePushOutboxProcessor(
            dbContext,
            new NoopTemplatePushDeliverySender(),
            NullLogger<TemplatePushOutboxProcessor>.Instance,
            options,
            new FixedHttpClientFactory(httpClient),
            realtime);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));

        var message = await dbContext.PushOutboxMessages.SingleAsync();
        var persisted = await dbContext.TemplateItems.SingleAsync(item => item.Id == template.Id);

        Assert.Equal(PushOutboxStatus.Sent, message.Status);
        Assert.Null(persisted.LocalizedTextsJson);
        Assert.Empty(await dbContext.TemplateCatalogChanges.ToListAsync());
        Assert.Equal(0, realtime.InvalidatedCount);
    }

    private static TemplateItem CreateLocalizationTemplate(string title)
    {
        var now = DateTime.UtcNow;
        return new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Video,
            Title = title,
            ShortDescription = "An English template description.",
            PetPhotoRequirements = "One pet\nClear face",
            Category = "Funny",
            Tags = "funny",
            TokenCost = 20,
            Status = TemplateStatus.Active,
            PromoBadgeMode = TemplatePromoBadgeMode.New,
            PreprocessingModel = "openai/gpt-image-2/edit",
            PreprocessingPrompt = "Keep the pet recognizable.",
            KlingModel = "fal-ai/kling-video/v3/pro/motion-control",
            KlingPrompt = "Make a playful entrance.",
            MusicDescription = "Upbeat pop music.",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
    }

    private static string ReadTargetLocale(string payloadJson)
    {
        using var document = System.Text.Json.JsonDocument.Parse(payloadJson);
        return document.RootElement.GetProperty("targetLocale").GetString()!;
    }

    private sealed class NoopTemplatePushDeliverySender : ITemplateGenerationPushDeliverySender
    {
        public Task<PushDeliveryResult> DeliverGenerationTerminalAsync(
            TemplateGenerationResponse generation,
            CancellationToken cancellationToken) => Task.FromResult(PushDeliveryResult.Delivered);
    }

    private sealed class FixedTranslationHandler(HttpStatusCode statusCode) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(statusCode)
            {
                Content = new StringContent("[[[\"Перевод\",\"source\",null,null,3]]]")
            });
        }
    }
}
