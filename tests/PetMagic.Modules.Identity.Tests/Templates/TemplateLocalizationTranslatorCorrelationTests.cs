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
            Assert.Equal(HttpMethod.Post, request.Method);
            Assert.Equal("translate.googleapis.com", request.RequestUri?.Host);
            Assert.Equal("/translate_a/single", request.RequestUri?.AbsolutePath);
            Assert.DoesNotContain("q=", request.RequestUri?.Query ?? string.Empty, StringComparison.Ordinal);
            Assert.True(request.Headers.TryGetValue(CorrelationContext.HeaderName, out var values));
            Assert.Equal("template-localization-correlation-test", Assert.Single(values));
            Assert.Contains("q=Cozy+Portrait", request.Body, StringComparison.Ordinal);
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
        public List<RecordedRequest> Requests { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var body = request.Content is null
                ? string.Empty
                : await request.Content.ReadAsStringAsync(cancellationToken);
            Requests.Add(CloneRequest(request, body));
            var translatedPayload = ExtractFormValue(body, "q");
            return new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent($"""[[["{translatedPayload}","source",null,null,3]]]""")
            };
        }

        private static RecordedRequest CloneRequest(HttpRequestMessage request, string body)
        {
            var clone = new RecordedRequest(request.Method, request.RequestUri, body);
            foreach (var header in request.Headers)
            {
                clone.Headers[header.Key] = header.Value.ToArray();
            }

            return clone;
        }

        private static string ExtractFormValue(string body, string key)
        {
            foreach (var segment in body.Split('&', StringSplitOptions.RemoveEmptyEntries))
            {
                var parts = segment.Split('=', 2);
                if (parts.Length == 2 && string.Equals(parts[0], key, StringComparison.Ordinal))
                {
                    return Uri.UnescapeDataString(parts[1].Replace('+', ' '));
                }
            }

            return "translated";
        }
    }

    private sealed class RecordedRequest(HttpMethod method, Uri? requestUri, string body)
    {
        public HttpMethod Method { get; } = method;

        public Uri? RequestUri { get; } = requestUri;

        public string Body { get; } = body;

        public Dictionary<string, string[]> Headers { get; } = new(StringComparer.OrdinalIgnoreCase);
    }
}
