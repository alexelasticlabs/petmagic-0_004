using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationPushNotificationOutbox(
    TemplatesDbContext dbContext) : ITemplateGenerationPushNotificationSender
{
    internal const string GenerationTerminalKind = "generation_terminal";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task NotifyGenerationTerminalAsync(
        TemplateGenerationResponse generation,
        CancellationToken cancellationToken)
    {
        // Enqueue in the terminal generation transaction. Delivery credentials
        // belong to the API dispatcher and are intentionally absent from the
        // isolated generation worker.
        if (generation.UserId == TemplateGenerationService.AdminTestUserId)
        {
            return;
        }

        var deduplicationKey = $"template_generation:{generation.GenerationId:D}:{generation.Status}";
        if (dbContext.PushOutboxMessages.Local.Any(x => x.DeduplicationKey == deduplicationKey)
            || await dbContext.PushOutboxMessages.AsNoTracking().AnyAsync(
                x => x.DeduplicationKey == deduplicationKey,
                cancellationToken))
        {
            return;
        }

        var now = DateTime.UtcNow;
        dbContext.PushOutboxMessages.Add(new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = deduplicationKey,
            Kind = GenerationTerminalKind,
            UserId = generation.UserId,
            PayloadJson = JsonSerializer.Serialize(generation, JsonOptions),
            Status = PushOutboxStatus.Queued,
            NextAttemptAtUtc = now,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
    }
}
