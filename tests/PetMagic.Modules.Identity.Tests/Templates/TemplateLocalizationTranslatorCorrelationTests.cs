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
        Assert.Single(recordingHandler.Requests);
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
            var translatedPayload = ExtractQueryValue(request.RequestUri, "q");
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent($"""[[["{translatedPayload}","source",null,null,3]]]""")
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

        private static string ExtractQueryValue(Uri? requestUri, string key)
        {
            var query = requestUri?.Query ?? string.Empty;
            foreach (var segment in query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
            {
                var parts = segment.Split('=', 2);
                if (parts.Length == 2 && string.Equals(parts[0], key, StringComparison.Ordinal))
                {
                    return Uri.UnescapeDataString(parts[1]);
                }
            }

            return "translated";
        }
    }
}
