using Microsoft.Extensions.Http;

namespace PetMagic.Host.Api.Observability;

public static class CorrelationIdHttpClientFactoryOptions
{
    public static void AddCorrelationIdHandler(HttpClientFactoryOptions options)
    {
        options.HttpMessageHandlerBuilderActions.Add(builder =>
        {
            builder.AdditionalHandlers.Add(
                builder.Services.GetRequiredService<CorrelationIdDelegatingHandler>());
        });
    }
}
