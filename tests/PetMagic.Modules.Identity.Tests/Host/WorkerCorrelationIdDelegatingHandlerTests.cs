using System.Diagnostics;

using PetMagic.Host.GenerationWorker;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class WorkerCorrelationIdDelegatingHandlerTests
{
    [Fact]
    public async Task SendAsync_ShouldUseCurrentActivityTraceId()
    {
        using var activity = new Activity("worker-http").Start();
        var innerHandler = new CapturingHandler();
        var handler = new WorkerCorrelationIdDelegatingHandler
        {
            InnerHandler = innerHandler
        };
        using var client = new HttpClient(handler);

        using var response = await client.GetAsync("https://example.test/resource");

        Assert.True(response.IsSuccessStatusCode);
        Assert.NotNull(innerHandler.Request);
        Assert.True(innerHandler.Request!.Headers.TryGetValues(WorkerCorrelationIdDelegatingHandler.HeaderName, out var values));
        Assert.Equal(activity.TraceId.ToString(), Assert.Single(values));
    }

    [Fact]
    public async Task SendAsync_ShouldNotOverrideExistingCorrelationId()
    {
        var innerHandler = new CapturingHandler();
        var handler = new WorkerCorrelationIdDelegatingHandler
        {
            InnerHandler = innerHandler
        };
        using var client = new HttpClient(handler);
        using var request = new HttpRequestMessage(HttpMethod.Get, "https://example.test/resource");
        request.Headers.Add(WorkerCorrelationIdDelegatingHandler.HeaderName, "caller-correlation");

        using var response = await client.SendAsync(request);

        Assert.True(response.IsSuccessStatusCode);
        Assert.NotNull(innerHandler.Request);
        Assert.True(innerHandler.Request!.Headers.TryGetValues(WorkerCorrelationIdDelegatingHandler.HeaderName, out var values));
        Assert.Equal("caller-correlation", Assert.Single(values));
    }

    private sealed class CapturingHandler : HttpMessageHandler
    {
        public HttpRequestMessage? Request { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Request = request;
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK));
        }
    }
}
