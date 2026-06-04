using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Host.GenerationWorker;

public sealed class WorkerCorrelationIdDelegatingHandler : DelegatingHandler
{
    public const string HeaderName = CorrelationContext.HeaderName;

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (!request.Headers.Contains(HeaderName))
        {
            request.Headers.TryAddWithoutValidation(HeaderName, CorrelationContext.ResolveOrCreate());
        }

        return base.SendAsync(request, cancellationToken);
    }
}
