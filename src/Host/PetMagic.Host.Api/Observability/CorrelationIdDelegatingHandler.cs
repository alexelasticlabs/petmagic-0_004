using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Host.Api.Observability;

public sealed class CorrelationIdDelegatingHandler(IHttpContextAccessor httpContextAccessor) : DelegatingHandler
{
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (!request.Headers.Contains(CorrelationId.HeaderName))
        {
            var correlationId = ResolveCorrelationId();
            if (!string.IsNullOrWhiteSpace(correlationId))
            {
                request.Headers.TryAddWithoutValidation(CorrelationId.HeaderName, correlationId);
            }
        }

        return base.SendAsync(request, cancellationToken);
    }

    private string? ResolveCorrelationId()
    {
        var currentCorrelationId = CorrelationContext.CurrentId;
        if (!string.IsNullOrWhiteSpace(currentCorrelationId) && CorrelationId.IsValid(currentCorrelationId))
        {
            return currentCorrelationId;
        }

        var httpContext = httpContextAccessor.HttpContext;
        if (httpContext?.Items.TryGetValue(CorrelationId.HttpContextItemKey, out var value) == true
            && value is string correlationId
            && CorrelationId.IsValid(correlationId))
        {
            return correlationId;
        }

        var headerValue = httpContext?.Request.Headers[CorrelationId.HeaderName];
        return headerValue.HasValue
            ? CorrelationId.NormalizeOrCreate(headerValue.Value)
            : null;
    }
}
