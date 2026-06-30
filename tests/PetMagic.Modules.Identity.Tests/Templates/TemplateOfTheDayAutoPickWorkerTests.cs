using System.Reflection;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateOfTheDayAutoPickWorkerTests
{
    [Fact]
    public async Task EnsureTomorrowAutoPickAsync_ShouldRequestTomorrowInConfiguredBusinessTimeZone()
    {
        var (timeZoneId, businessDate) = ResolveBusinessDateDifferentFromUtc();
        var (templatesService, recorder) = RecordingTemplatesServiceProxy.Create();
        using var serviceProvider = new ServiceCollection()
            .AddSingleton(templatesService)
            .BuildServiceProvider();
        var worker = new TemplateOfTheDayAutoPickWorker(
            serviceProvider.GetRequiredService<IServiceScopeFactory>(),
            new TemplatesOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = "wwwroot/templates-media",
                DefaultImagePrompt = "Create a themed pet portrait.",
                DefaultPreprocessingPrompt = "Keep the same pet.",
                DefaultKlingPrompt = "Funny dance.",
                AllowedImageModels = ["openai/gpt-image-2/edit"],
                AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
                AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
                SupportedLocalizationLocales = ["ru"],
                TemplateOfTheDayBusinessTimeZone = timeZoneId
            },
            NullLogger<TemplateOfTheDayAutoPickWorker>.Instance);

        await worker.EnsureTomorrowAutoPickAsync(CancellationToken.None);

        var command = Assert.IsType<AutoPickTemplateOfTheDayCommand>(recorder.Command);
        Assert.Equal(businessDate.AddDays(1), command.Date);
        Assert.Null(command.AllowedTypes);
        Assert.Null(command.ExcludeRecentDays);
        Assert.Null(command.CreatedByAdminId);
        Assert.False(command.Force);
        Assert.Equal(1, recorder.CallCount);
    }

    [Fact]
    public async Task EnsureTomorrowAutoPickAsync_ShouldLogStructuredWarning_WhenAutoPickFails()
    {
        var (templatesService, _) = FailingTemplatesServiceProxy.Create("templates.auto_pick_failed");
        using var serviceProvider = new ServiceCollection()
            .AddSingleton(templatesService)
            .BuildServiceProvider();
        var logger = new CapturingLogger<TemplateOfTheDayAutoPickWorker>();
        var worker = new TemplateOfTheDayAutoPickWorker(
            serviceProvider.GetRequiredService<IServiceScopeFactory>(),
            new TemplatesOptions
            {
                TemplateOfTheDayBusinessTimeZone = "UTC"
            },
            logger);

        await worker.EnsureTomorrowAutoPickAsync(CancellationToken.None);

        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Template of the Day auto-pick failed.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("ensure_tomorrow_auto_pick", entry.Properties["Operation"]);
        Assert.Equal("UTC", entry.Properties["BusinessTimeZone"]);
        Assert.Equal("templates.auto_pick_failed", entry.Properties["ErrorCode"]);
    }

    private static (string TimeZoneId, DateOnly BusinessDate) ResolveBusinessDateDifferentFromUtc()
    {
        var utcDate = DateOnly.FromDateTime(DateTime.UtcNow);
        foreach (var timeZoneId in new[] { "Pacific/Kiritimati", "Etc/GMT+12" })
        {
            try
            {
                var timeZone = TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
                var businessDate = DateOnly.FromDateTime(
                    TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, timeZone));
                if (businessDate != utcDate)
                {
                    return (timeZoneId, businessDate);
                }
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        throw new InvalidOperationException("Could not resolve a test timezone with a business date different from UTC.");
    }

    private class RecordingTemplatesServiceProxy : DispatchProxy
    {
        public AutoPickTemplateOfTheDayCommand? Command { get; private set; }

        public int CallCount { get; private set; }

        public static (ITemplatesService Service, RecordingTemplatesServiceProxy Recorder) Create()
        {
            var service = Create<ITemplatesService, RecordingTemplatesServiceProxy>();
            return (service, (RecordingTemplatesServiceProxy)(object)service);
        }

        protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            if (targetMethod?.Name == nameof(ITemplatesService.AutoPickTemplateOfTheDayAsync))
            {
                Command = Assert.IsType<AutoPickTemplateOfTheDayCommand>(args?[0]);
                CallCount++;
                return Task.FromResult(Result.Success(CreateResponse(Command.Date)));
            }

            throw new NotSupportedException($"{targetMethod?.Name} is not used by this test.");
        }

        private static AdminTemplateOfTheDayResponse CreateResponse(DateOnly date)
        {
            return new AdminTemplateOfTheDayResponse(
                Guid.NewGuid(),
                Guid.NewGuid(),
                "Tomorrow Magic",
                "Image",
                "Daily",
                "Active",
                false,
                new TemplateAssetResponse(
                    "https://cdn.example.com/tomorrow.jpg",
                    "tomorrow.jpg",
                    "image/jpeg",
                    null,
                    null),
                date,
                date,
                true,
                false,
                0,
                null,
                null,
                null,
                DateTime.UtcNow,
                DateTime.UtcNow,
                null);
        }
    }

    private class FailingTemplatesServiceProxy : DispatchProxy
    {
        public string ErrorCode { get; private set; } = "templates.auto_pick_failed";

        public static (ITemplatesService Service, FailingTemplatesServiceProxy Recorder) Create(string errorCode)
        {
            var service = Create<ITemplatesService, FailingTemplatesServiceProxy>();
            var proxy = (FailingTemplatesServiceProxy)(object)service;
            proxy.ErrorCode = errorCode;
            return (service, proxy);
        }

        protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            if (targetMethod?.Name == nameof(ITemplatesService.AutoPickTemplateOfTheDayAsync))
            {
                return Task.FromResult(Result.Failure<AdminTemplateOfTheDayResponse>(new Error(ErrorCode, "failed")));
            }

            throw new NotSupportedException($"{targetMethod?.Name} is not used by this test.");
        }
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull
        {
            return NullScope.Instance;
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            var properties = state is IEnumerable<KeyValuePair<string, object?>> values
                ? values.ToDictionary(x => x.Key, x => x.Value)
                : new Dictionary<string, object?>();
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception, properties));
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel LogLevel,
        string Message,
        Exception? Exception,
        IReadOnlyDictionary<string, object?> Properties);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
