using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
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
                var errorCode = AdminFailureMessageSanitizer.SanitizeCode(result.Error.Code)
                    ?? "templates.auto_pick_failed";

                logger.LogWarning(
                    "Template of the Day auto-pick failed. Operation={Operation} TargetDate={TargetDate} BusinessTimeZone={BusinessTimeZone} ErrorCode={ErrorCode}",
                    "ensure_tomorrow_auto_pick",
                    targetDate,
                    options.TemplateOfTheDayBusinessTimeZone,
                    errorCode);
                return;
            }

            logger.LogInformation(
                "Template of the Day auto-pick ensured. Operation={Operation} TargetDate={TargetDate} BusinessTimeZone={BusinessTimeZone} TemplateIdHash={TemplateIdHash}",
                "ensure_tomorrow_auto_pick",
                targetDate,
                options.TemplateOfTheDayBusinessTimeZone,
                TemplateLogSanitizer.SafeId(result.Value.TemplateId));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Template of the Day auto-pick worker iteration failed. Operation={Operation} BusinessTimeZone={BusinessTimeZone} ExceptionType={ExceptionType}",
                "ensure_tomorrow_auto_pick",
                options.TemplateOfTheDayBusinessTimeZone,
                SafeLogValues.ExceptionType(exception));
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
