using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.DataProtection;

using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

using PetMagic.Modules.Economy.Api;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Identity.Api;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.SupportChat.Api;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Infrastructure;

using Serilog;

LoadDotEnvFileIfPresent();

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, loggerConfiguration) =>
{
    loggerConfiguration
        .ReadFrom.Configuration(context.Configuration)
        .Enrich.FromLogContext()
        .WriteTo.Console();
});

builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();
builder.Services.AddMemoryCache();

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

builder.Services.AddRateLimiter(options =>
{
    options.AddPolicy("auth", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "global",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst
            }));

    options.AddPolicy("economy", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.FindFirst("sub")?.Value
                ?? httpContext.Connection.RemoteIpAddress?.ToString()
                ?? "global",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst
            }));

    options.AddPolicy("templates", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.FindFirst("sub")?.Value
                ?? httpContext.Connection.RemoteIpAddress?.ToString()
                ?? "global",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 90,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst
            }));

    options.AddPolicy("support-chat", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.FindFirst("sub")?.Value
                ?? httpContext.Connection.RemoteIpAddress?.ToString()
                ?? "global",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst
            }));

    options.AddPolicy("auth-register", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "global",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 8,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst
            }));

    options.AddPolicy("auth-password-reset", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "global",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst
            }));
});

builder.Services
    .AddEconomyInfrastructure(builder.Configuration)
    .AddEconomyApiModule()
    .AddIdentityInfrastructure(builder.Configuration, builder.Environment)
    .AddIdentityApiModule()
    .AddSupportChatInfrastructure(builder.Configuration)
    .AddSupportChatApiModule()
    .AddTemplatesInfrastructure(builder.Configuration, builder.Environment)
    .AddTemplatesApiModule();

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
        .AddMeter("PetMagic.Modules.Economy")
        .AddOtlpExporter());

var app = builder.Build();

Directory.CreateDirectory(dataProtectionKeysPath);
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "support-attachments"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "user-avatars"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "templates-media"));

app.UseSerilogRequestLogging();
app.UseExceptionHandler();

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
    await next();
});

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors("AdminWeb");
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

        staticFileContext.Context.Response.Headers.CacheControl = "public,max-age=31536000,immutable";

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
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }))
    .AllowAnonymous();

app.MapEconomyApiModule();
app.MapIdentityApiModule();
app.MapSupportChatApiModule();
app.MapTemplatesApiModule();

await app.Services.EnsureEconomySeedDataAsync();
await app.Services.EnsureIdentitySeedDataAsync();
await app.Services.EnsureSupportChatSeedDataAsync();
await app.Services.EnsureTemplatesSeedDataAsync();

app.Run();

static X509Certificate2 LoadOrCreateDataProtectionCertificate(
    string certificatePath,
    string certificatePassword,
    string applicationName)
{
    Directory.CreateDirectory(Path.GetDirectoryName(certificatePath)!);

    if (File.Exists(certificatePath))
    {
        return X509CertificateLoader.LoadPkcs12FromFile(
            certificatePath,
            certificatePassword,
            X509KeyStorageFlags.Exportable | X509KeyStorageFlags.PersistKeySet);
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
