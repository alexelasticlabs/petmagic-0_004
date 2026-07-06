using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class EmailDispatchProcessorTests
{
    [Fact]
    public async Task ProcessNextAsync_ShouldSanitizeDurableFailureMessage()
    {
        await using var dbContext = CreateDbContext();
        dbContext.EmailDispatchJobs.Add(new EmailDispatchJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            RecipientEmail = "pet@example.com",
            Subject = "Confirm",
            HtmlBody = "<p>123456</p>",
            TextBody = "123456",
            Kind = EmailDispatchKind.EmailConfirmation,
            Status = EmailDispatchStatus.Queued,
            QueuedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();
        var sender = new FailingEmailSender(
            "email.smtp_failed token=code-secret",
            "smtp failed token=smtp-token api_secret=smtp-secret signedPayload=provider-payload");
        var processor = new EmailDispatchProcessor(
            dbContext,
            sender,
            new EmailOptions
            {
                MaxDispatchAttempts = 1
            },
            NullLogger<EmailDispatchProcessor>.Instance);

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        Assert.True(processed);
        var job = await dbContext.EmailDispatchJobs.SingleAsync();
        Assert.Equal(EmailDispatchStatus.Failed, job.Status);
        Assert.NotNull(job.FailureCode);
        Assert.NotNull(job.FailureMessage);
        Assert.DoesNotContain("code-secret", job.FailureCode);
        Assert.DoesNotContain("smtp-token", job.FailureMessage);
        Assert.DoesNotContain("smtp-secret", job.FailureMessage);
        Assert.DoesNotContain("provider-payload", job.FailureMessage);
    }

    private static IdentityDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase($"email-dispatch-processor-tests-{Guid.NewGuid():N}")
            .Options;

        return new IdentityDbContext(options);
    }

    private sealed class FailingEmailSender(string code, string message) : IEmailSender
    {
        public Task<Result> SendAsync(EmailDispatchJob job, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure(new Error(code, message)));
        }
    }
}
