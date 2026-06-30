using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Diagnostics;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Http;

using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

using PetMagic.Host.Api.Observability;
using PetMagic.Modules.Economy.Api;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Host.Api.Security;
using PetMagic.Modules.Identity.Api;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.SupportChat.Api;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Gamification.Api;
using PetMagic.Modules.Gamification.Infrastructure;

using Serilog;
using Serilog.Events;
using Serilog.Formatting.Json;

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

    var dataProtectionKeysPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".aspnet",
        "DataProtection-Keys");
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

        var dataProtectionCertificate = LoadOrCreateDataProtectionCertificate(
            dataProtectionCertificatePath,
            dataProtectionCertificatePassword,
            builder.Environment.ApplicationName);

        dataProtectionBuilder.ProtectKeysWithCertificate(dataProtectionCertificate);
    }

    var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    var allowAnyCorsInDevelopment = builder.Environment.IsDevelopment();
    HostApiProductionConfigurationValidator.ValidateDefaultConnectionString(builder.Configuration, builder.Environment);
    HostApiProductionConfigurationValidator.ValidateJwtSigningKey(builder.Configuration, builder.Environment);
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
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.Ip(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("AuthRegister", 8),
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst
                }));

        options.AddPolicy("auth-password-reset", httpContext =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: RateLimitPartitionKeys.Ip(httpContext),
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = RateLimitPermit("AuthPasswordReset", 10),
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
        .AddTemplatesInfrastructure(builder.Configuration, builder.Environment)
        .AddTemplatesApiModule()
        .AddGamificationInfrastructure(builder.Configuration)
        .AddGamificationApiModule();

    builder.Services.AddHealthChecks()
        .AddCheck("self", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy());

    builder.Services
        .AddOpenTelemetry()
        .ConfigureResource(resource => resource.AddService("PetMagic.Host.Api"))
        .WithTracing(tracing => tracing
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddOtlpExporter())
        .WithMetrics(metrics => metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRuntimeInstrumentation()
            .AddMeter("PetMagic.Host.Api")
            .AddMeter("PetMagic.Modules.Economy")
            .AddMeter("PetMagic.Modules.Templates")
            .AddOtlpExporter());

    var app = builder.Build();

    Directory.CreateDirectory(dataProtectionKeysPath);
    Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot"));
    Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "support-attachments"));
    Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "user-avatars"));
    Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "templates-media"));

    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
    });

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
            var requestPath = context.Request.Path.Value ?? string.Empty;
            if (requestPath.StartsWith("/templates-media", StringComparison.OrdinalIgnoreCase))
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
        if (requestPath.Contains("/support-attachments", StringComparison.OrdinalIgnoreCase))
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

        if (requestPath.Contains("/user-avatars", StringComparison.OrdinalIgnoreCase))
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

        await next();
    });

    app.UseStaticFiles(new StaticFileOptions
    {
        OnPrepareResponse = static staticFileContext =>
        {
            staticFileContext.Context.Response.Headers.XContentTypeOptions = "nosniff";

            var requestPath = staticFileContext.Context.Request.Path.Value ?? string.Empty;
            var contentType = staticFileContext.Context.Response.ContentType ?? string.Empty;
            var isManagedMediaPath = requestPath.StartsWith("/support-attachments", StringComparison.OrdinalIgnoreCase)
                || requestPath.StartsWith("/user-avatars", StringComparison.OrdinalIgnoreCase)
                || requestPath.StartsWith("/templates-media", StringComparison.OrdinalIgnoreCase);

            if (!isManagedMediaPath)
            {
                return;
            }

            if (requestPath.StartsWith("/templates-media", StringComparison.OrdinalIgnoreCase))
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

            if (requestPath.StartsWith("/support-attachments", StringComparison.OrdinalIgnoreCase)
                && !isImage)
            {
                staticFileContext.Context.Response.Headers.ContentDisposition = "attachment";
                return;
            }

            if (requestPath.StartsWith("/templates-media", StringComparison.OrdinalIgnoreCase)
                && !isImage
                && !isVideo)
            {
                staticFileContext.Context.Response.Headers.ContentDisposition = "attachment";
            }
        }
    });
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
            var result = new
            {
                status = report.Status.ToString(),
                checks = report.Entries.Select(e => new
                {
                    name = e.Key,
                    status = e.Value.Status.ToString(),
                    duration = e.Value.Duration
                }),
                totalDuration = report.TotalDuration
            };
            await context.Response.WriteAsJsonAsync(result);
        }
    }).AllowAnonymous();

    app.MapEconomyApiModule();
    app.MapIdentityApiModule();
    app.MapSupportChatApiModule();
    app.MapTemplatesApiModule();
    app.MapGamificationApiModule();

    await app.Services.EnsureEconomySeedDataAsync();
    await app.Services.EnsureIdentitySeedDataAsync();
    await app.Services.EnsureSupportChatSeedDataAsync();
    await app.Services.EnsureTemplatesSeedDataAsync();
    await app.Services.EnsureGamificationSeedDataAsync();

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

static X509Certificate2 LoadOrCreateDataProtectionCertificate(
    string certificatePath,
    string certificatePassword,
    string applicationName)
{
    Directory.CreateDirectory(Path.GetDirectoryName(certificatePath)!);

    if (File.Exists(certificatePath))
    {
        try
        {
            return X509CertificateLoader.LoadPkcs12FromFile(
                certificatePath,
                certificatePassword,
                X509KeyStorageFlags.Exportable | X509KeyStorageFlags.PersistKeySet);
        }
        catch (CryptographicException)
        {
            File.Delete(certificatePath);
        }
    }

    using var rsa = RSA.Create(2048);
    var subject = $"CN={applicationName} Data Protection";
    var request = new CertificateRequest(
        new X500DistinguishedName(subject),
        rsa,
        HashAlgorithmName.SHA256,
        RSASignaturePadding.Pkcs1);

    request.CertificateExtensions.Add(
        new X509BasicConstraintsExtension(false, false, 0, false));
    request.CertificateExtensions.Add(
        new X509KeyUsageExtension(X509KeyUsageFlags.KeyEncipherment | X509KeyUsageFlags.DigitalSignature, false));
    request.CertificateExtensions.Add(
        new X509SubjectKeyIdentifierExtension(request.PublicKey, false));

    using var certificate = request.CreateSelfSigned(
        DateTimeOffset.UtcNow.AddDays(-1),
        DateTimeOffset.UtcNow.AddYears(5));

    File.WriteAllBytes(
        certificatePath,
        certificate.Export(X509ContentType.Pfx, certificatePassword));

    return X509CertificateLoader.LoadPkcs12FromFile(
        certificatePath,
        certificatePassword,
        X509KeyStorageFlags.Exportable | X509KeyStorageFlags.PersistKeySet);
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

static string ResolveBootstrapEnvironment()
{
    return Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
        ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
        ?? Environments.Production;
}
