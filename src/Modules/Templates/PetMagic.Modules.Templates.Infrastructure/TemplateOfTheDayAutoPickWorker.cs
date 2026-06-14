using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateOfTheDayAutoPickWorker(
    IServiceScopeFactory scopeFactory,
    TemplatesOptions options,
    ILogger<TemplateOfTheDayAutoPickWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.TemplateOfTheDayAutoPickWorkerEnabled)
        {
            return;
        }

        var interval = TimeSpan.FromMinutes(Math.Max(1, options.TemplateOfTheDayAutoPickIntervalMinutes));

        while (!stoppingToken.IsCancellationRequested)
        {
            await EnsureTomorrowAutoPickAsync(stoppingToken);

            try
            {
                await Task.Delay(interval, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
        }
    }

    internal async Task EnsureTomorrowAutoPickAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var service = scope.ServiceProvider.GetRequiredService<ITemplatesService>();
            var targetDate = ResolveBusinessDate().AddDays(1);

            var result = await service.AutoPickTemplateOfTheDayAsync(
                new AutoPickTemplateOfTheDayCommand(
                    targetDate,
                    null,
                    null,
                    null),
                cancellationToken);

            if (result.IsFailure)
            {
                logger.LogWarning(
                    "Template of the Day auto-pick failed for {TargetDate}: {ErrorCode}",
                    targetDate,
                    result.Error.Code);
                return;
            }

            logger.LogInformation(
                "Template of the Day auto-pick ensured for {TargetDate} with template {TemplateId}.",
                targetDate,
                result.Value.TemplateId);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "Template of the Day auto-pick worker iteration failed.");
        }
    }

    private DateOnly ResolveBusinessDate()
    {
        var timeZone = ResolveBusinessTimeZone();
        var businessNow = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, timeZone);
        return DateOnly.FromDateTime(businessNow);
    }

    private TimeZoneInfo ResolveBusinessTimeZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(options.TemplateOfTheDayBusinessTimeZone);
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.Utc;
        }
        catch (InvalidTimeZoneException)
        {
            return TimeZoneInfo.Utc;
        }
    }
}
