using Microsoft.AspNetCore.Http;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class CorrelationIdDelegatingHandlerTests
{
    [Fact]
    public async Task SendAsync_ShouldPropagateCorrelationIdFromHttpContext()
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Items[CorrelationId.HttpContextItemKey] = "request-correlation-1";
        var accessor = new HttpContextAccessor
        {
            HttpContext = httpContext
        };
        var innerHandler = new CapturingHandler();
        var handler = new CorrelationIdDelegatingHandler(accessor)
        {
            InnerHandler = innerHandler
        };
        using var client = new HttpClient(handler);

        using var response = await client.GetAsync("https://example.test/resource");

        Assert.True(response.IsSuccessStatusCode);
        Assert.NotNull(innerHandler.Request);
        Assert.True(innerHandler.Request!.Headers.TryGetValues(CorrelationId.HeaderName, out var values));
        Assert.Equal("request-correlation-1", Assert.Single(values));
    }

    [Fact]
    public async Task SendAsync_ShouldNotOverrideExistingCorrelationId()
    {
        var accessor = new HttpContextAccessor
        {
            HttpContext = new DefaultHttpContext()
        };
        accessor.HttpContext.Items[CorrelationId.HttpContextItemKey] = "server-correlation";
        var innerHandler = new CapturingHandler();
        var handler = new CorrelationIdDelegatingHandler(accessor)
        {
            InnerHandler = innerHandler
        };
        using var client = new HttpClient(handler);
        using var request = new HttpRequestMessage(HttpMethod.Get, "https://example.test/resource");
        request.Headers.Add(CorrelationId.HeaderName, "caller-correlation");

        using var response = await client.SendAsync(request);

        Assert.True(response.IsSuccessStatusCode);
        Assert.NotNull(innerHandler.Request);
        Assert.True(innerHandler.Request!.Headers.TryGetValues(CorrelationId.HeaderName, out var values));
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
