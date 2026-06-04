using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateLocalizationTranslatorCorrelationTests
{
    [Fact]
    public async Task GenerateAsync_ShouldUseProvidedFactoryBackedHttpClient()
    {
        using var correlationScope = CorrelationContext.Push("template-localization-correlation-test");
        var recordingHandler = new RecordingHandler();
        using var httpClient = new HttpClient(new TestCorrelationHandler
        {
            InnerHandler = recordingHandler
        });

        var localizedTextsJson = await TemplateLocalizationTranslator.GenerateAsync(
            "Cozy Portrait",
            "Warm portrait template",
            null,
            null,
            null,
            null,
            ["ru"],
            "en",
            httpClient,
            CancellationToken.None);

        Assert.NotNull(localizedTextsJson);
        Assert.Equal(2, recordingHandler.Requests.Count);
        Assert.All(recordingHandler.Requests, request =>
        {
            Assert.Equal("translate.googleapis.com", request.RequestUri?.Host);
            Assert.True(request.Headers.TryGetValues(CorrelationContext.HeaderName, out var values));
            Assert.Equal("template-localization-correlation-test", Assert.Single(values));
        });
    }

    private sealed class TestCorrelationHandler : DelegatingHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (!request.Headers.Contains(CorrelationContext.HeaderName))
            {
                request.Headers.TryAddWithoutValidation(CorrelationContext.HeaderName, CorrelationContext.ResolveOrCreate());
            }

            return base.SendAsync(request, cancellationToken);
        }
    }

    private sealed class RecordingHandler : HttpMessageHandler
    {
        public List<HttpRequestMessage> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(CloneRequest(request));
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent("""[[["translated","source",null,null,3]]]""")
            });
        }

        private static HttpRequestMessage CloneRequest(HttpRequestMessage request)
        {
            var clone = new HttpRequestMessage(request.Method, request.RequestUri);
            foreach (var header in request.Headers)
            {
                clone.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }

            return clone;
        }
    }
}
