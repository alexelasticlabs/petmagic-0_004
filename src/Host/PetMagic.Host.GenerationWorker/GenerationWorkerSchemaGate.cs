using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Host.GenerationWorker;

internal static class GenerationWorkerSchemaGate
{
    public static async Task WaitUntilReadyAsync(
        IServiceProvider serviceProvider,
        TimeSpan timeout,
        CancellationToken cancellationToken = default)
    {
        var logger = serviceProvider.GetRequiredService<ILoggerFactory>()
            .CreateLogger("PetMagic.Host.GenerationWorker.SchemaGate");
        var startedAtUtc = DateTime.UtcNow;
        string lastState = "schema was not checked";

        while (DateTime.UtcNow - startedAtUtc < timeout)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                await using var scope = serviceProvider.CreateAsyncScope();
                var economy = scope.ServiceProvider.GetRequiredService<EconomyDbContext>();
                var templates = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
                if (!economy.Database.IsRelational() || !templates.Database.IsRelational())
                {
                    return;
                }

                var economyPending = (await economy.Database.GetPendingMigrationsAsync(cancellationToken)).ToArray();
                var templatesPending = (await templates.Database.GetPendingMigrationsAsync(cancellationToken)).ToArray();
                if (economyPending.Length == 0 && templatesPending.Length == 0)
                {
                    logger.LogInformation("Generation worker schema gate passed; Economy and Templates are current.");
                    return;
                }

                lastState = $"Economy=[{string.Join(',', economyPending)}], Templates=[{string.Join(',', templatesPending)}]";
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                lastState = $"{exception.GetType().Name}: {exception.Message}";
            }

            logger.LogWarning(
                "Generation worker is waiting for API migrations. State={SchemaState}",
                lastState);
            await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
        }

        throw new TimeoutException(
            $"Generation worker refused to start because Economy/Templates schema did not become current within {timeout.TotalMinutes:F0} minutes. Last state: {lastState}");
    }
}
