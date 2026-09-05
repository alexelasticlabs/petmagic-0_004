using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task DiscoveryAdmin_ShouldPublishPreviewPreserveLegacyFieldsAndRestoreImmutableRevision()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = await CreateSqliteDbContextAsync(connection);
        var templates = CreateService(db);
        var firstId = await CreateActiveImageTemplateAsync(templates, "First", "Funny", ["discovery"]);
        var secondId = await CreateActiveImageTemplateAsync(templates, "Second", "Funny", ["discovery"]);
        var admin = new TemplateDiscoveryAdminService(db);
        var actor = Guid.NewGuid();
        var draft = (await admin.CreateDraftAsync(actor, new(0), default)).Value;
        var section = Assert.Single(draft.Document.Sections) with
        {
            HeroTemplateId = firstId,
            SelectionMode = "Manual",
            TemplateIds = [secondId],
            Copy = new Dictionary<string, DiscoveryCopy> { ["en"] = new("Fun", ""), ["ru"] = new("Веселье", "") }
        };
        var saved = (await admin.SaveDraftAsync(actor, draft.Id, new(draft.EditVersion,
            draft.Document with { Sections = [section] }), default)).Value;
        var preview = (await admin.PreviewAsync(saved.Id, "ru-RU", default)).Value;
        Assert.Equal("Веселье", Assert.Single(preview.Sections).Title);
        var request = new PublishDiscoveryRequest(saved.EditVersion, 1, "Launch discovery");
        var published = await admin.PublishAsync(actor, saved.Id, "publish-1", request, default);
        Assert.True(published.IsSuccess);
        var replay = await admin.PublishAsync(actor, saved.Id, "publish-1", request, default);
        Assert.Equal(published.Value.Id, replay.Value.Id);
        Assert.Equal(published.Value.EditVersion, replay.Value.EditVersion);
        Assert.Equal(TemplateDiscoveryDocument.Serialize(published.Value.Document), TemplateDiscoveryDocument.Serialize(replay.Value.Document));
        Assert.Single(await db.TemplateDiscoveryCommandReceipts.ToArrayAsync());
        Assert.Single(await db.TemplateRealtimeEvents.Where(row => row.Data!.Contains("discovery_published")).ToArrayAsync());
        Assert.Equal(3, await db.PushOutboxMessages.CountAsync(row => row.Kind == "admin_audit" && row.PayloadJson.Contains("templates.discovery.")));
        var publicResult = (await templates.ListPublicDiscoveryAsync(new(6, 12, "ru"), default)).Value;
        Assert.Equal(1, publicResult.Revision);
        Assert.Equal("Funny", publicResult.Sections[0].Category);
        Assert.Equal(new[] { firstId, secondId }, publicResult.Sections[0].Items.Select(item => item.Id));
        Assert.Equal(preview.Sections[0].Items.Select(item => item.Id), publicResult.Sections[0].Items.Select(item => item.Id));
        Assert.Equal("discovery.conflict", (await admin.SaveDraftAsync(actor, saved.Id, new(published.Value.EditVersion, saved.Document), default)).Error.Code);
        Assert.Equal("discovery.conflict", (await admin.PublishAsync(actor, saved.Id, "publish-1", request with { Reason = "Changed" }, default)).Error.Code);
        var restored = (await admin.CreateDraftAsync(actor, new(2, saved.Id), default)).Value;
        Assert.Equal(2, restored.Number);
        Assert.Equal(saved.Id, restored.BasedOnRevisionId);
        Assert.Equal("Draft", restored.State);
        Assert.Equal(saved.Id, (await admin.GetAsync(default)).Published!.Id);
    }

    [Fact]
    public async Task DiscoveryAdmin_ShouldRejectQaPinsAndSkipTemplatesArchivedAfterPublication()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = await CreateSqliteDbContextAsync(connection);
        var service = CreateService(db);
        var id = await CreateActiveImageTemplateAsync(service, "Public", "Funny", ["discovery"]);
        var admin = new TemplateDiscoveryAdminService(db);
        var actor = Guid.NewGuid();
        var draft = (await admin.CreateDraftAsync(actor, new(0), default)).Value;
        draft = (await admin.SaveDraftAsync(actor, draft.Id, new(draft.EditVersion, draft.Document with
        { Sections = [draft.Document.Sections[0] with { HeroTemplateId = id }] }), default)).Value;
        var item = await db.TemplateItems.SingleAsync(row => row.Id == id);
        item.IsQaOnly = true;
        await db.SaveChangesAsync();
        var invalid = (await admin.ValidateAsync(draft.Id, default)).Value;
        Assert.False(invalid.IsValid);
        Assert.Contains(invalid.Issues, issue => issue.Code == "template_unavailable");
        Assert.True((await admin.PublishAsync(actor, draft.Id, "invalid", new(draft.EditVersion, 1, "Invalid"), default)).IsFailure);
        item.IsQaOnly = false;
        await db.SaveChangesAsync();
        Assert.True((await admin.PublishAsync(actor, draft.Id, "valid", new(draft.EditVersion, 1, "Valid"), default)).IsSuccess);
        item.IsQaOnly = true;
        await db.SaveChangesAsync();
        Assert.Empty((await service.ListPublicDiscoveryAsync(new(6, 12, "en"), default)).Value.Sections);
    }

    [Fact]
    public async Task DiscoveryAdmin_ShouldKeepDraftOnVersionConflictAndDiscardWithoutChangingPublished()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = await CreateSqliteDbContextAsync(connection);
        var service = CreateService(db);
        await CreateActiveImageTemplateAsync(service, "Public", "Funny", ["discovery"]);
        var admin = new TemplateDiscoveryAdminService(db);
        var actor = Guid.NewGuid();
        var draft = (await admin.CreateDraftAsync(actor, new(0), default)).Value;
        var document = draft.Document with { AutoplayIntervalMs = 12000 };
        var saved = (await admin.SaveDraftAsync(actor, draft.Id, new(1, document), default)).Value;
        Assert.Equal("discovery.conflict", (await admin.SaveDraftAsync(actor, draft.Id, new(1, draft.Document), default)).Error.Code);
        Assert.Equal(12000, (await admin.GetAsync(default)).Draft!.Document.AutoplayIntervalMs);
        Assert.True((await admin.DiscardAsync(actor, draft.Id, new(saved.EditVersion, 1), default)).IsSuccess);
        var state = await admin.GetAsync(default);
        Assert.Null(state.Draft);
        Assert.Null(state.Published);
        Assert.Equal("Discarded", Assert.Single((await admin.HistoryAsync(0, 20, default)).Items).State);
    }

    [Fact]
    public void DiscoveryDocument_ShouldBoundAndValidateUntrustedPayloads()
    {
        Assert.Null(TemplateDiscoveryDocument.Read("null"));
        Assert.Null(TemplateDiscoveryDocument.Read("{\"schemaVersion\":1}"));
        Assert.Null(TemplateDiscoveryDocument.Read("{broken"));
        var copy = new Dictionary<string, DiscoveryCopy> { ["en"] = new("English", "Fallback"), ["ru"] = new("", "Текст") };
        Assert.Equal(new("English", "Текст"), TemplateDiscoveryDocument.ResolveCopy(copy, "ru-RU"));
        Assert.Equal(new("English", "Fallback"), TemplateDiscoveryDocument.ResolveCopy(copy, "ja"));
    }
}
