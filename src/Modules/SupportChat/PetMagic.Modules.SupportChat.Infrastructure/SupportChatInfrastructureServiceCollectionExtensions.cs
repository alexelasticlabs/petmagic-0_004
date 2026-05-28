using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public static class SupportChatInfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddSupportChatInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var attachmentStorageOptions = BuildSupportAttachmentStorageOptions(
            configuration.GetSection("SupportChat:AttachmentStorage"));
        var pushOptions = BuildSupportChatPushOptions(configuration);

        services.AddDbContext<SupportChatDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        services.AddSingleton(attachmentStorageOptions);
        services.AddSingleton(pushOptions);
        services.AddSingleton<ISupportAttachmentStorage, LocalSupportAttachmentStorage>();
        services.AddScoped<SupportAttachmentCleanupProcessor>();
        services.AddScoped<ISupportPushTokenService, SupportPushTokenService>();
        services.AddScoped<NoopSupportChatPushNotificationSender>();
        services.AddHttpClient<FcmSupportChatPushNotificationSender>();
        services.AddScoped<ISupportChatPushNotificationSender>(serviceProvider =>
        {
            var options = serviceProvider.GetRequiredService<SupportChatPushOptions>();
            return options.IsConfigured
                ? serviceProvider.GetRequiredService<FcmSupportChatPushNotificationSender>()
                : serviceProvider.GetRequiredService<NoopSupportChatPushNotificationSender>();
        });
        services.AddScoped<ISupportChatService, SupportChatService>();
        services.AddScoped<ISupportReplyTemplateCatalogService, SupportReplyTemplateCatalogService>();
        services.AddHostedService<SupportAttachmentCleanupWorker>();

        return services;
    }

    public static async Task EnsureSupportChatSeedDataAsync(this IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<SupportChatDbContext>();
        await dbContext.Database.MigrateAsync();
        await EnsureSupportChatSchemaCompatibilityAsync(dbContext);
        await SeedDefaultReplyTemplatesAsync(dbContext);
    }

    private static Task EnsureSupportChatSchemaCompatibilityAsync(SupportChatDbContext dbContext)
    {
        // Guard against schema drift in existing databases where attachment columns can be missing
        // while migration history is marked as applied.
        return dbContext.Database.ExecuteSqlRawAsync(
            """
            CREATE TABLE IF NOT EXISTS support_message_attachments
            (
                "Id" uuid,
                "MessageId" uuid,
                "FileUrl" character varying(2048),
                "MimeType" character varying(128),
                "FileName" character varying(256),
                "SizeBytes" bigint,
                "StorageKey" character varying(1024),
                "ExpiresAtUtc" timestamp with time zone,
                "DeletedAtUtc" timestamp with time zone,
                "IsDeleted" boolean,
                "DurationSeconds" double precision,
                "Width" integer,
                "Height" integer,
                "SortOrder" integer,
                "CreatedAtUtc" timestamp with time zone
            );

            ALTER TABLE support_message_attachments
                ADD COLUMN IF NOT EXISTS "Id" uuid NULL,
                ADD COLUMN IF NOT EXISTS "MessageId" uuid NULL,
                ADD COLUMN IF NOT EXISTS "FileUrl" character varying(2048) NULL,
                ADD COLUMN IF NOT EXISTS "MimeType" character varying(128) NULL,
                ADD COLUMN IF NOT EXISTS "FileName" character varying(256) NULL,
                ADD COLUMN IF NOT EXISTS "SizeBytes" bigint NULL,
                ADD COLUMN IF NOT EXISTS "StorageKey" character varying(1024) NULL,
                ADD COLUMN IF NOT EXISTS "ExpiresAtUtc" timestamp with time zone NULL,
                ADD COLUMN IF NOT EXISTS "DeletedAtUtc" timestamp with time zone NULL,
                ADD COLUMN IF NOT EXISTS "IsDeleted" boolean NULL,
                ADD COLUMN IF NOT EXISTS "DurationSeconds" double precision NULL,
                ADD COLUMN IF NOT EXISTS "Width" integer NULL,
                ADD COLUMN IF NOT EXISTS "Height" integer NULL,
                ADD COLUMN IF NOT EXISTS "SortOrder" integer NULL,
                ADD COLUMN IF NOT EXISTS "CreatedAtUtc" timestamp with time zone NULL;

            ALTER TABLE support_message_attachments
                ALTER COLUMN "IsDeleted" SET DEFAULT false;

            ALTER TABLE support_messages
                ADD COLUMN IF NOT EXISTS "ReplyToMessageId" uuid NULL,
                ADD COLUMN IF NOT EXISTS "ReplyToPreview" character varying(280) NULL;
            """);
    }

    private static async Task SeedDefaultReplyTemplatesAsync(SupportChatDbContext dbContext)
    {
        if (await dbContext.SupportReplyTemplates.AnyAsync())
        {
            return;
        }

        var now = DateTime.UtcNow;
        dbContext.SupportReplyTemplates.AddRange(
            new SupportReplyTemplate
            {
                Id = Guid.NewGuid(),
                Title = "Подтвердить получение",
                Body = "Спасибо, мы получили ваше обращение и уже взяли его в работу. Вернемся с обновлением как можно скорее.",
                IsEnabled = true,
                SortOrder = 10,
                CreatedAtUtc = now,
                UpdatedAtUtc = now,
            },
            new SupportReplyTemplate
            {
                Id = Guid.NewGuid(),
                Title = "Идет проверка",
                Body = "Мы уже проверяем ситуацию у себя. Как только подтвердим причину или найдем обходное решение, сразу напишем вам.",
                IsEnabled = true,
                SortOrder = 20,
                CreatedAtUtc = now,
                UpdatedAtUtc = now,
            },
            new SupportReplyTemplate
            {
                Id = Guid.NewGuid(),
                Title = "Запросить детали",
                Body = "Чтобы быстрее разобраться, пришлите, пожалуйста, что именно вы делали перед проблемой и когда это произошло. Если есть скриншот или текст ошибки, тоже поможет.",
                IsEnabled = true,
                SortOrder = 30,
                CreatedAtUtc = now,
                UpdatedAtUtc = now,
            });

        await dbContext.SaveChangesAsync();
    }

    private static SupportAttachmentStorageOptions BuildSupportAttachmentStorageOptions(IConfigurationSection section)
    {
        return new SupportAttachmentStorageOptions
        {
            PublicBaseUrl = section["PublicBaseUrl"] ?? "http://localhost:5000",
            LocalMediaRootPath = section["LocalMediaRootPath"] ?? Path.Combine("wwwroot", "support-attachments"),
            MaxImageFileSizeBytes = ParsePositiveLong(section["MaxImageFileSizeBytes"], 10 * 1024 * 1024),
            MaxVideoFileSizeBytes = ParsePositiveLong(section["MaxVideoFileSizeBytes"], 50 * 1024 * 1024),
            RetentionDays = ParsePositiveInt(section["RetentionDays"], 30),
            CleanupWorkerEnabled = ParseBool(section["CleanupWorkerEnabled"], true),
            CleanupPollIntervalMilliseconds = ParsePositiveInt(section["CleanupPollIntervalMilliseconds"], 86_400_000),
            CleanupBatchSize = ParsePositiveInt(section["CleanupBatchSize"], 100),
            CleanupRetryDelayMilliseconds = ParseNonNegativeInt(section["CleanupRetryDelayMilliseconds"], 30_000),
        };
    }

    private static SupportChatPushOptions BuildSupportChatPushOptions(IConfiguration configuration)
    {
        var supportSection = configuration.GetSection("SupportChat:FirebasePush");
        var templateSection = configuration.GetSection("Templates:FirebasePush");

        return new SupportChatPushOptions
        {
            Enabled = ParseBool(
                ReadValue(supportSection, "Enabled", "SUPPORT_FIREBASE_PUSH_ENABLED")
                    ?? ReadValue(templateSection, "Enabled", "FIREBASE_PUSH_ENABLED"),
                false),
            ProjectId = ReadValue(supportSection, "ProjectId", "SUPPORT_FIREBASE_PROJECT_ID")
                ?? ReadValue(templateSection, "ProjectId", "FIREBASE_PROJECT_ID")
                ?? string.Empty,
            ServiceAccountJson = ReadValue(supportSection, "ServiceAccountJson", "SUPPORT_FIREBASE_SERVICE_ACCOUNT_JSON")
                ?? ReadValue(templateSection, "ServiceAccountJson", "FIREBASE_SERVICE_ACCOUNT_JSON")
                ?? string.Empty,
            ServiceAccountJsonPath = ReadValue(supportSection, "ServiceAccountJsonPath", "SUPPORT_FIREBASE_SERVICE_ACCOUNT_JSON_PATH")
                ?? ReadValue(templateSection, "ServiceAccountJsonPath", "FIREBASE_SERVICE_ACCOUNT_JSON_PATH")
                ?? string.Empty
        };
    }

    private static string? ReadValue(IConfigurationSection section, string key, string environmentVariable)
    {
        var value = section[key];
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value;
        }

        return Environment.GetEnvironmentVariable(environmentVariable);
    }

    private static long ParsePositiveLong(string? rawValue, long fallback)
    {
        return long.TryParse(rawValue, out var parsed) && parsed > 0 ? parsed : fallback;
    }

    private static int ParsePositiveInt(string? rawValue, int fallback)
    {
        return int.TryParse(rawValue, out var parsed) && parsed > 0 ? parsed : fallback;
    }

    private static int ParseNonNegativeInt(string? rawValue, int fallback)
    {
        return int.TryParse(rawValue, out var parsed) && parsed >= 0 ? parsed : fallback;
    }

    private static bool ParseBool(string? rawValue, bool fallback)
    {
        return bool.TryParse(rawValue, out var parsed) ? parsed : fallback;
    }
}
