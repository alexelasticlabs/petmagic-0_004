using System.Diagnostics;
using System.Reflection;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

using PetMagic.Host.Api.Observability;
using PetMagic.Host.Api.Startup;
using PetMagic.Modules.Economy.Api;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Host.Api.Security;
using PetMagic.Modules.Identity.Api;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Options;
using PetMagic.Modules.SupportChat.Api;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;
using PetMagic.Modules.Gamification.Api;
using PetMagic.Modules.Gamification.Infrastructure;

using Serilog;
using Serilog.Events;
using Serilog.Formatting.Json;

using PetMagic.BuildingBlocks.Data;

LoadDotEnvFileIfPresent();

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .Enrich.WithProperty("ApplicationName", "PetMagic.Host.Api")
    .Enrich.WithProperty("Environment", ResolveBootstrapEnvironment())
    .WriteTo.Console(new JsonFormatter(), standardErrorFromLevel: LogEventLevel.Error)
    .CreateLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);
    var buildInfo = ResolveBuildInfo(builder.Environment.EnvironmentName);
    var databaseConnectionBudget = new PostgreSqlConnectionBudget(
        ReadPositiveDatabaseSetting(
            builder.Configuration,
            "Database:MaxPoolSize",
            PostgreSqlConnectionBudget.ApiDefaultMaxPoolSize),
        ReadPositiveDatabaseSetting(
            builder.Configuration,
            "Database:PeerMaxPoolSize",
            PostgreSqlConnectionBudget.GenerationWorkerDefaultMaxPoolSize),
        ReadPositiveDatabaseSetting(
            builder.Configuration,
            "Database:OperationalReserveConnections",
            PostgreSqlConnectionBudget.DefaultOperationalReserveConnections));
    var sharedPostgreSqlDataSource = databaseConnectionBudget.CreateDataSource(
        builder.Configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is required."),
        "PetMagic.Host.Api");
    builder.Configuration["ConnectionStrings:DefaultConnection"] = sharedPostgreSqlDataSource.ConnectionString;
    builder.Services.AddSingleton(_ => sharedPostgreSqlDataSource);

    TemplateGenerationHostModeValidator.RequireGenerationWorkerMode(
        builder.Configuration,
        builder.Environment,
        "PetMagic.Host.Api",
        expectedEnabled: false);

    builder.Host.UseSerilog((context, loggerConfiguration) =>
    {
        loggerConfiguration
            .ReadFrom.Configuration(context.Configuration)
            .Enrich.FromLogContext()
            .Enrich.WithProperty("ApplicationName", "PetMagic.Host.Api")
            .Enrich.WithProperty("Environment", context.HostingEnvironment.EnvironmentName);
    });

    builder.Services.AddOpenApi();
    builder.Services.AddProblemDetails(SafeProblemDetailsOptions.Configure);
    builder.Services.Configure<LoggingOptions>(builder.Configuration.GetSection(LoggingOptions.SectionName));
    builder.Services.AddMemoryCache();
    builder.Services.AddHttpContextAccessor();
    builder.Services.AddResponseCompression(options =>
    {
        options.EnableForHttps = true;
    });
    builder.Services.AddTransient<CorrelationIdDelegatingHandler>();
    builder.Services.ConfigureAll<HttpClientFactoryOptions>(CorrelationIdHttpClientFactoryOptions.AddCorrelationIdHandler);

    var defaultDataProtectionKeysPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".aspnet",
        "DataProtection-Keys");
    var dataProtectionKeysPath = builder.Configuration["DataProtection:KeysPath"] ?? string.Empty;
    if (string.IsNullOrWhiteSpace(dataProtectionKeysPath))
    {
        dataProtectionKeysPath = defaultDataProtectionKeysPath;
    }

    var dataProtectionBuilder = builder.Services.AddDataProtection()
        .SetApplicationName("PetMagic.Host.Api")
        .PersistKeysToFileSystem(new DirectoryInfo(dataProtectionKeysPath));

    if (builder.Environment.IsDevelopment())
    {
        var dataProtectionCertificatePath = Path.Combine(dataProtectionKeysPath, "petmagic-data-protection-dev.pfx");
        var dataProtectionCertificatePassword = builder.Configuration["DataProtection:CertificatePassword"];
        if (string.IsNullOrWhiteSpace(dataProtectionCertificatePassword))
        {
            throw new InvalidOperationException(
                "Development DataProtection certificate password is not configured. Set DataProtection:CertificatePassword in development config or environment.");
        }

        using var bootstrapLoggerFactory = LoggerFactory.Create(logging => logging.AddSerilog(Log.Logger, dispose: false));
        var dataProtectionCertificate = DataProtectionCertificateLoader.LoadOrCreateDevelopmentCertificate(
            dataProtectionCertificatePath,
            dataProtectionCertificatePassword,
            builder.Environment.ApplicationName,
            bootstrapLoggerFactory.CreateLogger("PetMagic.Host.Api.DataProtection"));

        dataProtectionBuilder.ProtectKeysWithCertificate(dataProtectionCertificate);
    }

    var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    var allowAnyCorsInDevelopment = builder.Environment.IsDevelopment();
    var forwardedHeadersTrustSettings = ForwardedHeadersTrustSettings.Read(builder.Configuration);
    ForwardedHeadersTrust.Validate(forwardedHeadersTrustSettings, builder.Environment);
    HostApiProductionConfigurationValidator.ValidateDefaultConnectionString(builder.Configuration, builder.Environment);
    HostApiProductionConfigurationValidator.ValidateJwtSigningKey(builder.Configuration, builder.Environment);
    HostApiProductionConfigurationValidator.ValidateExternalAuthMobileRedirectScheme(builder.Configuration, builder.Environment);
    HostApiProductionConfigurationValidator.ValidateAllowedHosts(builder.Configuration, builder.Environment);
    HostApiProductionConfigurationValidator.ValidateCorsAllowedOrigins(allowedOrigins, builder.Environment);
    HostApiProductionConfigurationValidator.ValidatePublicMediaBaseUrls(builder.Configuration, builder.Environment);
    HostApiProductionConfigurationValidator.ValidateNoPublicServerSecrets(builder.Configuration, builder.Environment);

    builder.Services.AddCors(options =>
    {
        options.AddPolicy("AdminWeb", policy =>
        {
            if (allowedOrigins.Length == 0)
            {
                if (allowAnyCorsInDevelopment)
                {
                    policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
                    return;
                }

                throw new InvalidOperationException(
                    "Cors:AllowedOrigins must be configured for non-development environments.");
            }

            policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod().AllowCredentials();
        });
    });

    var rateLimitSection = builder.Configuration.GetSection("RateLimiting");
    int RateLimitPermit(string policyName, int defaultPermitLimit) =>
        Math.Max(1, rateLimitSection.GetSection(policyName).GetValue<int?>("PermitLimit") ?? defaultPermitLimit);

    builder.Services.AddRateLimiter(options =>
    {
        options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
        options.OnRejected = RateLimitProblemResponse.WriteAsync;

        options.AddPolicy("auth", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.UserOrIp(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("Auth", 30),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("economy", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.UserOrIp(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("Economy", 60),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("templates", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.UserOrIp(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("Templates", 90),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("templates-analytics", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.UserOrIp(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("TemplatesAnalytics", 48),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("templates-events", httpContext =>
            RateLimitPartition.GetConcurrencyLimiter(
                partitionKey: RateLimitPartitionKeys.Ip(httpContext),
                factory: _ => new ConcurrencyLimiterOptions
                {
                    PermitLimit = RateLimitPermit("TemplatesEventsConcurrent", 3),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("generation-create", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.UserOrIp(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("GenerationCreate", 12),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("generation-status", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.UserOrIp(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("GenerationStatus", 180),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("support-chat", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.UserOrIp(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("SupportChat", 60),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("admin", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.UserOrIp(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("Admin", 120),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("webhooks", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.WebhookProvider(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("Webhooks", 120),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("auth-register", httpContext =>
            RateLimitPartition.GetSlidingWindowLimiter(
                partitionKey: RateLimitPartitionKeys.Ip(httpContext),
                factory: _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("AuthRegister", 8),
                    Window = TimeSpan.FromMinutes(1),
                    SegmentsPerWindow = 6,
                    QueueLimit = 0,
                    AutoReplenishment = true,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("auth-password-reset", httpContext =>
            RateLimitPartition.GetSlidingWindowLimiter(
                partitionKey: RateLimitPartitionKeys.Ip(httpContext),
                factory: _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("AuthPasswordReset", 10),
                    Window = TimeSpan.FromMinutes(1),
                    SegmentsPerWindow = 6,
                    QueueLimit = 0,
                    AutoReplenishment = true,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("auth-email-verification", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.Ip(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("AuthEmailVerification", 10),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("auth-external", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.Ip(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("AuthExternal", 12),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));
    });

    builder.Services
        .AddEconomyInfrastructure(builder.Configuration, builder.Environment.IsProduction())
        .AddEconomyApiModule()
        .AddIdentityInfrastructure(builder.Configuration, builder.Environment)
        .AddIdentityApiModule()
        .AddSupportChatInfrastructure(builder.Configuration, builder.Environment.IsProduction())
        .AddSupportChatApiModule()
        .AddTemplatesInfrastructure(
            builder.Configuration,
            builder.Environment,
            TemplateSchedulerConfigFingerprint.ApiComponent)
        .AddTemplatesApiModule()
        .AddGamificationInfrastructure(builder.Configuration)
        .AddGamificationApiModule();

    builder.Services.AddHealthChecks()
        .AddCheck("self", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy())
        .AddCheck<PremiumSubscriptionPlansHealthCheck>("economy_subscription_plans")
        .AddCheck<StoreAccountBindingModeHealthCheck>("store_account_binding")
        .AddCheck<TemplateContentHealthCheck>("templates_content")
        .AddCheck<TemplateSchedulerConfigHealthCheck>("templates_scheduler_config")
        .AddCheck<FalProviderRuntimeHealthCheck>("templates_fal_provider")
        .AddCheck<GamificationLegacyDeliveryHealthCheck>("gamification_legacy_delivery")
        .AddCheck<PushOutboxHealthCheck>("push_outbox");
    builder.Services.AddScoped<IAdminSystemStatusService, AdminSystemStatusService>();
    builder.Services.AddScoped<IAdminOperationsStatusService, AdminOperationsStatusService>();
    builder.Services.AddScoped<IAdminOperationsProblemService, AdminOperationsProblemService>();

    builder.Services
        .AddOpenTelemetry()
        .ConfigureResource(resource => resource.AddService("PetMagic.Host.Api"))
        .WithTracing(tracing =>
        {
            tracing
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation();

            if (IsOtlpExporterConfigured(builder.Configuration))
            {
                tracing.AddOtlpExporter();
            }
        })
        .WithMetrics(metrics =>
        {
            metrics
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation()
                .AddMeter("PetMagic.Host.Api")
                .AddMeter("PetMagic.Modules.Economy")
                .AddMeter("PetMagic.Modules.Templates")
                .AddMeter("PetMagic.Notifications");

            if (IsOtlpExporterConfigured(builder.Configuration))
            {
                metrics.AddOtlpExporter();
            }
        });

    var app = builder.Build();

    Directory.CreateDirectory(dataProtectionKeysPath);
    Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot"));
    Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "support-attachments"));
    Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "user-avatars"));
    Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "templates-media"));
    var extraStaticWebRootPath = app.Configuration["StaticFiles:ExtraWebRootPath"];
    if (!string.IsNullOrWhiteSpace(extraStaticWebRootPath))
    {
        Directory.CreateDirectory(extraStaticWebRootPath);
        Directory.CreateDirectory(Path.Combine(extraStaticWebRootPath, "support-attachments"));
        Directory.CreateDirectory(Path.Combine(extraStaticWebRootPath, "user-avatars"));
        Directory.CreateDirectory(Path.Combine(extraStaticWebRootPath, "templates-media"));
    }

    if (forwardedHeadersTrustSettings.Enabled)
    {
        app.UseForwardedHeaders(ForwardedHeadersTrust.BuildOptions(forwardedHeadersTrustSettings));
    }

    app.UseMiddleware<CorrelationIdMiddleware>();
    app.UseMiddleware<GlobalExceptionMiddleware>();
    app.UseMiddleware<StructuredRequestLoggingMiddleware>();
    app.UseMiddleware<RequestMetricsMiddleware>();
    app.UseResponseCompression();

    if (!app.Environment.IsDevelopment())
    {
        app.UseHsts();
        app.UseHttpsRedirection();
    }

    app.Use(async (context, next) =>
    {
        context.Response.Headers.TryAdd("X-Content-Type-Options", "nosniff");
        context.Response.Headers.TryAdd("X-Frame-Options", "DENY");
        context.Response.Headers.TryAdd("Referrer-Policy", "no-referrer");
        context.Response.Headers.TryAdd("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'");
        await next();
    });

    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi();
    }

    app.UseCors("AdminWeb");
    if (!app.Environment.IsDevelopment())
    {
        app.Use(async (context, next) =>
        {
            if (IsManagedStaticMediaPath(context.Request.Path, "/templates-media"))
            {
                context.Response.StatusCode = StatusCodes.Status404NotFound;
                return;
            }

            await next();
        });
    }

    app.Use(async (context, next) =>
    {
        var requestPath = context.Request.Path.Value ?? string.Empty;
        var supportStorageOptions = context.RequestServices
            .GetRequiredService<IOptions<SupportAttachmentStorageOptions>>()
            .Value;
        if (IsManagedSignedMediaPath(
            context.Request.Path,
            "/support-attachments",
            supportStorageOptions.PublicBaseUrl))
        {
            var signer = context.RequestServices.GetRequiredService<ISupportAttachmentReadUrlSigner>();
            var query = context.Request.Query.ToDictionary(
                pair => pair.Key,
                pair => (string?)pair.Value.ToString(),
                StringComparer.OrdinalIgnoreCase);
            if (!signer.IsAuthorizedRequest(requestPath, query))
            {
                context.Response.StatusCode = StatusCodes.Status404NotFound;
                return;
            }
        }

        var avatarStorageOptions = context.RequestServices
            .GetRequiredService<IOptions<AvatarStorageOptions>>()
            .Value;
        if (IsManagedSignedMediaPath(
            context.Request.Path,
            "/user-avatars",
            avatarStorageOptions.PublicBaseUrl))
        {
            var signer = context.RequestServices.GetRequiredService<IAvatarReadUrlSigner>();
            var query = context.Request.Query.ToDictionary(
                pair => pair.Key,
                pair => (string?)pair.Value.ToString(),
                StringComparer.OrdinalIgnoreCase);
            if (!signer.IsAuthorizedRequest(requestPath, query))
            {
                context.Response.StatusCode = StatusCodes.Status404NotFound;
                return;
            }
        }

        var templatesOptions = context.RequestServices.GetRequiredService<TemplatesOptions>();
        if (IsManagedSignedMediaPath(
            context.Request.Path,
            "/templates-media",
            templatesOptions.PublicBaseUrl) &&
            !app.Environment.IsDevelopment())
        {
            // Local template storage is development-only and public catalog
            // responses carry its canonical static URL. Production rejects the
            // local provider and continues to require signed managed media URLs.
            var signer = context.RequestServices.GetRequiredService<ITemplateMediaReadUrlSigner>();
            var query = context.Request.Query.ToDictionary(
                pair => pair.Key,
                pair => (string?)pair.Value.ToString(),
                StringComparer.OrdinalIgnoreCase);
            if (!signer.IsAuthorizedRequest(requestPath, query))
            {
                context.Response.StatusCode = StatusCodes.Status404NotFound;
                return;
            }
        }

        await next();
    });

    app.UseStaticFiles(new StaticFileOptions
    {
        OnPrepareResponse = PrepareManagedStaticFileResponse
    });
    if (!string.IsNullOrWhiteSpace(extraStaticWebRootPath))
    {
        app.UseStaticFiles(new StaticFileOptions
        {
            FileProvider = new PhysicalFileProvider(extraStaticWebRootPath),
            OnPrepareResponse = PrepareManagedStaticFileResponse
        });
    }

    app.UseAuthentication();
    app.UseRateLimiter();
    app.UseMiddleware<LegalAcceptanceEnforcementMiddleware>();
    app.UseAuthorization();
    app.UseMiddleware<RequestLogContextMiddleware>();

    app.MapHealthChecks("/health", new HealthCheckOptions
    {
        ResponseWriter = async (context, report) =>
        {
            context.Response.ContentType = "application/json";
            var result = HealthResponseBuilder.Build(context, report, buildInfo);
            await context.Response.WriteAsJsonAsync(result);
        }
    }).AllowAnonymous();
    app.MapAdminSystemStatusEndpoints();

    app.MapEconomyApiModule();
    app.MapIdentityApiModule();
    app.MapSupportChatApiModule();
    app.MapTemplatesApiModule();
    app.MapGamificationApiModule();

    await StartupMigrationLock.RunWithMigrationLockAsync(
        sharedPostgreSqlDataSource,
        async () =>
        {
            await PostgreSqlIndexIntegrityValidator.RepairPendingMigrationIndexesAsync(
                sharedPostgreSqlDataSource);
            var isEmptyPostgreSqlSchema = await PostgreSqlStartupSchemaState.IsEmptyAsync(
                sharedPostgreSqlDataSource);
            if (isEmptyPostgreSqlSchema)
            {
                Log.Information("Initializing EF migration history for an empty PostgreSQL schema.");
                using var historyScope = app.Services.CreateScope();
                var economyDbContext = historyScope.ServiceProvider.GetRequiredService<EconomyDbContext>();
                var historyRepository = economyDbContext.GetService<IHistoryRepository>();
                await historyRepository.CreateIfNotExistsAsync();
            }

            await app.Services.EnsureEconomySeedDataAsync();
            await app.Services.EnsureIdentitySeedDataAsync();
            await app.Services.EnsureSupportChatSeedDataAsync();
            await app.Services.EnsureTemplatesSeedDataAsync();
            await app.Services.EnsureGamificationSeedDataAsync();
            await PostgreSqlIndexIntegrityValidator.ValidateAsync(
                sharedPostgreSqlDataSource);
        },
        acquireTimeout: TimeSpan.FromMinutes(5));

    app.Run();
}
catch (Exception exception)
{
    Log.Fatal(exception, "PetMagic.Host.Api stopped during startup or runtime.");
    throw;
}
finally
{
    Log.CloseAndFlush();
}

static HostBuildInfo ResolveBuildInfo(string environmentName)
{
    var assembly = Assembly.GetExecutingAssembly();
    var assemblyName = assembly.GetName();
    var informationalVersion = assembly
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()
        ?.InformationalVersion;
    var sourceRevision = NormalizeSourceRevision(assembly
        .GetCustomAttributes<AssemblyMetadataAttribute>()
        .FirstOrDefault(attribute => string.Equals(attribute.Key, "SourceRevisionId", StringComparison.Ordinal))
        ?.Value);

    if (string.IsNullOrWhiteSpace(sourceRevision)
        && informationalVersion?.IndexOf('+', StringComparison.Ordinal) is int revisionSeparator
        && revisionSeparator >= 0
        && revisionSeparator < informationalVersion.Length - 1)
    {
        sourceRevision = NormalizeSourceRevision(informationalVersion[(revisionSeparator + 1)..]);
    }

    sourceRevision ??= NormalizeSourceRevision(
        Environment.GetEnvironmentVariable("RENDER_GIT_COMMIT"));

    return new HostBuildInfo(
        Application: "PetMagic.Host.Api",
        Environment: environmentName,
        Version: assemblyName.Version?.ToString() ?? "unknown",
        InformationalVersion: string.IsNullOrWhiteSpace(informationalVersion)
            ? "unknown"
            : informationalVersion,
        SourceRevision: sourceRevision ?? "unknown",
        ProcessStartedAtUtc: DateTimeOffset.UtcNow);
}

static string? NormalizeSourceRevision(string? value)
{
    var candidate = value?.Trim();
    if (candidate is null
        || candidate.Length is < 7 or > 64
        || candidate.Any(character => !Uri.IsHexDigit(character)))
    {
        return null;
    }

    return candidate.ToLowerInvariant();
}

static void LoadDotEnvFileIfPresent()
{
    var environmentName = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
        ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
    if (!string.Equals(environmentName, Environments.Development, StringComparison.OrdinalIgnoreCase))
    {
        return;
    }

    var currentDirectory = new DirectoryInfo(Directory.GetCurrentDirectory());
    while (currentDirectory is not null)
    {
        var envPath = Path.Combine(currentDirectory.FullName, ".env");
        if (File.Exists(envPath))
        {
            foreach (var rawLine in File.ReadLines(envPath))
            {
                var line = rawLine.Trim();
                if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#'))
                {
                    continue;
                }

                if (line.StartsWith("export ", StringComparison.Ordinal))
                {
                    line = line["export ".Length..].TrimStart();
                }

                var separatorIndex = line.IndexOf('=');
                if (separatorIndex <= 0)
                {
                    continue;
                }

                var key = line[..separatorIndex].Trim();
                if (string.IsNullOrWhiteSpace(key))
                {
                    continue;
                }

                if (Environment.GetEnvironmentVariable(key) is not null)
                {
                    continue;
                }

                var value = line[(separatorIndex + 1)..].Trim();
                if (value.Length >= 2
                    && ((value.StartsWith('"') && value.EndsWith('"'))
                        || (value.StartsWith('\'') && value.EndsWith('\''))))
                {
                    value = value[1..^1];
                }

                Environment.SetEnvironmentVariable(key, value);
            }

            return;
        }

        currentDirectory = currentDirectory.Parent;
    }
}

static bool IsManagedSignedMediaPath(PathString requestPath, string managedPathPrefix, string publicBaseUrl)
{
    var managedPrefix = new PathString(managedPathPrefix);
    if (requestPath.StartsWithSegments(managedPrefix))
    {
        return true;
    }

    var publicBasePath = ResolvePublicBasePath(publicBaseUrl);
    if (string.IsNullOrWhiteSpace(publicBasePath))
    {
        return false;
    }

    return requestPath.StartsWithSegments(new PathString($"{publicBasePath}{managedPathPrefix}"));
}

static bool IsManagedStaticMediaPath(PathString requestPath, string managedPathPrefix)
{
    return requestPath.StartsWithSegments(new PathString(managedPathPrefix));
}

static void PrepareManagedStaticFileResponse(StaticFileResponseContext staticFileContext)
{
    staticFileContext.Context.Response.Headers.XContentTypeOptions = "nosniff";

    var requestPath = staticFileContext.Context.Request.Path;
    var contentType = staticFileContext.Context.Response.ContentType ?? string.Empty;
    var isSupportAttachmentsPath = IsManagedStaticMediaPath(requestPath, "/support-attachments");
    var isUserAvatarsPath = IsManagedStaticMediaPath(requestPath, "/user-avatars");
    var isTemplatesMediaPath = IsManagedStaticMediaPath(requestPath, "/templates-media");
    var isManagedMediaPath = isSupportAttachmentsPath
        || isUserAvatarsPath
        || isTemplatesMediaPath;

    if (!isManagedMediaPath)
    {
        return;
    }

    if (isTemplatesMediaPath)
    {
        staticFileContext.Context.Response.Headers.CacheControl = "public,max-age=31536000,immutable";
    }
    else
    {
        staticFileContext.Context.Response.Headers.CacheControl = "no-store";
        staticFileContext.Context.Response.Headers.Pragma = "no-cache";
    }

    var isImage = contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase);
    var isVideo = contentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase);

    if (isSupportAttachmentsPath && !isImage)
    {
        staticFileContext.Context.Response.Headers.ContentDisposition = "attachment";
        return;
    }

    if (isTemplatesMediaPath
        && !isImage
        && !isVideo)
    {
        staticFileContext.Context.Response.Headers.ContentDisposition = "attachment";
    }
}

static string ResolvePublicBasePath(string publicBaseUrl)
{
    if (!Uri.TryCreate(publicBaseUrl, UriKind.Absolute, out var uri)
        || string.IsNullOrWhiteSpace(uri.AbsolutePath)
        || uri.AbsolutePath == "/")
    {
        return string.Empty;
    }

    return uri.AbsolutePath.TrimEnd('/');
}

static string ResolveBootstrapEnvironment()
{
    return Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
        ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
        ?? Environments.Production;
}

static bool IsOtlpExporterConfigured(IConfiguration configuration) =>
    !string.IsNullOrWhiteSpace(configuration["OpenTelemetry:Otlp:Endpoint"])
    || !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT"));

static int ReadPositiveDatabaseSetting(
    IConfiguration configuration,
    string key,
    int fallback)
{
    var configured = configuration.GetValue<int?>(key);
    if (configured is null)
    {
        return fallback;
    }

    if (configured <= 0)
    {
        throw new InvalidOperationException($"{key} must be a positive integer.");
    }

    return configured.Value;
}

internal sealed record HostBuildInfo(
    string Application,
    string Environment,
    string Version,
    string InformationalVersion,
    string SourceRevision,
    DateTimeOffset ProcessStartedAtUtc);
