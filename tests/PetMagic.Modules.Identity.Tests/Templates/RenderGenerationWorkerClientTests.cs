using System.Net;
using System.Text.Json;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class RenderGenerationWorkerClientTests
{
    [Fact]
    public void AddRenderGenerationWorkerControl_ShouldReadServerOnlyEnvironmentKeys()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["RENDER_API_KEY"] = "test-render-api-key",
                ["RENDER_GENERATION_WORKER_SERVICE_ID"] = ServiceId,
                ["RENDER_GENERATION_WORKER_EXPECTED_OWNER_ID"] = "tea-owner",
                ["RENDER_GENERATION_WORKER_EXPECTED_NAME"] = "petmagic-production-generation-worker",
                ["RENDER_GENERATION_WORKER_EXPECTED_TYPE"] = "background_worker",
                ["RENDER_GENERATION_WORKER_EXPECTED_REPOSITORY"] = ExpectedRepository
            })
            .Build();
        var services = new ServiceCollection();

        services.AddRenderGenerationWorkerControl(configuration);

        using var provider = services.BuildServiceProvider();
        var client = provider.GetRequiredService<IRenderGenerationWorkerClient>();
        Assert.True(client.IsConfigured);
    }

    [Fact]
    public async Task GetTargetStatusAsync_ShouldNotCallRender_WhenConfigurationIsIncomplete()
    {
        var handler = new RecordingHandler();
        var client = CreateClient(handler, CreateOptions(apiKey: string.Empty));

        var result = await client.GetTargetStatusAsync(CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(RenderGenerationWorkerErrors.NotConfigured.Code, result.Error.Code);
        Assert.Empty(handler.Requests);
    }

    [Fact]
    public async Task GetTargetStatusAsync_ShouldNotCallRender_WhenExpectedRepositoryIsNotHttps()
    {
        var handler = new RecordingHandler();
        var options = CreateOptions(
            expectedRepository: "http://github.com/alexelasticlabs/petmagic-0_004");
        var client = CreateClient(handler, options);

        var result = await client.GetTargetStatusAsync(CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(RenderGenerationWorkerErrors.NotConfigured.Code, result.Error.Code);
        Assert.Empty(handler.Requests);
    }

    [Fact]
    public async Task GetTargetStatusAsync_ShouldValidateLockedTarget_AndNormalizeRepositorySuffix()
    {
        var handler = new RecordingHandler(ServiceResponse(repository: ExpectedRepository + ".git"));
        var client = CreateClient(handler);

        var result = await client.GetTargetStatusAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(ServiceId, result.Value.ServiceId);
        Assert.Equal("background_worker", result.Value.Type);
        Assert.Equal(ExpectedRepository, result.Value.Repository);
        Assert.Equal("standard", result.Value.Plan);
        Assert.Equal("frankfurt", result.Value.Region);
        Assert.Equal(1, result.Value.DesiredInstances);
        Assert.False(result.Value.AutoscalingEnabled);

        var request = Assert.Single(handler.Requests);
        Assert.Equal(HttpMethod.Get, request.Method);
        Assert.Equal($"/v1/services/{ServiceId}", request.PathAndQuery);
        Assert.Equal("Bearer", request.AuthorizationScheme);
        Assert.Equal("test-render-api-key", request.AuthorizationParameter);
    }

    [Fact]
    public async Task GetTargetStatusAsync_ShouldRejectRepositoryMismatch_WithoutExposingValues()
    {
        var handler = new RecordingHandler(ServiceResponse(repository: "https://github.com/other/repository"));
        var client = CreateClient(handler);

        var result = await client.GetTargetStatusAsync(CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.render.target_mismatch", result.Error.Code);
        Assert.Equal("repository", result.Error.Metadata!["field"]);
        Assert.DoesNotContain("other", JsonSerializer.Serialize(result.Error), StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("test-render-api-key", JsonSerializer.Serialize(result.Error), StringComparison.Ordinal);
    }

    [Fact]
    public async Task ListInstancesAsync_ShouldValidateTargetBeforeListingInstances()
    {
        var handler = new RecordingHandler(
            ServiceResponse(),
            JsonResponse(
                HttpStatusCode.OK,
                """
                [
                  { "id": "srv-instance-a", "createdAt": "2026-07-28T10:00:00Z" },
                  { "id": "srv-instance-b", "createdAt": "2026-07-28T10:01:00Z" }
                ]
                """));
        var client = CreateClient(handler);

        var result = await client.ListInstancesAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.Count);
        Assert.Equal("srv-instance-a", result.Value[0].Id);
        Assert.Equal(DateTimeKind.Utc, result.Value[0].CreatedAtUtc.Kind);
        Assert.Collection(
            handler.Requests,
            request => Assert.Equal($"/v1/services/{ServiceId}", request.PathAndQuery),
            request => Assert.Equal($"/v1/services/{ServiceId}/instances", request.PathAndQuery));
    }

    [Fact]
    public async Task ScaleAsync_ShouldRefuseAutoscaling_WithoutPostingScale()
    {
        var handler = new RecordingHandler(ServiceResponse(numInstances: null));
        var client = CreateClient(handler);

        var result = await client.ScaleAsync(4, CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(RenderGenerationWorkerErrors.AutoscalingEnabled.Code, result.Error.Code);
        Assert.Single(handler.Requests);
        Assert.Equal(HttpMethod.Get, handler.Requests[0].Method);
    }

    [Fact]
    public async Task ScaleAsync_ShouldRefuseExplicitAutoscaling_EvenWhenInstanceCountIsPresent()
    {
        var handler = new RecordingHandler(ServiceResponse(numInstances: 2, autoscalingJson: "{}"));
        var client = CreateClient(handler);

        var result = await client.ScaleAsync(4, CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(RenderGenerationWorkerErrors.AutoscalingEnabled.Code, result.Error.Code);
        Assert.Single(handler.Requests);
    }

    [Fact]
    public async Task ScaleAsync_ShouldPostOnlyTheValidatedInstanceCount_AndRequireAccepted()
    {
        var handler = new RecordingHandler(
            ServiceResponse(),
            new HttpResponseMessage(HttpStatusCode.Accepted));
        var client = CreateClient(handler);

        var result = await client.ScaleAsync(4, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(4, result.Value.TargetInstances);
        Assert.NotEqual(default, result.Value.AcceptedAtUtc);
        Assert.Collection(
            handler.Requests,
            request => Assert.Equal(HttpMethod.Get, request.Method),
            request =>
            {
                Assert.Equal(HttpMethod.Post, request.Method);
                Assert.Equal($"/v1/services/{ServiceId}/scale", request.PathAndQuery);
                Assert.Equal("{\"numInstances\":4}", request.Content);
            });
    }

    [Fact]
    public async Task ScaleAsync_ShouldRejectOutOfRangeTarget_WithoutCallingRender()
    {
        var handler = new RecordingHandler();
        var client = CreateClient(handler);

        var result = await client.ScaleAsync(9, CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.render.invalid_target", result.Error.Code);
        Assert.Empty(handler.Requests);
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized, "templates.render.auth_failed")]
    [InlineData(HttpStatusCode.Forbidden, "templates.render.permission_denied")]
    [InlineData(HttpStatusCode.TooManyRequests, "templates.render.rate_limited")]
    [InlineData(HttpStatusCode.ServiceUnavailable, "templates.render.upstream_unavailable")]
    public async Task GetTargetStatusAsync_ShouldMapStableErrors_WithoutReturningResponseBody(
        HttpStatusCode statusCode,
        string expectedCode)
    {
        var response = JsonResponse(statusCode, "{\"secret\":\"provider-response-secret\"}");
        if (statusCode == HttpStatusCode.TooManyRequests)
        {
            response.Headers.RetryAfter = new System.Net.Http.Headers.RetryConditionHeaderValue(
                TimeSpan.FromSeconds(30));
        }

        var client = CreateClient(new RecordingHandler(response));

        var result = await client.GetTargetStatusAsync(CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(expectedCode, result.Error.Code);
        Assert.DoesNotContain("provider-response-secret", JsonSerializer.Serialize(result.Error), StringComparison.Ordinal);
    }

    private static RenderGenerationWorkerClient CreateClient(
        RecordingHandler handler,
        RenderGenerationWorkerOptions? options = null)
    {
        var httpClient = new HttpClient(handler)
        {
            BaseAddress = new Uri("https://api.render.com/v1/")
        };
        return new RenderGenerationWorkerClient(
            new StaticHttpClientFactory(httpClient),
            options ?? CreateOptions());
    }

    private static RenderGenerationWorkerOptions CreateOptions(
        string apiKey = "test-render-api-key",
        string expectedRepository = ExpectedRepository) => new()
    {
        ApiKey = apiKey,
        ServiceId = ServiceId,
        ExpectedOwnerId = "tea-owner",
        ExpectedServiceName = "petmagic-production-generation-worker",
        ExpectedServiceType = "background_worker",
        ExpectedRepository = expectedRepository,
        MinimumInstances = 1,
        MaximumInstances = 8
    };

    private static HttpResponseMessage ServiceResponse(
        string repository = ExpectedRepository,
        int? numInstances = 1,
        string? autoscalingJson = null)
    {
        var numInstancesProperty = numInstances.HasValue
            ? $", \"numInstances\": {numInstances.Value}"
            : string.Empty;
        var autoscalingProperty = autoscalingJson is null
            ? string.Empty
            : $", \"autoscaling\": {autoscalingJson}";

        return JsonResponse(
            HttpStatusCode.OK,
            $$"""
            {
              "id": "{{ServiceId}}",
              "name": "petmagic-production-generation-worker",
              "type": "background_worker",
              "ownerId": "tea-owner",
              "repo": "{{repository}}",
              "serviceDetails": {
                "plan": "standard",
                "region": "frankfurt"{{numInstancesProperty}}{{autoscalingProperty}}
              }
            }
            """);
    }

    private static HttpResponseMessage JsonResponse(HttpStatusCode statusCode, string body) => new(statusCode)
    {
        Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
    };

    private const string ServiceId = "srv-1234567890abcdefghij";
    private const string ExpectedRepository = "https://github.com/alexelasticlabs/petmagic-0_004";

    private sealed class StaticHttpClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(RenderGenerationWorkerClient.HttpClientName, name);
            return client;
        }
    }

    private sealed class RecordingHandler : HttpMessageHandler
    {
        private readonly Queue<HttpResponseMessage> _responses;

        public RecordingHandler(params HttpResponseMessage[] responses)
        {
            _responses = new Queue<HttpResponseMessage>(responses);
        }

        public List<RecordedRequest> Requests { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            var content = request.Content is null
                ? null
                : await request.Content.ReadAsStringAsync(cancellationToken);
            Requests.Add(new RecordedRequest(
                request.Method,
                request.RequestUri!.PathAndQuery,
                request.Headers.Authorization?.Scheme,
                request.Headers.Authorization?.Parameter,
                content));

            if (_responses.Count == 0)
            {
                throw new InvalidOperationException("No fake Render response was configured.");
            }

            return _responses.Dequeue();
        }
    }

    private sealed record RecordedRequest(
        HttpMethod Method,
        string PathAndQuery,
        string? AuthorizationScheme,
        string? AuthorizationParameter,
        string? Content);
}
