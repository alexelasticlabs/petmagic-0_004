using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public static class SupportChatInfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddSupportChatInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var attachmentStorageOptions = BuildSupportAttachmentStorageOptions(
            configuration.GetSection("SupportChat:AttachmentStorage"));

        services.AddDbContext<SupportChatDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        services.AddSingleton(attachmentStorageOptions);
        services.AddSingleton<ISupportAttachmentStorage, LocalSupportAttachmentStorage>();
        services.AddScoped<ISupportChatService, SupportChatService>();
        services.AddScoped<ISupportReplyTemplateCatalogService, SupportReplyTemplateCatalogService>();

        return services;
    }

    public static async Task EnsureSupportChatSeedDataAsync(this IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<SupportChatDbContext>();
        await dbContext.Database.MigrateAsync();
        await SeedDefaultReplyTemplatesAsync(dbContext);
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
            MaxFileSizeBytes = ParsePositiveLong(section["MaxFileSizeBytes"], 8 * 1024 * 1024)
        };
    }

    private static long ParsePositiveLong(string? rawValue, long fallback)
    {
        return long.TryParse(rawValue, out var parsed) && parsed > 0 ? parsed : fallback;
    }
}
