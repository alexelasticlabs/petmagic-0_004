using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
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
    public void SmtpMessageId_ShouldBeStableForDispatchJob()
    {
        var jobId = Guid.NewGuid();

        var first = SmtpEmailSender.BuildDeterministicMessageId(jobId, "support@petmagic.app");
        var second = SmtpEmailSender.BuildDeterministicMessageId(jobId, "support@petmagic.app");

        Assert.Equal(first, second);
        Assert.Equal($"<{jobId:N}@petmagic.app>", first);
    }

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

    [Fact]
    public async Task ProcessNextAsync_ShouldRecoverExpiredProcessingLease()
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
            Status = EmailDispatchStatus.Processing,
            AttemptCount = 1,
            LockId = Guid.NewGuid(),
            LockExpiresAtUtc = DateTime.UtcNow.AddMinutes(-1),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            UpdatedAtUtc = DateTime.UtcNow.AddMinutes(-1)
        });
        await dbContext.SaveChangesAsync();
        var sender = new SuccessfulEmailSender();
        var processor = new EmailDispatchProcessor(
            dbContext,
            sender,
            new EmailOptions { MaxDispatchAttempts = 3, ProcessingLeaseSeconds = 120 },
            NullLogger<EmailDispatchProcessor>.Instance);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));

        var job = await dbContext.EmailDispatchJobs.SingleAsync();
        Assert.Equal(EmailDispatchStatus.Sent, job.Status);
        Assert.Equal(2, job.AttemptCount);
        Assert.Null(job.LockId);
        Assert.Null(job.LockExpiresAtUtc);
        Assert.Equal(1, sender.SendCount);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldNotClaimActiveProcessingLease()
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
            Status = EmailDispatchStatus.Processing,
            AttemptCount = 1,
            LockId = Guid.NewGuid(),
            LockExpiresAtUtc = DateTime.UtcNow.AddMinutes(1),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();
        var sender = new SuccessfulEmailSender();
        var processor = new EmailDispatchProcessor(
            dbContext,
            sender,
            new EmailOptions { MaxDispatchAttempts = 3, ProcessingLeaseSeconds = 120 },
            NullLogger<EmailDispatchProcessor>.Instance);

        Assert.False(await processor.ProcessNextAsync(CancellationToken.None));
        Assert.Equal(0, sender.SendCount);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldIgnoreStaleCompletionAfterLeaseIsReclaimed()
    {
        var databaseRoot = new InMemoryDatabaseRoot();
        var databaseName = $"identity-email-lease-tests-{Guid.NewGuid():N}";
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase(databaseName, databaseRoot)
            .Options;
        var emailOptions = new EmailOptions
        {
            MaxDispatchAttempts = 3,
            ProcessingLeaseSeconds = 120,
            RetryDelaySeconds = 1
        };

        await using (var seedContext = new IdentityDbContext(options))
        {
            seedContext.EmailDispatchJobs.Add(CreateQueuedJob());
            await seedContext.SaveChangesAsync();
        }

        await using var firstContext = new IdentityDbContext(options);
        var blockingSender = new BlockingFailingEmailSender();
        var firstProcessor = new EmailDispatchProcessor(
            firstContext,
            blockingSender,
            emailOptions,
            NullLogger<EmailDispatchProcessor>.Instance);
        var firstProcessing = firstProcessor.ProcessNextAsync(CancellationToken.None);
        await blockingSender.SendStarted.Task.WaitAsync(TimeSpan.FromSeconds(5));

        await using (var expireContext = new IdentityDbContext(options))
        {
            var claimed = await expireContext.EmailDispatchJobs.SingleAsync();
            claimed.LockExpiresAtUtc = DateTime.UtcNow.AddMinutes(-1);
            await expireContext.SaveChangesAsync();
        }

        await using (var secondContext = new IdentityDbContext(options))
        {
            var secondProcessor = new EmailDispatchProcessor(
                secondContext,
                new SuccessfulEmailSender(),
                emailOptions,
                NullLogger<EmailDispatchProcessor>.Instance);
            Assert.True(await secondProcessor.ProcessNextAsync(CancellationToken.None));
        }

        blockingSender.Release.TrySetResult();
        Assert.True(await firstProcessing);

        await using var verificationContext = new IdentityDbContext(options);
        var persisted = await verificationContext.EmailDispatchJobs.AsNoTracking().SingleAsync();
        Assert.Equal(EmailDispatchStatus.Sent, persisted.Status);
        Assert.Equal(2, persisted.AttemptCount);
        Assert.Null(persisted.LockId);
        Assert.Null(persisted.LockExpiresAtUtc);
        Assert.Null(persisted.FailureCode);
    }

    private static IdentityDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase($"email-dispatch-processor-tests-{Guid.NewGuid():N}")
            .Options;

        return new IdentityDbContext(options);
    }

    private static EmailDispatchJob CreateQueuedJob()
    {
        var now = DateTime.UtcNow;
        return new EmailDispatchJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            RecipientEmail = "pet@example.com",
            Subject = "Confirm",
            HtmlBody = "<p>123456</p>",
            TextBody = "123456",
            Kind = EmailDispatchKind.EmailConfirmation,
            Status = EmailDispatchStatus.Queued,
            QueuedAtUtc = now.AddMinutes(-1),
            UpdatedAtUtc = now.AddMinutes(-1)
        };
    }

    private sealed class FailingEmailSender(string code, string message) : IEmailSender
    {
        public Task<Result> SendAsync(EmailDispatchJob job, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure(new Error(code, message)));
        }
    }

    private sealed class SuccessfulEmailSender : IEmailSender
    {
        public int SendCount { get; private set; }

        public Task<Result> SendAsync(EmailDispatchJob job, CancellationToken cancellationToken)
        {
            SendCount++;
            return Task.FromResult(Result.Success());
        }
    }

    private sealed class BlockingFailingEmailSender : IEmailSender
    {
        public TaskCompletionSource SendStarted { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public TaskCompletionSource Release { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<Result> SendAsync(EmailDispatchJob job, CancellationToken cancellationToken)
        {
            SendStarted.TrySetResult();
            await Release.Task.WaitAsync(cancellationToken);
            return Result.Failure(new Error("smtp.temporary", "Temporary failure"));
        }
    }
}
