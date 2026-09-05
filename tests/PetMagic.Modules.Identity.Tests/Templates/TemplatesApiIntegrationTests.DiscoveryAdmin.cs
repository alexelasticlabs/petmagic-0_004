using System.Net;
using System.Net.Http.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task DiscoveryAdminApi_ShouldEnforceRolesAndNoStoreThenPublishValidatedDraft()
    {
        await using var app = await TestApplication.CreateAsync(startGenerationWorker: false);
        await using (var scope = app.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<TemplatesDbContext>().Database.EnsureCreatedAsync();
        await CreateActiveImageTemplateAsync(app.Client, "Discovery API", "Funny", ["discovery"]);
        using var initial = await app.Client.GetAsync("/api/admin/templates/discovery/");
        Assert.Equal(HttpStatusCode.OK, initial.StatusCode);
        Assert.True(initial.Headers.CacheControl?.NoStore);
        using var created = await app.Client.PostAsJsonAsync("/api/admin/templates/discovery/drafts", new CreateDiscoveryDraftRequest(0));
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var draft = await ReadJsonAsync<DiscoveryRevisionResponse>(created);
        app.Client.DefaultRequestHeaders.Add("X-Test-Role", "Moderator");
        using var preview = await app.Client.GetAsync($"/api/admin/templates/discovery/drafts/{draft.Id}/preview?locale=ru");
        Assert.Equal(HttpStatusCode.OK, preview.StatusCode);
        Assert.True(preview.Headers.CacheControl?.Private);
        Assert.True(preview.Headers.CacheControl?.NoStore);
        using var forbidden = await app.Client.PutAsJsonAsync($"/api/admin/templates/discovery/drafts/{draft.Id}", new SaveDiscoveryDraftRequest(1, draft.Document));
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
        using var forbiddenPublish = await app.Client.PostAsJsonAsync($"/api/admin/templates/discovery/drafts/{draft.Id}/publish", new PublishDiscoveryRequest(1, 1, "Launch"));
        Assert.Equal(HttpStatusCode.Forbidden, forbiddenPublish.StatusCode);
        app.Client.DefaultRequestHeaders.Remove("X-Test-Role");
        app.Client.DefaultRequestHeaders.Add("Idempotency-Key", "discovery-api-publish");
        using var publish = await app.Client.PostAsJsonAsync($"/api/admin/templates/discovery/drafts/{draft.Id}/publish", new PublishDiscoveryRequest(1, 1, "Launch"));
        Assert.Equal(HttpStatusCode.OK, publish.StatusCode);
        using var stale = await app.Client.PutAsJsonAsync($"/api/admin/templates/discovery/drafts/{draft.Id}", new SaveDiscoveryDraftRequest(1, draft.Document));
        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);
        app.Client.DefaultRequestHeaders.Add("X-Test-Unauthenticated", "true");
        using var anonymous = await app.Client.GetAsync("/api/admin/templates/discovery/");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
    }
}
