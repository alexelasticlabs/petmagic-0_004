using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatePreviewOptimizationGate : IDisposable
{
    private readonly SemaphoreSlim semaphore;

    public TemplatePreviewOptimizationGate(TemplatesOptions options)
    {
        semaphore = new SemaphoreSlim(
            options.PreviewOptimization.MaxConcurrentOptimizations,
            options.PreviewOptimization.MaxConcurrentOptimizations);
    }

    public async ValueTask<IDisposable> EnterAsync(CancellationToken cancellationToken)
    {
        await semaphore.WaitAsync(cancellationToken);
        return new Lease(semaphore);
    }

    public void Dispose()
    {
        semaphore.Dispose();
    }

    private sealed class Lease(SemaphoreSlim semaphore) : IDisposable
    {
        private SemaphoreSlim? semaphore = semaphore;

        public void Dispose()
        {
            Interlocked.Exchange(ref semaphore, null)?.Release();
        }
    }
}
