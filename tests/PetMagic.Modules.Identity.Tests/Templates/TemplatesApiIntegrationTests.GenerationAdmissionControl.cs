using System.Net;
using System.Net.Http.Headers;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task AdminTemplateTestEndpoint_ShouldReturnServiceUnavailable_WhenAdmissionIsPaused()
    {
        var providerHealth = new ApiAdmissionHealthService(
            Result.Failure(TemplatesErrors.ProviderCapacityUnavailable));
        await using var application = await TestApplication.CreateAsync(
            startGenerationWorker: false,
            aiProviderHealthService: providerHealth);
        var template = await CreateActiveImageTemplateAsync(
            application.Client,
            "Paused Api Admin Portrait",
            "Portrait",
            ["api-admission-pause"]);

        using var multipart = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(
            WithValidMediaHeader("image/jpeg", "source.jpg", [1, 2, 3, 4]));
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        multipart.Add(fileContent, "sourceImage", "source.jpg");

        using var response = await application.Client.PostAsync(
            $"/api/admin/templates/{template.TemplateId}/test",
            multipart);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(1, providerHealth.CheckCount);
        await using var scope = application.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        Assert.Empty(await dbContext.TemplateGenerationJobs.ToArrayAsync());
    }

    private sealed class ApiAdmissionHealthService(Result result) : ITemplateAiProviderHealthService
    {
        public int CheckCount { get; private set; }

        public Task<Result> EnsureCanAcceptGenerationAsync(
            string mediaType,
            string tier,
            CancellationToken cancellationToken)
        {
            CheckCount++;
            return Task.FromResult(result);
        }
    }
}
